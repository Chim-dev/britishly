-- ============================================================
-- Britishly — 06_sync_local_time.sql
-- Sinkronisasi waktu pergantian kata harian & streak ke waktu lokal HP (12 malam)
-- Jalankan di Supabase SQL Editor.
-- ============================================================

-- 1. Perbarui function set_daily_word agar menerima tanggal lokal HP pengguna
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

  -- Cek apakah user sudah punya kata untuk tanggal tersebut
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

  -- Jika terjadi bentrok saat insert paralel, ambil baris yang ada
  if v_row is null then
    select * into v_row
    from public.daily_words
    where user_id = v_user_id and shown_date = v_target_date;
  end if;

  return v_row;
end;
$$;

comment on function public.set_daily_word is
  'Mengambil atau mencatat kata harian berdasarkan tanggal lokal HP pengguna.';

-- 2. Perbarui function get_streak agar menghitung berdasarkan tanggal lokal HP pengguna
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

  -- Belum pernah sama sekali, atau sudah bolong lebih dari 1 hari berdasarkan waktu HP
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
    exit when v_row <> v_expected;
    v_streak   := v_streak + 1;
    v_expected := v_expected - 1;
  end loop;

  return v_streak;
end;
$$;

comment on function public.get_streak is
  'Menghitung jumlah hari beruntun streak belajar berdasarkan tanggal lokal HP pengguna.';

-- Berikan izin akses eksekusi ke authenticated users
grant execute on function public.set_daily_word(text, text, text, date) to authenticated;
grant execute on function public.get_streak(date) to authenticated;
