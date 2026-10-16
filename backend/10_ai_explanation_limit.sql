-- ============================================================
-- Britishly — 10_ai_explanation_limit.sql
-- Penjelasan AI (Edge Function jelaskan-kata): cache bersama 7 hari
-- + jatah 5 panggilan Gemini per user per hari.
-- Jalankan KESEPULUH, setelah 09_security_fix.sql.
-- ============================================================
--
-- Alur di jelaskan-kata:
--   1. Kata ada di ai_explanations (umur < 7 hari) -> langsung dikembalikan.
--      TIDAK mengurangi jatah, TIDAK memanggil Gemini.
--   2. Belum ada -> pakai 1 jatah (maks 5/hari). Jatah habis -> ditolak.
--   3. Panggil Gemini -> simpan ke ai_explanations. Gagal -> jatah
--      dikembalikan, supaya gangguan Gemini tidak memakan jatah user.
--
-- Cache di HP tetap jalan seperti biasa; yang sudah ada di HP tidak pernah
-- sampai ke server sama sekali.
-- ============================================================


-- ------------------------------------------------------------
-- TABEL: ai_explanations — cache bersama semua user
-- Tanpa policy: hanya Edge Function (service role) yang membaca/menulis.
-- ------------------------------------------------------------
create table if not exists public.ai_explanations (
  word        text        primary key check (word ~ '^[a-z][a-z ''-]{0,39}$'),
  data        jsonb       not null,
  created_at  timestamptz not null default now()
);

create index if not exists idx_ai_explanations_created_at
  on public.ai_explanations (created_at);

alter table public.ai_explanations enable row level security;


-- ------------------------------------------------------------
-- TABEL: ai_explanation_usage — jatah per user per hari
-- Tanpa policy. Isinya cuma 1 baris per user (baris lama dibuang).
-- ------------------------------------------------------------
create table if not exists public.ai_explanation_usage (
  user_id     uuid  not null references auth.users (id) on delete cascade,
  usage_date  date  not null,
  jumlah      int   not null default 0,
  primary key (user_id, usage_date)
);

alter table public.ai_explanation_usage enable row level security;


-- ------------------------------------------------------------
-- FUNCTION: pakai_kuota_penjelasan
-- Mengambil 1 jatah. true = boleh memanggil Gemini, false = jatah habis.
-- Baris dikunci (FOR UPDATE) supaya permintaan bersamaan tidak bisa
-- melewati batas.
-- ------------------------------------------------------------
create or replace function public.pakai_kuota_penjelasan(
  p_user   uuid,
  p_batas  int
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_terpakai int;
begin
  delete from public.ai_explanation_usage
  where user_id = p_user and usage_date < current_date;

  insert into public.ai_explanation_usage (user_id, usage_date, jumlah)
  values (p_user, current_date, 0)
  on conflict (user_id, usage_date) do nothing;

  select jumlah into v_terpakai
  from public.ai_explanation_usage
  where user_id = p_user and usage_date = current_date
  for update;

  if v_terpakai >= p_batas then
    return false;
  end if;

  update public.ai_explanation_usage
  set jumlah = jumlah + 1
  where user_id = p_user and usage_date = current_date;

  return true;
end;
$$;


-- ------------------------------------------------------------
-- FUNCTION: kembalikan_kuota_penjelasan
-- Mengembalikan 1 jatah ketika Gemini gagal menjawab.
-- ------------------------------------------------------------
create or replace function public.kembalikan_kuota_penjelasan(p_user uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.ai_explanation_usage
  set jumlah = greatest(0, jumlah - 1)
  where user_id = p_user and usage_date = current_date;
$$;

-- Hanya Edge Function (service role) yang boleh memanggil keduanya.
revoke execute on function public.pakai_kuota_penjelasan(uuid, int) from public, anon, authenticated;
revoke execute on function public.kembalikan_kuota_penjelasan(uuid) from public, anon, authenticated;
grant execute on function public.pakai_kuota_penjelasan(uuid, int) to service_role;
grant execute on function public.kembalikan_kuota_penjelasan(uuid) to service_role;


-- ------------------------------------------------------------
-- HAPUS OTOMATIS: penjelasan berumur lebih dari 7 hari, tiap malam
-- pukul 03:00 UTC (10:00 WIB). Memakai pg_cron, tersedia juga di paket
-- gratis Supabase.
--
-- jelaskan-kata sendiri juga mengabaikan entri > 7 hari, jadi umur
-- cache tetap tepat 7 hari walaupun jadwal ini sempat telat.
--
-- Memanggil cron.schedule dengan nama yang sama akan memperbarui jadwal
-- yang sudah ada, jadi file ini aman dijalankan ulang.
-- ------------------------------------------------------------
create extension if not exists pg_cron;

select cron.schedule(
  'hapus-cache-penjelasan-ai',
  '0 3 * * *',
  $$delete from public.ai_explanations where created_at < now() - interval '7 days'$$
);
