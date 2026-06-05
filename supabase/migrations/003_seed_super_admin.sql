insert into public.usuarios (nome, cpf, email, ativo)
values ('Super Admin SIGAE', '05574671360', 'superadmin@sigae.local', true)
on conflict (cpf) do update
set nome = excluded.nome,
    email = excluded.email,
    ativo = true;

insert into public.usuarios_cargos (usuario_id, cargo, ativo)
select id, 'super_admin'::public.perfil_usuario, true
from public.usuarios
where cpf = '05574671360'
on conflict (usuario_id, municipio_id, escola_id, cargo) do update
set ativo = true;
