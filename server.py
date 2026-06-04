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

ROOT = Path(__file__).resolve().parent
DB_PATH = ROOT / "sigae.db"
SCHEMA_PATH = ROOT / "schema.sql"


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
        ("Administrador SIGAE", "admin@sigae.local", "00000000000", "Administrador"),
        ("Helena Duarte", "diretor@sigae.local", "11111111111", "Diretor"),
        ("Rafael Martins", "multi@sigae.local", "22222222222", "Professor,Gestor municipal"),
        ("Clara Nascimento", "professor@sigae.local", "33333333333", "Professor"),
    ]
    with connect() as conn:
        conn.executescript(SCHEMA_PATH.read_text())
        columns = [row["name"] for row in conn.execute("PRAGMA table_info(users)").fetchall()]
        if "cpf" not in columns:
            conn.execute("ALTER TABLE users ADD COLUMN cpf TEXT")
        conn.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_users_cpf ON users(cpf)")
        for name, email, cpf, role in seed_users:
            conn.execute(
                """
                INSERT INTO users (name, email, cpf, role, password_hash)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(email) DO UPDATE SET name = excluded.name, cpf = excluded.cpf, role = excluded.role
                """,
                (name, email, cpf, role, hash_password("sigae123")),
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
        self.send_json({"error": "Rota não encontrada"}, 404)


if __name__ == "__main__":
    init_db()
    server = ThreadingHTTPServer(("127.0.0.1", 8000), SigaeHandler)
    print("SIGAE disponível em http://127.0.0.1:8000")
    server.serve_forever()
