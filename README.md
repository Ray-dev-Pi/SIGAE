# SIGAE

SIGAE - Sistema Integrado de Gestão Administrativa e Educacional.

Este repositório contém uma primeira versão navegável da plataforma web solicitada. A interface foi criada em HTML, CSS e JavaScript puro, e há também um backend mínimo em Python/SQLite com API REST, banco relacional, autenticação com hash de senha e auditoria inicial.

## Como abrir

Opção estática:

Abra o arquivo `index.html` diretamente no navegador.

Opção com API local:

```bash
python3 server.py
```

Depois acesse `http://127.0.0.1:8000`.

Opção com API salvando no Supabase/PostgreSQL:

```bash
DATABASE_URL="postgresql://..." python3 server.py
```

Com `DATABASE_URL` configurado, a aba Super Admin grava escolas, ativa/inativa unidades e cadastra diretores/secretárias diretamente no PostgreSQL do Supabase.

O acesso usa CPF e senha de usuários cadastrados no backend local ou, em produção, no Supabase.

## Recursos implementados nesta versão

- Layout responsivo para computador, tablet e smartphone.
- Tela de login institucional, responsiva e sem exposição de dados operacionais.
- Identificação automática por cargo cadastrado.
- Escolha de perfil quando o usuário possui mais de um cargo.
- Navegação por módulos respeitando o perfil ativo.
- Painel executivo com indicadores, gráficos CSS e tabela de escolas.
- Telas de cadastros, vida escolar, documentos, relatórios, AVA e Censo Escolar.
- Busca global por alunos e escolas.
- Cadastro rápido com persistência em `localStorage`.
- API REST inicial em `/api/health`, `/api/dashboard`, `/api/records`, `/api/audit` e `/api/login`.
- Banco SQLite criado automaticamente a partir de `schema.sql`.
- Senhas protegidas com PBKDF2 e salt por usuário.
- Área lateral com alertas, auditoria e status operacional.
- Preparação para Supabase em `supabase.example.js`, com tabelas previstas para usuários, cargos, matrículas, notas e frequências.
- Migration PostgreSQL/Supabase em `supabase/migrations/001_initial_sigae_schema.sql`.

## Próximos passos técnicos

- Criar o projeto Supabase, executar a migration em `supabase/migrations` e copiar `supabase.example.js` para `supabase.js` com URL e chave pública real.
- Ativar políticas RLS no Supabase por município, escola e perfil.
- Implementar exportação real em PDF, Excel e layouts oficiais do Censo Escolar.
- Adicionar testes automatizados e pipeline de implantação em nuvem.
