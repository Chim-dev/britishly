-- ============================================================
-- Britishly — 08_word_levels.sql
-- Label level CEFR (A1–C2) per kata, ditentukan Gemini
-- Jalankan KEDELAPAN, setelah 07_daily_word_schedule.sql.
-- ============================================================
--
-- Hemat kuota Gemini:
--   - word_levels dipakai BERSAMA semua user. Satu kata cukup ditanyakan
--     ke Gemini sekali seumur hidup; user berikutnya tinggal membaca.
--   - word_level_usage membatasi berapa kata BARU yang boleh ditanyakan
--     satu akun per hari, supaya satu akun iseng tidak menghabiskan kuota.
--
-- Kedua tabel hanya DITULIS oleh Edge Function `level-kata` (service role).
-- User biasa cuma boleh membaca word_levels.
-- ============================================================


-- ------------------------------------------------------------
-- TABEL: word_levels
-- ------------------------------------------------------------
create table if not exists public.word_levels (
  word        text        primary key check (word ~ '^[a-z][a-z ''-]{0,39}$'),
  level       text        not null check (level in ('A1', 'A2', 'B1', 'B2', 'C1', 'C2')),
  created_at  timestamptz not null default now()
);

comment on table public.word_levels is
  'Level CEFR per kata, hasil Gemini; dibagi ke semua user';

alter table public.word_levels enable row level security;

drop policy if exists "word_levels_select" on public.word_levels;
create policy "word_levels_select"
  on public.word_levels for select
  to authenticated
  using (true);


-- ------------------------------------------------------------
-- TABEL: word_level_usage — jatah kata baru per user per hari
-- Tanpa policy sama sekali: tidak bisa dibaca/ditulis dari aplikasi.
-- Isinya cuma 1 baris per user (baris hari sebelumnya dibuang).
-- ------------------------------------------------------------
create table if not exists public.word_level_usage (
  user_id     uuid  not null references auth.users (id) on delete cascade,
  usage_date  date  not null,
  jumlah      int   not null default 0,
  primary key (user_id, usage_date)
);

alter table public.word_level_usage enable row level security;


-- ------------------------------------------------------------
-- FUNCTION: pakai_kuota_level
--
-- Memesan sampai p_minta kata dari jatah harian p_batas milik p_user,
-- lalu mengembalikan berapa yang BOLEH ditanyakan (0..p_minta).
-- Baris dikunci (FOR UPDATE) supaya permintaan bersamaan tidak bisa
-- melewati batas.
-- ------------------------------------------------------------
create or replace function public.pakai_kuota_level(
  p_user   uuid,
  p_minta  int,
  p_batas  int
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_terpakai int;
  v_boleh    int;
begin
  delete from public.word_level_usage
  where user_id = p_user and usage_date < current_date;

  insert into public.word_level_usage (user_id, usage_date, jumlah)
  values (p_user, current_date, 0)
  on conflict (user_id, usage_date) do nothing;

  select jumlah into v_terpakai
  from public.word_level_usage
  where user_id = p_user and usage_date = current_date
  for update;

  v_boleh := greatest(0, least(p_minta, p_batas - v_terpakai));

  update public.word_level_usage
  set jumlah = jumlah + v_boleh
  where user_id = p_user and usage_date = current_date;

  return v_boleh;
end;
$$;

-- Hanya Edge Function (service role) yang boleh memanggil. Kalau user
-- biasa bisa, mereka bisa menghabiskan / mengakali jatah akun lain.
revoke execute on function public.pakai_kuota_level(uuid, int, int) from public, anon, authenticated;
grant execute on function public.pakai_kuota_level(uuid, int, int) to service_role;
