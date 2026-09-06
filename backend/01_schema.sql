-- ============================================================
-- Britishly — 01_schema.sql
-- Skema tabel utama (sesuai ERD)
-- Jalankan PERTAMA di Supabase SQL Editor.
-- ============================================================

-- Ekstensi untuk generate UUID (biasanya sudah aktif di Supabase)
create extension if not exists "pgcrypto";


-- ------------------------------------------------------------
-- ENUM: status hafalan
-- Dipakai kolom saved_words.status_hafalan
-- ------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'status_hafalan') then
    create type public.status_hafalan as enum ('belum', 'sedang', 'sudah');
  end if;
end
$$;


-- ------------------------------------------------------------
-- TABEL: saved_words
-- Kata yang disimpan user ke daftar pribadinya.
--
-- Relasi: USERS 1 : N SAVED_WORDS
-- user_id mengacu ke auth.users (tabel bawaan Supabase Auth).
-- ON DELETE CASCADE: kalau akun user dihapus, kosakatanya ikut terhapus.
-- ------------------------------------------------------------
create table if not exists public.saved_words (
  id              uuid                  primary key default gen_random_uuid(),
  user_id         uuid                  not null
                                        references auth.users (id) on delete cascade,
  word            text                  not null,
  definition      text,
  example         text,
  category        text                  not null default 'Sehari-hari',
  is_favorite     boolean               not null default false,
  status_hafalan  public.status_hafalan not null default 'belum',
  created_at      timestamptz           not null default now(),

  -- Satu user tidak boleh menyimpan kata yang sama dua kali
  constraint saved_words_user_word_unique unique (user_id, word),

  -- Kata tidak boleh string kosong
  constraint saved_words_word_not_blank check (length(trim(word)) > 0)
);


-- ------------------------------------------------------------
-- TABEL: word_synonyms
-- Kata bermakna serupa yang dipilih user untuk sebuah saved_word.
--
-- Relasi: SAVED_WORDS 1 : N WORD_SYNONYMS
-- ON DELETE CASCADE: inilah yang bikin "hapus kata otomatis hapus
-- sinonimnya" — tidak perlu dihapus manual dari aplikasi.
-- ------------------------------------------------------------
create table if not exists public.word_synonyms (
  id                  uuid  primary key default gen_random_uuid(),
  saved_word_id       uuid  not null
                            references public.saved_words (id) on delete cascade,
  synonym_text        text  not null,
  synonym_definition  text,

  -- Sinonim yang sama tidak boleh dobel dalam satu grup kata
  constraint word_synonyms_unique_per_word unique (saved_word_id, synonym_text),

  constraint word_synonyms_text_not_blank check (length(trim(synonym_text)) > 0)
);


-- ------------------------------------------------------------
-- INDEX
-- Mempercepat query yang paling sering dipakai aplikasi.
-- ------------------------------------------------------------

-- "Tampilkan semua kosakata milik user ini, terbaru dulu"
create index if not exists idx_saved_words_user_created
  on public.saved_words (user_id, created_at desc);

-- "Filter per kategori"
create index if not exists idx_saved_words_user_category
  on public.saved_words (user_id, category);

-- "Tampilkan hanya yang difavoritkan"
create index if not exists idx_saved_words_user_favorite
  on public.saved_words (user_id) where is_favorite = true;

-- "Ambil semua sinonim milik satu kata"
create index if not exists idx_word_synonyms_saved_word
  on public.word_synonyms (saved_word_id);


-- ------------------------------------------------------------
-- KOMENTAR (dokumentasi tabel, tampil di dashboard Supabase)
-- ------------------------------------------------------------
comment on table public.saved_words   is 'Daftar kosakata pribadi milik user';
comment on table public.word_synonyms is 'Kata bermakna serupa untuk tiap kata tersimpan';
