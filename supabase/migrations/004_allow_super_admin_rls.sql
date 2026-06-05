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
