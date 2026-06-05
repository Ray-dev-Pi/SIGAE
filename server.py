#!/usr/bin/env python3
import base64
import hashlib
import hmac
import json
import os
import sqlite3
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

try:
    import psycopg
    from psycopg.rows import dict_row
except ImportError:
    psycopg = None
    dict_row = None

ROOT = Path(__file__).resolve().parent
DB_PATH = ROOT / "sigae.db"
SCHEMA_PATH = ROOT / "schema.sql"
DATABASE_URL = os.environ.get("DATABASE_URL")


def connect():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def hash_password(password, salt=None):
    salt = salt or os.urandom(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, 120_000)
    return base64.b64encode(salt + digest).decode("ascii")


def verify_password(password, stored):
    raw = base64.b64decode(stored.encode("ascii"))
    salt, expected = raw[:16], raw[16:]
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, 120_000)
    return hmac.compare_digest(digest, expected)


def init_db():
    seed_users = [
        ("Super Admin SIGAE", "superadmin@sigae.local", "05574671360", "super_admin", "055746713"),
        ("Administrador SIGAE", "admin@sigae.local", "00000000000", "Administrador", "sigae123"),
        ("Helena Duarte", "diretor@sigae.local", "11111111111", "Diretor", "sigae123"),
        ("Rafael Martins", "multi@sigae.local", "22222222222", "Professor,Gestor municipal", "sigae123"),
        ("Clara Nascimento", "professor@sigae.local", "33333333333", "Professor", "sigae123"),
    ]
    with connect() as conn:
        conn.executescript(SCHEMA_PATH.read_text())
        columns = [row["name"] for row in conn.execute("PRAGMA table_info(users)").fetchall()]
        if "cpf" not in columns:
            conn.execute("ALTER TABLE users ADD COLUMN cpf TEXT")
        conn.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_users_cpf ON users(cpf)")
        for name, email, cpf, role, password in seed_users:
            conn.execute(
                """
                INSERT INTO users (name, email, cpf, role, password_hash)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(email) DO UPDATE SET name = excluded.name, cpf = excluded.cpf, role = excluded.role, password_hash = excluded.password_hash
                """,
                (name, email, cpf, role, hash_password(password)),
            )
        if conn.execute("SELECT COUNT(*) FROM schools").fetchone()[0] == 0:
            conn.executemany(
                "INSERT INTO schools (name, students, teachers, attendance, approval, status) VALUES (?, ?, ?, ?, ?, ?)",
                [
                    ("EMEF Paulo Freire", 1240, 82, 94, 88, "Regular"),
                    ("EMEI Ana Neri", 680, 41, 91, 92, "Regular"),
                    ("EMEF Darcy Ribeiro", 980, 63, 87, 81, "Atenção"),
                    ("CMEI Esperança", 520, 34, 96, 95, "Regular"),
                ],
            )
        if conn.execute("SELECT COUNT(*) FROM audit_logs").fetchone()[0] == 0:
            conn.executemany(
                "INSERT INTO audit_logs (actor, action, entity) VALUES (?, ?, ?)",
                [
                    ("Sistema", "Backup diário concluído", "Infraestrutura"),
                    ("Gestor municipal", "Relatório consolidado exportado", "Relatórios"),
                    ("Secretaria escolar", "Rematrículas efetivadas", "Matrículas"),
                ],
            )


def rows(query, params=()):
    with connect() as conn:
        return [dict(row) for row in conn.execute(query, params).fetchall()]


def cloud_enabled():
    return bool(DATABASE_URL and psycopg)


def pg_connect():
    if not cloud_enabled():
        raise RuntimeError("Supabase/PostgreSQL não configurado.")
    return psycopg.connect(DATABASE_URL, row_factory=dict_row)


def ensure_default_municipio(conn):
    row = conn.execute("SELECT id FROM public.municipios ORDER BY created_at LIMIT 1").fetchone()
    if row:
        return row["id"]
    row = conn.execute(
        """
        INSERT INTO public.municipios (nome, uf)
        VALUES (%s, %s)
        RETURNING id
        """,
        ("Município SIGAE", "SP"),
    ).fetchone()
    return row["id"]


def map_school(row):
    endereco = row.get("endereco") or {}
    return {
        "id": str(row["id"]),
        "name": row["nome"],
        "inep": row.get("codigo_inep") or "",
        "city": endereco.get("regiao") or endereco.get("bairro") or "",
        "stages": ", ".join(row.get("etapas") or []),
        "students": 0,
        "teachers": 0,
        "attendance": 0,
        "approval": 0,
        "status": "Regular" if row.get("ativa") else "Inativa",
        "active": bool(row.get("ativa")),
    }


def map_school_user(row):
    return {
        "id": str(row["id"]),
        "name": row["nome"],
        "cpf": row["cpf"],
        "role": "Diretor" if row["cargo"] == "diretor" else "Secretaria escolar",
        "school": row.get("escola") or "",
        "active": bool(row.get("ativo")),
    }


def pg_count(conn, table):
    try:
        return conn.execute(f"SELECT COUNT(*) AS total FROM public.{table}").fetchone()["total"]
    except Exception:
        return 0


class SigaeHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def send_json(self, payload, status=200):
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def read_json(self):
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            return {}
        return json.loads(self.rfile.read(length).decode("utf-8"))

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/api/health":
            self.send_json({"status": "ok", "service": "SIGAE"})
            return
        if path == "/api/cloud-status":
            self.send_json({"postgres": cloud_enabled()})
            return
        if path == "/api/schools":
            if not cloud_enabled():
                self.send_json({"error": "Supabase/PostgreSQL não configurado."}, 503)
                return
            with pg_connect() as conn:
                rows = conn.execute(
                    """
                    SELECT id, nome, codigo_inep, endereco, etapas, ativa
                    FROM public.escolas
                    ORDER BY nome
                    """
                ).fetchall()
            self.send_json([map_school(row) for row in rows])
            return
        if path == "/api/school-users":
            if not cloud_enabled():
                self.send_json({"error": "Supabase/PostgreSQL não configurado."}, 503)
                return
            with pg_connect() as conn:
                rows = conn.execute(
                    """
                    SELECT u.id, u.nome, u.cpf, u.ativo, c.cargo::text, e.nome AS escola
                    FROM public.usuarios u
                    JOIN public.usuarios_cargos c ON c.usuario_id = u.id
                    LEFT JOIN public.escolas e ON e.id = c.escola_id
                    WHERE c.cargo IN ('diretor', 'secretaria_escolar')
                    ORDER BY u.nome
                    """
                ).fetchall()
            self.send_json([map_school_user(row) for row in rows])
            return
        if path == "/api/global-stats":
            if not cloud_enabled():
                local_schools = rows("SELECT students, teachers FROM schools")
                local_users = rows("SELECT id FROM users")
                self.send_json({
                    "cities": 0,
                    "schools": len(local_schools),
                    "activeSchools": len(local_schools),
                    "students": sum(school["students"] for school in local_schools),
                    "enrollments": 0,
                    "teachers": sum(school["teachers"] for school in local_schools),
                    "users": len(local_users),
                })
                return
            with pg_connect() as conn:
                active_schools = conn.execute("SELECT COUNT(*) AS total FROM public.escolas WHERE ativa = true").fetchone()["total"]
                payload = {
                    "cities": pg_count(conn, "municipios"),
                    "schools": pg_count(conn, "escolas"),
                    "activeSchools": active_schools,
                    "students": pg_count(conn, "alunos"),
                    "enrollments": pg_count(conn, "matriculas"),
                    "teachers": pg_count(conn, "professores"),
                    "users": pg_count(conn, "usuarios"),
                }
            self.send_json(payload)
            return
        if path == "/api/dashboard":
            schools = rows("SELECT name, students, teachers, attendance, approval, status FROM schools ORDER BY name")
            totals = {
                "students": sum(school["students"] for school in schools),
                "teachers": sum(school["teachers"] for school in schools),
                "attendance": round(sum(school["attendance"] for school in schools) / max(len(schools), 1), 1),
                "approval": round(sum(school["approval"] for school in schools) / max(len(schools), 1), 1),
            }
            self.send_json({"totals": totals, "schools": schools})
            return
        if path == "/api/records":
            self.send_json(rows("SELECT id, type, name, school, status, created_at FROM records ORDER BY id DESC"))
            return
        if path == "/api/audit":
            self.send_json(rows("SELECT actor, action, entity, created_at FROM audit_logs ORDER BY id DESC LIMIT 20"))
            return
        super().do_GET()

    def do_POST(self):
        path = urlparse(self.path).path
        payload = self.read_json()
        if path == "/api/login":
            cpf = "".join(char for char in payload.get("cpf", "") if char.isdigit())
            password = payload.get("password", "")
            with connect() as conn:
                user = conn.execute("SELECT name, email, cpf, role, password_hash FROM users WHERE cpf = ?", (cpf,)).fetchone()
            if not user:
                self.send_json({"error": "CPF não cadastrado."}, 404)
            elif verify_password(password, user["password_hash"]):
                roles = [role.strip() for role in user["role"].split(",") if role.strip()]
                self.send_json({"name": user["name"], "email": user["email"], "cpf": user["cpf"], "role": roles[0], "roles": roles})
            else:
                self.send_json({"error": "Senha incorreta para o CPF informado."}, 401)
            return
        if path == "/api/records":
            required = ["type", "name", "school", "status"]
            if not all(payload.get(field) for field in required):
                self.send_json({"error": "Campos obrigatórios ausentes"}, 400)
                return
            with connect() as conn:
                cursor = conn.execute(
                    "INSERT INTO records (type, name, school, status) VALUES (?, ?, ?, ?)",
                    (payload["type"], payload["name"], payload["school"], payload["status"]),
                )
                conn.execute("INSERT INTO audit_logs (actor, action, entity) VALUES (?, ?, ?)", ("API", "Registro criado", payload["type"]))
            self.send_json({"id": cursor.lastrowid, **payload}, 201)
            return
        if path == "/api/schools":
            if not cloud_enabled():
                self.send_json({"error": "Supabase/PostgreSQL não configurado."}, 503)
                return
            required = ["name"]
            if not all(payload.get(field) for field in required):
                self.send_json({"error": "Nome da escola é obrigatório."}, 400)
                return
            with pg_connect() as conn:
                municipio_id = ensure_default_municipio(conn)
                row = conn.execute(
                    """
                    INSERT INTO public.escolas (municipio_id, nome, codigo_inep, endereco, etapas, ativa)
                    VALUES (%s, %s, NULLIF(%s, ''), %s::jsonb, %s, true)
                    RETURNING id, nome, codigo_inep, endereco, etapas, ativa
                    """,
                    (
                        municipio_id,
                        payload["name"].strip(),
                        "".join(char for char in payload.get("inep", "") if char.isdigit()),
                        json.dumps({"regiao": payload.get("city", "").strip()}),
                        [item.strip() for item in payload.get("stages", "").split(",") if item.strip()],
                    ),
                ).fetchone()
                conn.commit()
            self.send_json(map_school(row), 201)
            return
        if path == "/api/school-users":
            if not cloud_enabled():
                self.send_json({"error": "Supabase/PostgreSQL não configurado."}, 503)
                return
            cpf = "".join(char for char in payload.get("cpf", "") if char.isdigit())
            name = payload.get("name", "").strip()
            role = payload.get("role", "Diretor")
            school_id = payload.get("schoolId")
            if not name or len(cpf) != 11 or not school_id:
                self.send_json({"error": "Nome, CPF e escola são obrigatórios."}, 400)
                return
            cargo = "diretor" if role == "Diretor" else "secretaria_escolar"
            with pg_connect() as conn:
                school = conn.execute("SELECT id, municipio_id FROM public.escolas WHERE id = %s", (school_id,)).fetchone()
                if not school:
                    self.send_json({"error": "Escola não encontrada."}, 404)
                    return
                user = conn.execute(
                    """
                    INSERT INTO public.usuarios (nome, cpf, municipio_id, escola_id, ativo)
                    VALUES (%s, %s, %s, %s, true)
                    ON CONFLICT (cpf) DO UPDATE
                    SET nome = EXCLUDED.nome,
                        municipio_id = EXCLUDED.municipio_id,
                        escola_id = EXCLUDED.escola_id,
                        ativo = true
                    RETURNING id
                    """,
                    (name, cpf, school["municipio_id"], school["id"]),
                ).fetchone()
                conn.execute(
                    """
                    INSERT INTO public.usuarios_cargos (usuario_id, municipio_id, escola_id, cargo, ativo)
                    VALUES (%s, %s, %s, %s::public.perfil_usuario, true)
                    ON CONFLICT (usuario_id, municipio_id, escola_id, cargo) DO UPDATE
                    SET ativo = true
                    """,
                    (user["id"], school["municipio_id"], school["id"], cargo),
                )
                conn.commit()
            self.send_json({"ok": True}, 201)
            return
        self.send_json({"error": "Rota não encontrada"}, 404)

    def do_PATCH(self):
        path = urlparse(self.path).path
        payload = self.read_json()
        if path.startswith("/api/schools/"):
            if not cloud_enabled():
                self.send_json({"error": "Supabase/PostgreSQL não configurado."}, 503)
                return
            school_id = path.rsplit("/", 1)[-1]
            with pg_connect() as conn:
                row = conn.execute(
                    """
                    UPDATE public.escolas
                    SET ativa = %s
                    WHERE id = %s
                    RETURNING id, nome, codigo_inep, endereco, etapas, ativa
                    """,
                    (bool(payload.get("active")), school_id),
                ).fetchone()
                conn.commit()
            if not row:
                self.send_json({"error": "Escola não encontrada."}, 404)
                return
            self.send_json(map_school(row))
            return
        self.send_json({"error": "Rota não encontrada"}, 404)


if __name__ == "__main__":
    init_db()
    server = ThreadingHTTPServer(("127.0.0.1", 8000), SigaeHandler)
    print("SIGAE disponível em http://127.0.0.1:8000")
    server.serve_forever()
