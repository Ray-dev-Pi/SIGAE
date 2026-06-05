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

  delete from auth.identities
  where user_id = super_admin_auth_id
    and provider = 'email';

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'auth'
      and table_name = 'identities'
      and column_name = 'provider_id'
  ) then
    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'auth'
        and table_name = 'identities'
        and column_name = 'id'
        and udt_name = 'uuid'
    ) then
      execute '
        insert into auth.identities (
          id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
        )
        values ($1, $1, $2, $3, ''email'', now(), now(), now())'
      using super_admin_auth_id, super_admin_auth_id::text, jsonb_build_object(
        'sub', super_admin_auth_id::text,
        'email', 'superadmin@sigae.local',
        'email_verified', true,
        'phone_verified', false
      );
    else
      execute '
        insert into auth.identities (
          id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
        )
        values ($1, $2, $1, $3, ''email'', now(), now(), now())'
      using super_admin_auth_id::text, super_admin_auth_id, jsonb_build_object(
        'sub', super_admin_auth_id::text,
        'email', 'superadmin@sigae.local',
        'email_verified', true,
        'phone_verified', false
      );
    end if;
  else
    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'auth'
        and table_name = 'identities'
        and column_name = 'id'
        and udt_name = 'uuid'
    ) then
      execute '
        insert into auth.identities (
          id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
        )
        values ($1, $1, $2, ''email'', now(), now(), now())'
      using super_admin_auth_id, jsonb_build_object(
        'sub', super_admin_auth_id::text,
        'email', 'superadmin@sigae.local',
        'email_verified', true,
        'phone_verified', false
      );
    else
      execute '
        insert into auth.identities (
          id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
        )
        values ($1, $2, $3, ''email'', now(), now(), now())'
      using super_admin_auth_id::text, super_admin_auth_id, jsonb_build_object(
        'sub', super_admin_auth_id::text,
        'email', 'superadmin@sigae.local',
        'email_verified', true,
        'phone_verified', false
      );
    end if;
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
