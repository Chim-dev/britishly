-- ============================================================
-- Britishly — 02_rls.sql
-- Row Level Security: user hanya bisa mengakses datanya sendiri.
-- Jalankan KEDUA, setelah 01_schema.sql.
-- ============================================================
--
-- PENTING: Tanpa RLS, siapa pun yang punya anon key (yang tertanam
-- di dalam APK, jadi bisa dibaca orang) bisa membaca SELURUH isi
-- database. RLS bukan opsional — ini pengaman utamanya.
--
-- auth.uid() = UUID user yang sedang login, disediakan Supabase Auth.
-- ============================================================


-- ------------------------------------------------------------
-- Aktifkan RLS
-- ------------------------------------------------------------
alter table public.saved_words   enable row level security;
alter table public.word_synonyms enable row level security;


-- ------------------------------------------------------------
-- POLICY: saved_words
-- Pemilik ditentukan langsung dari kolom user_id.
-- ------------------------------------------------------------

drop policy if exists "saved_words_select_own" on public.saved_words;
create policy "saved_words_select_own"
  on public.saved_words
  for select
  using (auth.uid() = user_id);

drop policy if exists "saved_words_insert_own" on public.saved_words;
create policy "saved_words_insert_own"
  on public.saved_words
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "saved_words_update_own" on public.saved_words;
create policy "saved_words_update_own"
  on public.saved_words
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "saved_words_delete_own" on public.saved_words;
create policy "saved_words_delete_own"
  on public.saved_words
  for delete
  using (auth.uid() = user_id);


-- ------------------------------------------------------------
-- POLICY: word_synonyms
-- Tabel ini tidak punya kolom user_id, jadi kepemilikan dicek
-- lewat tabel induknya (saved_words).
-- ------------------------------------------------------------

drop policy if exists "word_synonyms_select_own" on public.word_synonyms;
create policy "word_synonyms_select_own"
  on public.word_synonyms
  for select
  using (
    exists (
      select 1 from public.saved_words sw
      where sw.id = word_synonyms.saved_word_id
        and sw.user_id = auth.uid()
    )
  );

drop policy if exists "word_synonyms_insert_own" on public.word_synonyms;
create policy "word_synonyms_insert_own"
  on public.word_synonyms
  for insert
  with check (
    exists (
      select 1 from public.saved_words sw
      where sw.id = word_synonyms.saved_word_id
        and sw.user_id = auth.uid()
    )
  );

drop policy if exists "word_synonyms_update_own" on public.word_synonyms;
create policy "word_synonyms_update_own"
  on public.word_synonyms
  for update
  using (
    exists (
      select 1 from public.saved_words sw
      where sw.id = word_synonyms.saved_word_id
        and sw.user_id = auth.uid()
    )
  );

drop policy if exists "word_synonyms_delete_own" on public.word_synonyms;
create policy "word_synonyms_delete_own"
  on public.word_synonyms
  for delete
  using (
    exists (
      select 1 from public.saved_words sw
      where sw.id = word_synonyms.saved_word_id
        and sw.user_id = auth.uid()
    )
  );
