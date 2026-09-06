-- ============================================================
-- Britishly — 03_transaction_function.sql
-- TRANSACTION FUNCTION (poin 7 pada dokumen perancangan)
-- Jalankan KETIGA, setelah 02_rls.sql.
-- ============================================================
--
-- MASALAH YANG DISELESAIKAN
-- Menyimpan 1 kata beserta beberapa sinonim melibatkan 2 tahap:
--   1. INSERT ke saved_words        -> menghasilkan id baru
--   2. INSERT beberapa baris ke word_synonyms yang memakai id tersebut
--
-- Kalau tahap 1 berhasil tapi tahap 2 gagal (koneksi putus, data tidak
-- valid, dsb), database menyimpan kata TANPA sinonim -> data tidak
-- konsisten. Karena itu keduanya dibungkus jadi SATU unit kerja atomic:
-- berhasil semua, atau tidak sama sekali.
--
--
-- CATATAN PENTING SOAL "BEGIN ... COMMIT / ROLLBACK"
-- Di PostgreSQL, isi sebuah FUNCTION otomatis berjalan di dalam satu
-- transaksi. Perintah COMMIT / ROLLBACK eksplisit justru TIDAK boleh
-- ditulis di dalam function (akan error), karena transaksinya dikelola
-- oleh Postgres sendiri.
--
-- Yang terjadi sebenarnya:
--   BEGIN        -> membuka blok PL/pgSQL sekaligus awal unit transaksi
--   RETURN       -> semua perubahan di-COMMIT otomatis
--   RAISE/error  -> SELURUH perubahan di-ROLLBACK otomatis
--
-- Jadi sifat atomic-nya nyata dan tetap terpenuhi. Blok EXCEPTION di
-- bawah sengaja ditulis eksplisit supaya perilaku rollback itu terlihat
-- jelas dan bisa dijelaskan saat presentasi.
-- ============================================================


-- ------------------------------------------------------------
-- FUNCTION: save_word_with_synonyms
--
-- Parameter p_synonyms berupa JSON array, contoh:
--   [
--     {"text": "delighted", "definition": "very pleased"},
--     {"text": "thrilled",  "definition": "extremely happy"}
--   ]
--
-- Mengembalikan: id (uuid) dari kata yang baru tersimpan.
--
-- SECURITY INVOKER = function berjalan sebagai user yang memanggil,
-- sehingga policy RLS tetap berlaku. (Jangan diubah ke DEFINER —
-- itu akan mem-bypass RLS dan membuka celah keamanan.)
-- ------------------------------------------------------------
create or replace function public.save_word_with_synonyms(
  p_word        text,
  p_definition  text  default null,
  p_example     text  default null,
  p_category    text  default 'Sehari-hari',
  p_synonyms    jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id       uuid := auth.uid();
  v_saved_word_id uuid;
  v_synonym       jsonb;
  v_text          text;
begin
  -- ---- Validasi awal -------------------------------------------------
  if v_user_id is null then
    raise exception 'Tidak terautentikasi. Silakan login terlebih dahulu.'
      using errcode = '28000';
  end if;

  if p_word is null or length(trim(p_word)) = 0 then
    raise exception 'Kata tidak boleh kosong.'
      using errcode = '22023';
  end if;

  if jsonb_typeof(p_synonyms) <> 'array' then
    raise exception 'Parameter p_synonyms harus berupa JSON array.'
      using errcode = '22023';
  end if;

  -- ---- TAHAP 1: simpan kata utama ------------------------------------
  insert into public.saved_words (user_id, word, definition, example, category)
  values (
    v_user_id,
    trim(p_word),
    p_definition,
    p_example,
    coalesce(nullif(trim(p_category), ''), 'Sehari-hari')
  )
  returning id into v_saved_word_id;

  -- ---- TAHAP 2: simpan seluruh sinonim terpilih -----------------------
  -- Kalau ada satu saja yang gagal di sini, TAHAP 1 ikut dibatalkan.
  for v_synonym in select * from jsonb_array_elements(p_synonyms)
  loop
    v_text := trim(coalesce(v_synonym ->> 'text', ''));

    -- Lewati entri kosong, jangan sampai bikin transaksi gagal
    continue when v_text = '';

    insert into public.word_synonyms (saved_word_id, synonym_text, synonym_definition)
    values (v_saved_word_id, v_text, v_synonym ->> 'definition')
    on conflict (saved_word_id, synonym_text) do nothing;
  end loop;

  -- Sampai di sini semua berhasil -> Postgres COMMIT otomatis
  return v_saved_word_id;

exception
  -- Kata sudah pernah disimpan user ini (kena unique constraint)
  when unique_violation then
    raise exception 'Kata "%" sudah ada di daftar kosakatamu.', trim(p_word)
      using errcode = '23505';

  -- Error lain apa pun -> ROLLBACK otomatis atas SEMUA insert di atas
  when others then
    raise exception 'Gagal menyimpan kata: %', sqlerrm;
end;
$$;

comment on function public.save_word_with_synonyms is
  'Menyimpan satu kata beserta sinonim terpilih secara atomic (transaction function).';


-- ------------------------------------------------------------
-- FUNCTION: replace_synonyms
-- Mengganti seluruh sinonim sebuah kata dalam satu transaksi.
-- Dipakai use case "Mengelola Daftar Kosakata" (Update).
-- ------------------------------------------------------------
create or replace function public.replace_synonyms(
  p_saved_word_id uuid,
  p_synonyms      jsonb default '[]'::jsonb
)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_synonym jsonb;
  v_text    text;
  v_count   integer := 0;
begin
  if v_user_id is null then
    raise exception 'Tidak terautentikasi.' using errcode = '28000';
  end if;

  -- Pastikan kata ini memang milik user yang sedang login
  if not exists (
    select 1 from public.saved_words
    where id = p_saved_word_id and user_id = v_user_id
  ) then
    raise exception 'Kata tidak ditemukan atau bukan milikmu.'
      using errcode = '42501';
  end if;

  -- Hapus lama + isi baru, keduanya dalam satu transaksi
  delete from public.word_synonyms where saved_word_id = p_saved_word_id;

  for v_synonym in select * from jsonb_array_elements(p_synonyms)
  loop
    v_text := trim(coalesce(v_synonym ->> 'text', ''));
    continue when v_text = '';

    insert into public.word_synonyms (saved_word_id, synonym_text, synonym_definition)
    values (p_saved_word_id, v_text, v_synonym ->> 'definition')
    on conflict (saved_word_id, synonym_text) do nothing;

    v_count := v_count + 1;
  end loop;

  return v_count;

exception
  when others then
    raise exception 'Gagal memperbarui sinonim: %', sqlerrm;
end;
$$;

comment on function public.replace_synonyms is
  'Mengganti seluruh sinonim sebuah kata secara atomic.';
