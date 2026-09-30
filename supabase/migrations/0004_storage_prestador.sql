-- 0004 · Storage do cadastro do prestador
--
-- documentos  privado. BI e comprovativos em {perfil_id}/{tipo}.jpg.
--             Só o dono escreve e lê o seu prefixo; a equipa de aprovação lê
--             pelo painel (service role, que ignora a RLS).
-- publico     leitura pública. Fotos de perfil, capa e portefólio em
--             {perfil_id}/{tipo}.jpg. Só o dono escreve no seu prefixo.
--
-- A app envia com upsert (repetir um envio falhado substitui o ficheiro), por
-- isso o dono precisa de insert, update e select no seu prefixo.
-- Idempotente: pode correr mais de uma vez.

insert into storage.buckets (id, name, public)
values ('documentos', 'documentos', false)
on conflict (id) do nothing;

-- `publico` já existe; só se cria se faltar, sem mexer na configuração actual.
insert into storage.buckets (id, name, public)
values ('publico', 'publico', true)
on conflict (id) do nothing;

-- ── documentos ────────────────────────────────────────────────────────────

drop policy if exists "documentos: dono insere no seu prefixo" on storage.objects;
create policy "documentos: dono insere no seu prefixo"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'documentos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "documentos: dono lê o seu prefixo" on storage.objects;
create policy "documentos: dono lê o seu prefixo"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'documentos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "documentos: dono substitui no seu prefixo" on storage.objects;
create policy "documentos: dono substitui no seu prefixo"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'documentos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'documentos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- ── publico ───────────────────────────────────────────────────────────────
-- A leitura pública vem de `public = true` (URL público). Estas políticas só
-- tratam da escrita, e do select de que o upsert precisa.

drop policy if exists "publico: dono insere no seu prefixo" on storage.objects;
create policy "publico: dono insere no seu prefixo"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'publico'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "publico: dono lê o seu prefixo" on storage.objects;
create policy "publico: dono lê o seu prefixo"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'publico'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "publico: dono substitui no seu prefixo" on storage.objects;
create policy "publico: dono substitui no seu prefixo"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'publico'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'publico'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
