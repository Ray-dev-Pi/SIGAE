create or replace function public.login_usuario_por_cpf(login_cpf text)
returns table (
  id uuid,
  nome text,
  email text,
  cpf char(11)
)
language sql
stable
security definer
set search_path = public
as $$
  select u.id, u.nome, u.email, u.cpf
  from public.usuarios u
  where u.cpf = regexp_replace(coalesce(login_cpf, ''), '[^0-9]', '', 'g')::char(11)
    and u.ativo = true
    and u.email is not null
  limit 1
$$;

revoke all on function public.login_usuario_por_cpf(text) from public;
grant execute on function public.login_usuario_por_cpf(text) to anon, authenticated;
