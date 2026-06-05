-- SIGAE - RPC for creating registration invites in production.
-- Keeps token generation in the frontend, but centralizes authorization and
-- persistence in the database.

create or replace function public.criar_convite_cadastro(
  convite_token text,
  convite_cargo public.perfil_usuario,
  convite_nome_destinatario text default null,
  convite_email_destinatario text default null
)
returns table (
  id uuid,
  token text,
  cargo text,
  nome_destinatario text,
  email_destinatario text,
  status text,
  expira_em timestamptz,
  criado_em timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  usuario_atual uuid;
begin
  if not public.current_user_is_admin() then
    raise exception 'Usuário sem permissão para gerar convites.';
  end if;

  usuario_atual := public.current_usuario_id();

  return query
  insert into public.cadastro_convites (
    token,
    cargo,
    nome_destinatario,
    email_destinatario,
    criado_por
  )
  values (
    convite_token,
    convite_cargo,
    nullif(trim(coalesce(convite_nome_destinatario, '')), ''),
    nullif(lower(trim(coalesce(convite_email_destinatario, ''))), ''),
    usuario_atual
  )
  returning
    cadastro_convites.id,
    cadastro_convites.token,
    cadastro_convites.cargo::text,
    cadastro_convites.nome_destinatario,
    cadastro_convites.email_destinatario,
    cadastro_convites.status,
    cadastro_convites.expira_em,
    cadastro_convites.criado_em;
end;
$$;

revoke all on function public.criar_convite_cadastro(text, public.perfil_usuario, text, text) from public;
grant execute on function public.criar_convite_cadastro(text, public.perfil_usuario, text, text) to authenticated;

notify pgrst, 'reload schema';
