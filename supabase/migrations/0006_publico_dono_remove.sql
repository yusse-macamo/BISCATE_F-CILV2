-- 0006 · Remover ficheiros do próprio no bucket `publico`
--
-- A galeria de trabalhos deixa o prestador remover fotografias. A app apaga
-- primeiro a linha em `portfolio` e depois o ficheiro em
-- publico/{perfil_id}/portfolio_{millis}.jpg. Sem esta política, a linha
-- desaparece mas o ficheiro fica no Storage.
-- Idempotente.

drop policy if exists "publico: dono remove no seu prefixo" on storage.objects;
create policy "publico: dono remove no seu prefixo"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'publico'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
