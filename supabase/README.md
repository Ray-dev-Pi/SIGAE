# Supabase/PostgreSQL

Este diretório contém a estrutura inicial do banco PostgreSQL do SIGAE para Supabase.

## Como aplicar

1. Abra o projeto no Supabase.
2. Acesse **SQL Editor**.
3. Execute as migrations em ordem: `001_initial_sigae_schema.sql`, `002_add_super_admin_profile.sql`, `003_seed_super_admin.sql` e `004_allow_super_admin_rls.sql`.
4. Depois configure `supabase.js` localmente a partir de `supabase.example.js`.

## Observações

- O login do frontend consulta `usuarios.cpf` e busca cargos em `usuarios_cargos`.
- A autenticação real usa `auth.users`; a tabela `usuarios` guarda os dados de domínio e referencia `auth.users.id` em `auth_user_id`.
- RLS já fica habilitado. As políticas iniciais permitem leitura para usuários autenticados e escrita para `administrador` ou `gestor_municipal`.
- Para produção, refine as políticas por município, escola, turma e vínculo do usuário.
