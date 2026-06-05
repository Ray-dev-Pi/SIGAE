select
  u.id as usuario_id,
  u.auth_user_id,
  u.cpf,
  u.email,
  u.ativo,
  au.id is not null as auth_user_exists,
  au.email_confirmed_at is not null as email_confirmed,
  exists (
    select 1
    from auth.identities i
    where i.user_id = au.id
      and i.provider = 'email'
  ) as email_identity_exists,
  array_agg(c.cargo order by c.cargo) filter (where c.cargo is not null) as cargos
from public.usuarios u
left join auth.users au on au.id = u.auth_user_id
left join public.usuarios_cargos c on c.usuario_id = u.id and c.ativo = true
where u.cpf = '05574671360'
group by u.id, u.auth_user_id, u.cpf, u.email, u.ativo, au.id, au.email_confirmed_at;

select * from public.login_usuario_por_cpf('05574671360');
