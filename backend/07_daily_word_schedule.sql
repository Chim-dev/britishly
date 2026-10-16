-- ============================================================
-- Britishly — 07_daily_word_schedule.sql
-- Jadwal kata harian BERSAMA: satu tanggal = satu kata untuk semua user
-- Jalankan KETUJUH, setelah 06_sync_local_time.sql.
-- ============================================================
--
-- Kenapa perlu?
--   Notifikasi lokal harus sudah tahu kata besok saat dijadwalkan, padahal
--   kata diambil acak dari Datamuse API. Kalau tiap HP mengacak sendiri,
--   dua HP dengan satu akun bisa dapat kata berbeda. Tabel ini jadi sumber
--   tunggal untuk semua HP.
--
-- Isinya dipilih dan ditulis HANYA oleh Edge Function `jadwal-kata`
-- (service role). HP tidak bisa mengusulkan kata — kalau bisa, siapa pun
-- bisa menentukan kata harian semua user, termasuk kata kasar.
--
-- Ukurannya tidak ikut bertambah per user: 1 baris per hari, ±40 KB/tahun.
-- ============================================================


-- ------------------------------------------------------------
-- TABEL: daily_word_schedule
-- ------------------------------------------------------------
create table if not exists public.daily_word_schedule (
  shown_date  date        primary key,
  -- Dibatasi huruf kecil a–z supaya isian iseng tidak bisa masuk
  word        text        not null check (word ~ '^[a-z]{3,20}$'),
  created_at  timestamptz not null default now()
);

comment on table public.daily_word_schedule is
  'Kata harian bersama per tanggal; dibaca layar Kata Harian & notifikasi';


-- ------------------------------------------------------------
-- RLS — semua user login boleh membaca, TIDAK ada yang boleh
-- insert/update/delete. Yang menulis hanya Edge Function jadwal-kata.
-- ------------------------------------------------------------
alter table public.daily_word_schedule enable row level security;

drop policy if exists "daily_word_schedule_select" on public.daily_word_schedule;
create policy "daily_word_schedule_select"
  on public.daily_word_schedule for select
  to authenticated
  using (true);
