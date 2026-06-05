-- SIGAE - PostgreSQL/Supabase initial schema
-- Execute this file in the Supabase SQL Editor or through the Supabase CLI.

create extension if not exists pgcrypto;

do $$
begin
  create type public.perfil_usuario as enum (
    'super_admin',
    'administrador',
    'gestor_municipal',
    'diretor',
    'secretaria_escolar',
    'coordenador',
    'professor',
    'aluno',
    'responsavel'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.status_matricula as enum (
    'ativa',
    'rematriculada',
    'transferida',
    'cancelada',
    'concluida',
    'evasao'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.tipo_documento as enum (
    'declaracao',
    'boletim',
    'historico',
    'ata',
    'transferencia',
    'outro'
  );
exception
  when duplicate_object then null;
end $$;

create table if not exists public.municipios (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  uf char(2) not null,
  codigo_ibge text unique,
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.escolas (
  id uuid primary key default gen_random_uuid(),
  municipio_id uuid not null references public.municipios(id) on delete cascade,
  nome text not null,
  codigo_inep text unique,
  cnpj text,
  telefone text,
  email text,
  endereco jsonb not null default '{}'::jsonb,
  etapas text[] not null default '{}',
  ativa boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.usuarios (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  municipio_id uuid references public.municipios(id) on delete set null,
  escola_id uuid references public.escolas(id) on delete set null,
  nome text not null,
  cpf char(11) not null unique check (cpf ~ '^[0-9]{11}$'),
  email text unique,
  telefone text,
  ativo boolean not null default true,
  ultimo_acesso timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.usuarios_cargos (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references public.usuarios(id) on delete cascade,
  municipio_id uuid references public.municipios(id) on delete cascade,
  escola_id uuid references public.escolas(id) on delete cascade,
  cargo public.perfil_usuario not null,
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  unique (usuario_id, municipio_id, escola_id, cargo)
);

create table if not exists public.alunos (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid unique references public.usuarios(id) on delete set null,
  municipio_id uuid not null references public.municipios(id) on delete cascade,
  nome text not null,
  cpf char(11) unique check (cpf is null or cpf ~ '^[0-9]{11}$'),
  data_nascimento date,
  sexo text,
  nis text,
  dados_censo jsonb not null default '{}'::jsonb,
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.responsaveis (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid unique references public.usuarios(id) on delete set null,
  municipio_id uuid not null references public.municipios(id) on delete cascade,
  nome text not null,
  cpf char(11) unique check (cpf ~ '^[0-9]{11}$'),
  telefone text,
  email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.alunos_responsaveis (
  aluno_id uuid not null references public.alunos(id) on delete cascade,
  responsavel_id uuid not null references public.responsaveis(id) on delete cascade,
  parentesco text not null,
  responsavel_financeiro boolean not null default false,
  primary key (aluno_id, responsavel_id)
);

create table if not exists public.professores (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid unique references public.usuarios(id) on delete set null,
  municipio_id uuid not null references public.municipios(id) on delete cascade,
  escola_id uuid references public.escolas(id) on delete set null,
  matricula_funcional text,
  formacao text,
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.disciplinas (
  id uuid primary key default gen_random_uuid(),
  municipio_id uuid not null references public.municipios(id) on delete cascade,
  nome text not null,
  codigo text,
  ativa boolean not null default true,
  unique (municipio_id, nome)
);

create table if not exists public.turmas (
  id uuid primary key default gen_random_uuid(),
  escola_id uuid not null references public.escolas(id) on delete cascade,
  ano_letivo integer not null,
  nome text not null,
  etapa text not null,
  serie text,
  turno text,
  ativa boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (escola_id, ano_letivo, nome)
);

create table if not exists public.turmas_disciplinas (
  id uuid primary key default gen_random_uuid(),
  turma_id uuid not null references public.turmas(id) on delete cascade,
  disciplina_id uuid not null references public.disciplinas(id) on delete cascade,
  professor_id uuid references public.professores(id) on delete set null,
  carga_horaria integer,
  unique (turma_id, disciplina_id)
);

create table if not exists public.matriculas (
  id uuid primary key default gen_random_uuid(),
  aluno_id uuid not null references public.alunos(id) on delete cascade,
  turma_id uuid not null references public.turmas(id) on delete restrict,
  escola_id uuid not null references public.escolas(id) on delete restrict,
  ano_letivo integer not null,
  data_matricula date not null default current_date,
  status public.status_matricula not null default 'ativa',
  observacoes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (aluno_id, ano_letivo)
);

create table if not exists public.notas (
  id uuid primary key default gen_random_uuid(),
  matricula_id uuid not null references public.matriculas(id) on delete cascade,
  disciplina_id uuid not null references public.disciplinas(id) on delete cascade,
  periodo text not null,
  avaliacao text not null,
  nota numeric(5,2) check (nota is null or (nota >= 0 and nota <= 10)),
  recuperacao numeric(5,2) check (recuperacao is null or (recuperacao >= 0 and recuperacao <= 10)),
  professor_id uuid references public.professores(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.frequencias (
  id uuid primary key default gen_random_uuid(),
  matricula_id uuid not null references public.matriculas(id) on delete cascade,
  disciplina_id uuid references public.disciplinas(id) on delete set null,
  data_aula date not null,
  presente boolean not null,
  justificativa text,
  professor_id uuid references public.professores(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (matricula_id, disciplina_id, data_aula)
);

create table if not exists public.calendarios_letivos (
  id uuid primary key default gen_random_uuid(),
  escola_id uuid references public.escolas(id) on delete cascade,
  municipio_id uuid references public.municipios(id) on delete cascade,
  ano_letivo integer not null,
  eventos jsonb not null default '[]'::jsonb,
  dias_letivos integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.documentos (
  id uuid primary key default gen_random_uuid(),
  municipio_id uuid not null references public.municipios(id) on delete cascade,
  escola_id uuid references public.escolas(id) on delete set null,
  aluno_id uuid references public.alunos(id) on delete set null,
  usuario_id uuid references public.usuarios(id) on delete set null,
  tipo public.tipo_documento not null,
  titulo text not null,
  conteudo jsonb not null default '{}'::jsonb,
  arquivo_url text,
  assinado_em timestamptz,
  emitido_em timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.ocorrencias (
  id uuid primary key default gen_random_uuid(),
  aluno_id uuid references public.alunos(id) on delete cascade,
  escola_id uuid not null references public.escolas(id) on delete cascade,
  registrado_por uuid references public.usuarios(id) on delete set null,
  titulo text not null,
  descricao text not null,
  data_ocorrencia date not null default current_date,
  encaminhamento text,
  created_at timestamptz not null default now()
);

create table if not exists public.mensagens (
  id uuid primary key default gen_random_uuid(),
  municipio_id uuid not null references public.municipios(id) on delete cascade,
  escola_id uuid references public.escolas(id) on delete cascade,
  remetente_id uuid references public.usuarios(id) on delete set null,
  titulo text not null,
  corpo text not null,
  destinatarios jsonb not null default '{}'::jsonb,
  enviada_em timestamptz not null default now()
);

create table if not exists public.mensagens_leituras (
  mensagem_id uuid not null references public.mensagens(id) on delete cascade,
  usuario_id uuid not null references public.usuarios(id) on delete cascade,
  lida_em timestamptz not null default now(),
  primary key (mensagem_id, usuario_id)
);

create table if not exists public.ava_salas (
  id uuid primary key default gen_random_uuid(),
  turma_id uuid not null references public.turmas(id) on delete cascade,
  titulo text not null,
  descricao text,
  ativa boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.ava_materiais (
  id uuid primary key default gen_random_uuid(),
  sala_id uuid not null references public.ava_salas(id) on delete cascade,
  titulo text not null,
  tipo text not null,
  url text,
  conteudo text,
  publicado_por uuid references public.usuarios(id) on delete set null,
  publicado_em timestamptz not null default now()
);

create table if not exists public.ava_atividades (
  id uuid primary key default gen_random_uuid(),
  sala_id uuid not null references public.ava_salas(id) on delete cascade,
  titulo text not null,
  descricao text,
  data_entrega timestamptz,
  questoes jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.ava_entregas (
  id uuid primary key default gen_random_uuid(),
  atividade_id uuid not null references public.ava_atividades(id) on delete cascade,
  aluno_id uuid not null references public.alunos(id) on delete cascade,
  resposta jsonb not null default '{}'::jsonb,
  arquivo_url text,
  nota numeric(5,2),
  entregue_em timestamptz not null default now(),
  unique (atividade_id, aluno_id)
);

create table if not exists public.censo_escolar_exportacoes (
  id uuid primary key default gen_random_uuid(),
  municipio_id uuid not null references public.municipios(id) on delete cascade,
  ano_letivo integer not null,
  status text not null default 'rascunho',
  inconsistencias jsonb not null default '[]'::jsonb,
  arquivo_url text,
  gerado_por uuid references public.usuarios(id) on delete set null,
  gerado_em timestamptz not null default now()
);

create table if not exists public.auditoria_logs (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid references public.usuarios(id) on delete set null,
  acao text not null,
  entidade text not null,
  entidade_id uuid,
  dados jsonb not null default '{}'::jsonb,
  ip inet,
  user_agent text,
  created_at timestamptz not null default now()
);

create index if not exists idx_usuarios_cpf on public.usuarios(cpf);
create index if not exists idx_usuarios_auth_user_id on public.usuarios(auth_user_id);
create index if not exists idx_usuarios_cargos_usuario on public.usuarios_cargos(usuario_id);
create index if not exists idx_escolas_municipio on public.escolas(municipio_id);
create index if not exists idx_alunos_municipio on public.alunos(municipio_id);
create index if not exists idx_matriculas_turma on public.matriculas(turma_id);
create index if not exists idx_notas_matricula on public.notas(matricula_id);
create index if not exists idx_frequencias_matricula on public.frequencias(matricula_id);
create index if not exists idx_documentos_aluno on public.documentos(aluno_id);
create index if not exists idx_auditoria_usuario on public.auditoria_logs(usuario_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_municipios_updated_at on public.municipios;
create trigger set_municipios_updated_at
before update on public.municipios
for each row execute function public.set_updated_at();

drop trigger if exists set_escolas_updated_at on public.escolas;
create trigger set_escolas_updated_at
before update on public.escolas
for each row execute function public.set_updated_at();

drop trigger if exists set_usuarios_updated_at on public.usuarios;
create trigger set_usuarios_updated_at
before update on public.usuarios
for each row execute function public.set_updated_at();

drop trigger if exists set_alunos_updated_at on public.alunos;
create trigger set_alunos_updated_at
before update on public.alunos
for each row execute function public.set_updated_at();

drop trigger if exists set_matriculas_updated_at on public.matriculas;
create trigger set_matriculas_updated_at
before update on public.matriculas
for each row execute function public.set_updated_at();

drop trigger if exists set_notas_updated_at on public.notas;
create trigger set_notas_updated_at
before update on public.notas
for each row execute function public.set_updated_at();

create or replace function public.current_usuario_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.usuarios where auth_user_id = auth.uid() limit 1
$$;

create or replace function public.current_user_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.usuarios u
    join public.usuarios_cargos c on c.usuario_id = u.id
    where u.auth_user_id = auth.uid()
      and c.ativo = true
      and c.cargo in ('super_admin', 'administrador', 'gestor_municipal')
  )
$$;

alter table public.municipios enable row level security;
alter table public.escolas enable row level security;
alter table public.usuarios enable row level security;
alter table public.usuarios_cargos enable row level security;
alter table public.alunos enable row level security;
alter table public.responsaveis enable row level security;
alter table public.alunos_responsaveis enable row level security;
alter table public.professores enable row level security;
alter table public.disciplinas enable row level security;
alter table public.turmas enable row level security;
alter table public.turmas_disciplinas enable row level security;
alter table public.matriculas enable row level security;
alter table public.notas enable row level security;
alter table public.frequencias enable row level security;
alter table public.calendarios_letivos enable row level security;
alter table public.documentos enable row level security;
alter table public.ocorrencias enable row level security;
alter table public.mensagens enable row level security;
alter table public.mensagens_leituras enable row level security;
alter table public.ava_salas enable row level security;
alter table public.ava_materiais enable row level security;
alter table public.ava_atividades enable row level security;
alter table public.ava_entregas enable row level security;
alter table public.censo_escolar_exportacoes enable row level security;
alter table public.auditoria_logs enable row level security;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'municipios', 'escolas', 'usuarios', 'usuarios_cargos', 'alunos',
    'responsaveis', 'alunos_responsaveis', 'professores', 'disciplinas',
    'turmas', 'turmas_disciplinas', 'matriculas', 'notas', 'frequencias',
    'calendarios_letivos', 'documentos', 'ocorrencias', 'mensagens',
    'mensagens_leituras', 'ava_salas', 'ava_materiais', 'ava_atividades',
    'ava_entregas', 'censo_escolar_exportacoes', 'auditoria_logs'
  ]
  loop
    execute format('drop policy if exists %I on public.%I', 'authenticated_read_' || table_name, table_name);
    execute format(
      'create policy %I on public.%I for select to authenticated using (true)',
      'authenticated_read_' || table_name,
      table_name
    );

    execute format('drop policy if exists %I on public.%I', 'admin_write_' || table_name, table_name);
    execute format(
      'create policy %I on public.%I for all to authenticated using (public.current_user_is_admin()) with check (public.current_user_is_admin())',
      'admin_write_' || table_name,
      table_name
    );
  end loop;
end $$;
