-- SIGAE - production repair for token-based registration invites.
-- Use this migration when an existing Supabase project already has the core
-- SIGAE schema, but is missing cadastro_convites and its invite RPCs.

create extension if not exists pgcrypto;

create table if not exists public.cadastro_convites (
  id uuid primary key default gen_random_uuid(),
  token text not null unique,
  cargo public.perfil_usuario not null,
  nome_destinatario text,
  email_destinatario text,
  municipio_id uuid references public.municipios(id) on delete set null,
  escola_id uuid references public.escolas(id) on delete set null,
  status text not null default 'pendente' check (status in ('pendente', 'utilizado', 'expirado', 'cancelado')),
  criado_por uuid references public.usuarios(id) on delete set null,
  usado_por uuid references public.usuarios(id) on delete set null,
  expira_em timestamptz not null default (now() + interval '7 days'),
  criado_em timestamptz not null default now(),
  usado_em timestamptz
);

create index if not exists idx_cadastro_convites_token on public.cadastro_convites(token);
create index if not exists idx_cadastro_convites_status on public.cadastro_convites(status);

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

alter table public.cadastro_convites enable row level security;

drop policy if exists authenticated_read_cadastro_convites on public.cadastro_convites;
create policy authenticated_read_cadastro_convites
on public.cadastro_convites
for select to authenticated
using (true);

drop policy if exists admin_write_cadastro_convites on public.cadastro_convites;
create policy admin_write_cadastro_convites
on public.cadastro_convites
for all to authenticated
using (public.current_user_is_admin())
with check (public.current_user_is_admin());

create or replace function public.buscar_convite_cadastro(convite_token text)
returns table (
  token text,
  cargo text,
  nome_destinatario text,
  email_destinatario text,
  status text,
  expira_em timestamptz,
  escola_nome text,
  municipio_nome text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.token,
    c.cargo::text,
    c.nome_destinatario,
    c.email_destinatario,
    case
      when c.status = 'pendente' and c.expira_em < now() then 'expirado'
      else c.status
    end as status,
    c.expira_em,
    e.nome as escola_nome,
    m.nome as municipio_nome
  from public.cadastro_convites c
  left join public.escolas e on e.id = c.escola_id
  left join public.municipios m on m.id = c.municipio_id
  where c.token = convite_token
  limit 1
$$;

revoke all on function public.buscar_convite_cadastro(text) from public;
grant execute on function public.buscar_convite_cadastro(text) to anon, authenticated;

create or replace function public.aceitar_convite_cadastro(
  convite_token text,
  cadastro_nome text,
  cadastro_cpf text,
  cadastro_email text,
  cadastro_auth_user_id uuid
)
returns table (
  usuario_id uuid,
  cargo text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  convite public.cadastro_convites%rowtype;
  usuario_id_criado uuid;
  cpf_digits text;
begin
  cpf_digits := regexp_replace(coalesce(cadastro_cpf, ''), '[^0-9]', '', 'g');

  select *
  into convite
  from public.cadastro_convites
  where token = convite_token
  for update;

  if convite.id is null then
    raise exception 'Convite não encontrado.';
  end if;
  if convite.status <> 'pendente' or convite.expira_em < now() then
    raise exception 'Convite expirado ou já utilizado.';
  end if;
  if length(cpf_digits) <> 11 then
    raise exception 'CPF inválido.';
  end if;

  insert into public.usuarios (auth_user_id, municipio_id, escola_id, nome, cpf, email, ativo)
  values (
    cadastro_auth_user_id,
    convite.municipio_id,
    convite.escola_id,
    trim(cadastro_nome),
    cpf_digits,
    lower(trim(cadastro_email)),
    true
  )
  on conflict (cpf) do update
  set auth_user_id = excluded.auth_user_id,
      municipio_id = excluded.municipio_id,
      escola_id = excluded.escola_id,
      nome = excluded.nome,
      email = excluded.email,
      ativo = true
  returning id into usuario_id_criado;

  insert into public.usuarios_cargos (usuario_id, municipio_id, escola_id, cargo, ativo)
  values (usuario_id_criado, convite.municipio_id, convite.escola_id, convite.cargo, true)
  on conflict (usuario_id, municipio_id, escola_id, cargo) do update
  set ativo = true;

  update public.cadastro_convites
  set status = 'utilizado',
      usado_por = usuario_id_criado,
      usado_em = now()
  where id = convite.id;

  return query select usuario_id_criado, convite.cargo::text;
end;
$$;

revoke all on function public.aceitar_convite_cadastro(text, text, text, text, uuid) from public;
grant execute on function public.aceitar_convite_cadastro(text, text, text, text, uuid) to anon, authenticated;

notify pgrst, 'reload schema';
