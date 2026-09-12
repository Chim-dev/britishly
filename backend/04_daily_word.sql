-- ============================================================
-- Britishly — 04_daily_word.sql
-- Use case #4: "Melihat Kata Harian" + streak
-- Jalankan KEEMPAT, setelah 03_transaction_function.sql.
-- ============================================================
--
-- ⚠️  PERHATIAN — ERD PERLU DITAMBAH SATU ENTITAS
--
-- ERD-mu saat ini punya 3 entitas: USERS, SAVED_WORDS, WORD_SYNONYMS.
-- Tapi use case "Melihat Kata Harian + streak" butuh tempat menyimpan
-- riwayat kata apa yang muncul di tanggal berapa — tanpa itu, streak
-- akan hilang setiap kali user ganti HP atau reinstall aplikasi.
--
-- Maka ditambahkan satu entitas: DAILY_WORDS
--
--   USERS 1 ── N DAILY_WORDS
--
--   DAILY_WORDS
--     id          (uuid)  PK
--     user_id     (uuid)  FK -> USERS
--     word        (string)
--     definition  (string)
--     example     (string)
--     shown_date  (date)
--
-- Tolong tambahkan entitas ini ke gambar ERD-mu supaya rancangan dan
-- implementasi tetap sinkron. Streak sendiri TIDAK disimpan sebagai
-- kolom — nilainya dihitung dari tanggal-tanggal di tabel ini, supaya
-- tidak mungkin jadi tidak konsisten.
-- ============================================================


-- ------------------------------------------------------------
-- TABEL: daily_words
-- ------------------------------------------------------------
create table if not exists public.daily_words (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null
                          references auth.users (id) on delete cascade,
  word        text        not null,
  definition  text,
  example     text,
  shown_date  date        not null default current_date,

  -- Satu user hanya boleh punya satu kata per tanggal
  constraint daily_words_one_per_day unique (user_id, shown_date)
);

create index if not exists idx_daily_words_user_date
  on public.daily_words (user_id, shown_date desc);

comment on table public.daily_words is
  'Riwayat kata harian per user; dasar perhitungan streak';


-- ------------------------------------------------------------
-- RLS
-- ------------------------------------------------------------
alter table public.daily_words enable row level security;

drop policy if exists "daily_words_select_own" on public.daily_words;
create policy "daily_words_select_own"
  on public.daily_words for select
  using (auth.uid() = user_id);

drop policy if exists "daily_words_insert_own" on public.daily_words;
create policy "daily_words_insert_own"
  on public.daily_words for insert
  with check (auth.uid() = user_id);

drop policy if exists "daily_words_delete_own" on public.daily_words;
create policy "daily_words_delete_own"
  on public.daily_words for delete
  using (auth.uid() = user_id);


-- ------------------------------------------------------------
-- FUNCTION: set_daily_word
--
-- Alur di aplikasi Flutter:
--   1. Panggil function ini setiap kali layar "Kata Hari Ini" dibuka
--   2. Kalau user SUDAH punya kata untuk hari ini -> kata itu yang
--      dikembalikan (tidak berubah-ubah walau layar dibuka berkali-kali)
--   3. Kalau BELUM -> kata baru yang dikirim aplikasi disimpan
--
-- Jadi aplikasi yang memilih katanya (dari Dictionary API), database
-- yang menjaga agar satu hari tetap satu kata.
-- ------------------------------------------------------------
create or replace function public.set_daily_word(
  p_word        text,
  p_definition  text default null,
  p_example     text default null,
  p_date        date default current_date
)
returns public.daily_words
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id     uuid := auth.uid();
  v_row         public.daily_words;
  v_target_date date := coalesce(p_date, current_date);
begin
  if v_user_id is null then
    raise exception 'Tidak terautentikasi.' using errcode = '28000';
  end if;

  -- Sudah ada kata untuk tanggal ini? Kembalikan yang itu.
  select * into v_row
  from public.daily_words
  where user_id = v_user_id and shown_date = v_target_date;

  if found then
    return v_row;
  end if;

  if p_word is null or length(trim(p_word)) = 0 then
    raise exception 'Kata harian tidak boleh kosong.' using errcode = '22023';
  end if;

  insert into public.daily_words (user_id, word, definition, example, shown_date)
  values (v_user_id, trim(p_word), p_definition, p_example, v_target_date)
  on conflict (user_id, shown_date) do nothing
  returning * into v_row;

  -- Kalau bentrok (dibuka dari 2 device bersamaan), ambil yang sudah ada
  if v_row is null then
    select * into v_row
    from public.daily_words
    where user_id = v_user_id and shown_date = v_target_date;
  end if;

  return v_row;
end;
$$;

comment on function public.set_daily_word is
  'Mengambil kata harian user hari ini (berdasarkan tanggal lokal); membuat baru bila belum ada.';


-- ------------------------------------------------------------
-- FUNCTION: get_streak
--
-- Menghitung berapa hari berturut-turut user membuka kata harian.
-- Dihitung mundur dari hari terakhir yang tercatat.
--
-- Aturan:
--   - Terakhir buka hari ini atau kemarin  -> streak masih hidup
--   - Terakhir buka >= 2 hari lalu         -> streak putus, kembali 0
-- ------------------------------------------------------------
create or replace function public.get_streak(
  p_today date default current_date
)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id     uuid := auth.uid();
  v_streak      integer := 0;
  v_last        date;
  v_expected    date;
  v_row         date;
  v_target_date date := coalesce(p_today, current_date);
begin
  if v_user_id is null then
    return 0;
  end if;

  select max(shown_date) into v_last
  from public.daily_words
  where user_id = v_user_id;

  -- Belum pernah sama sekali, atau sudah bolong lebih dari 1 hari berdasarkan waktu lokal user
  if v_last is null or v_last < v_target_date - 1 then
    return 0;
  end if;

  v_expected := v_last;

  for v_row in
    select shown_date
    from public.daily_words
    where user_id = v_user_id and shown_date <= v_last
    order by shown_date desc
  loop
    exit when v_row <> v_expected;   -- ketemu tanggal bolong, berhenti
    v_streak   := v_streak + 1;
    v_expected := v_expected - 1;
  end loop;

  return v_streak;
end;
$$;

comment on function public.get_streak is
  'Menghitung jumlah hari beruntun user membuka kata harian berdasarkan tanggal lokal HP.';

