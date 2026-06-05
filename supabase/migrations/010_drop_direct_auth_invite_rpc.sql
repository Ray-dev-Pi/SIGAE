-- SIGAE - remove the direct Auth-user invite RPC.
-- Invited users must be created through Supabase Auth signUp, then linked to
-- public.usuarios by aceitar_convite_cadastro. Direct inserts into auth.users
-- are not compatible with this project's Auth runtime.

drop function if exists public.aceitar_convite_cadastro_com_senha(text, text, text, text, text);

notify pgrst, 'reload schema';
