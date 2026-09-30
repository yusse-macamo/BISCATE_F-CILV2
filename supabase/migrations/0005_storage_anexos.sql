-- 0005 · Storage dos anexos dos pedidos
--
-- anexos  privado. Fotografias que o cliente junta a um pedido, em
--         {cliente_id}/{pedido_id}/{n}.jpg.
--         O cliente escreve e lê a sua pasta; o prestador do pedido lê.
--
-- A linha correspondente vai para a tabela `anexos` (pedido_id, caminho).
-- A app envia com upsert (repetir um envio falhado substitui o ficheiro),
-- por isso o dono precisa de insert, update e select.
-- Idempotente: pode correr mais de uma vez.

insert into storage.buckets (id, name, public)
values ('anexos', 'anexos', false)
on conflict (id) do nothing;

drop policy if exists "anexos: cliente insere na sua pasta" on storage.objects;
create policy "anexos: cliente insere na sua pasta"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'anexos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "anexos: cliente substitui na sua pasta" on storage.objects;
create policy "anexos: cliente substitui na sua pasta"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'anexos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'anexos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- Lê o cliente dono da pasta, e o prestador a quem o pedido foi feito.
drop policy if exists "anexos: cliente e prestador do pedido leem" on storage.objects;
create policy "anexos: cliente e prestador do pedido leem"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'anexos'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or exists (
        select 1
        from public.pedidos p
        where p.id::text = (storage.foldername(name))[2]
          and p.prestador_id = (select auth.uid())
      )
    )
  );
