# Supabase/PostgreSQL

Este diretório contém a estrutura inicial do banco PostgreSQL do SIGAE para Supabase.

## Como aplicar

1. Abra o projeto no Supabase.
2. Acesse **SQL Editor**.
3. Execute as migrations em ordem: `001_initial_sigae_schema.sql`, `002_add_super_admin_profile.sql`, `003_seed_super_admin.sql`, `004_allow_super_admin_rls.sql`, `005_login_lookup_by_cpf.sql`, `006_repair_super_admin_login.sql`, `007_create_registration_invites.sql`, `008_create_invite_rpc.sql`, `009_delete_invite_rpc.sql` e `010_drop_direct_auth_invite_rpc.sql`.
4. Depois publique um `supabase.js` de produção a partir de `supabase.example.js`, com a URL e a anon key reais do projeto.

## Observações

- O login do frontend usa a RPC `login_usuario_por_cpf` para localizar o e-mail por CPF antes do Supabase Auth e depois busca cargos em `usuarios_cargos`.
- A autenticação real usa `auth.users`; a tabela `usuarios` guarda os dados de domínio e referencia `auth.users.id` em `auth_user_id`.
- RLS já fica habilitado. As políticas iniciais permitem leitura para usuários autenticados e escrita para `super_admin`, `administrador` ou `gestor_municipal`.
- Para produção, refine as políticas por município, escola, turma e vínculo do usuário.
