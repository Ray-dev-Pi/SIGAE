do $$
declare
  super_admin_auth_id uuid;
begin
  select id
  into super_admin_auth_id
  from auth.users
  where email = 'superadmin@sigae.local'
  limit 1;

  if super_admin_auth_id is null then
    super_admin_auth_id := gen_random_uuid();

    insert into auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at
    )
    values (
      '00000000-0000-0000-0000-000000000000',
      super_admin_auth_id,
      'authenticated',
      'authenticated',
      'superadmin@sigae.local',
      crypt('055746713', gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"name":"Super Admin SIGAE","cpf":"05574671360"}'::jsonb,
      now(),
      now()
    );
  else
    update auth.users
    set encrypted_password = crypt('055746713', gen_salt('bf')),
        email_confirmed_at = coalesce(email_confirmed_at, now()),
        raw_app_meta_data = '{"provider":"email","providers":["email"]}'::jsonb,
        raw_user_meta_data = '{"name":"Super Admin SIGAE","cpf":"05574671360"}'::jsonb,
        updated_at = now()
    where id = super_admin_auth_id;
  end if;

  insert into public.usuarios (auth_user_id, nome, cpf, email, ativo)
  values (super_admin_auth_id, 'Super Admin SIGAE', '05574671360', 'superadmin@sigae.local', true)
  on conflict (cpf) do update
  set auth_user_id = excluded.auth_user_id,
      nome = excluded.nome,
      email = excluded.email,
      ativo = true;

  insert into public.usuarios_cargos (usuario_id, cargo, ativo)
  select id, 'super_admin'::public.perfil_usuario, true
  from public.usuarios
  where cpf = '05574671360'
  on conflict (usuario_id, municipio_id, escola_id, cargo) do update
  set ativo = true;
end $$;
