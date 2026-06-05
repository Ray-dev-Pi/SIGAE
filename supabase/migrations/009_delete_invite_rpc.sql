-- SIGAE - RPC for deleting token-based registration invites.

create or replace function public.apagar_convite_cadastro(convite_token text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.current_user_is_admin() then
    raise exception 'Usuário sem permissão para apagar convites.';
  end if;

  delete from public.cadastro_convites
  where token = convite_token;

  return found;
end;
$$;

revoke all on function public.apagar_convite_cadastro(text) from public;
grant execute on function public.apagar_convite_cadastro(text) to authenticated;

notify pgrst, 'reload schema';
