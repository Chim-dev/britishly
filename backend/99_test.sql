-- ============================================================
-- Britishly — 99_test.sql
-- Skrip pengecekan: memastikan schema, RLS, dan function jalan.
-- Aman dijalankan berkali-kali. Tidak wajib.
-- ============================================================
--
-- CARA PAKAI
-- Jalankan blok satu per satu di SQL Editor, jangan sekaligus,
-- supaya hasil tiap pengecekan kelihatan jelas.
-- ============================================================


-- ------------------------------------------------------------
-- CEK 1 — Tabel sudah terbentuk?
-- Harusnya muncul: daily_words, saved_words, word_synonyms
-- ------------------------------------------------------------
select table_name
from information_schema.tables
where table_schema = 'public'
order by table_name;


-- ------------------------------------------------------------
-- CEK 2 — RLS sudah aktif?
-- Kolom rowsecurity HARUS true untuk ketiga tabel.
-- Kalau ada yang false, ulangi 02_rls.sql.
-- ------------------------------------------------------------
select tablename, rowsecurity
from pg_tables
where schemaname = 'public'
order by tablename;


-- ------------------------------------------------------------
-- CEK 3 — Policy sudah terpasang?
-- Harusnya ada 4 policy untuk saved_words, 4 untuk word_synonyms,
-- dan 3 untuk daily_words.
-- ------------------------------------------------------------
select tablename, policyname, cmd
from pg_policies
where schemaname = 'public'
order by tablename, cmd;


-- ------------------------------------------------------------
-- CEK 4 — Function sudah ada?
-- Harusnya muncul: get_streak, replace_synonyms,
--                  save_word_with_synonyms, set_daily_word
-- ------------------------------------------------------------
select routine_name, data_type as return_type
from information_schema.routines
where routine_schema = 'public'
  and routine_type = 'FUNCTION'
order by routine_name;


-- ------------------------------------------------------------
-- CEK 5 — Enum status_hafalan berisi nilai yang benar?
-- Harusnya: belum, sedang, sudah
-- ------------------------------------------------------------
select enumlabel
from pg_enum e
join pg_type t on t.oid = e.enumtypid
where t.typname = 'status_hafalan'
order by e.enumsortorder;


-- ------------------------------------------------------------
-- CEK 6 — Transaction function beneran jalan?
--
-- CATATAN: di SQL Editor, auth.uid() bernilai NULL karena kamu
-- tidak login sebagai user aplikasi. Jadi query di bawah HARUS
-- gagal dengan pesan "Tidak terautentikasi".
--
-- Kalau pesan itu yang muncul, berarti function DAN pengecekan
-- keamanannya bekerja dengan benar. Itu hasil yang diharapkan.
--
-- Pengujian sungguhan dilakukan dari aplikasi Flutter setelah login.
-- ------------------------------------------------------------
select public.save_word_with_synonyms(
  p_word       => 'happy',
  p_definition => 'feeling or showing pleasure',
  p_example    => 'She was happy to see him.',
  p_category   => 'Sehari-hari',
  p_synonyms   => '[
    {"text": "delighted", "definition": "very pleased"},
    {"text": "thrilled",  "definition": "extremely happy"}
  ]'::jsonb
);


-- ------------------------------------------------------------
-- CEK 7 — Lihat isi data (setelah menyimpan dari aplikasi)
-- Di SQL Editor kamu bertindak sebagai admin, jadi bisa melihat
-- data semua user. Ini normal — RLS berlaku untuk aplikasi,
-- bukan untuk dashboard pemilik project.
-- ------------------------------------------------------------
select
  sw.word,
  sw.category,
  sw.status_hafalan,
  sw.is_favorite,
  count(ws.id) as jumlah_sinonim,
  sw.created_at
from public.saved_words sw
left join public.word_synonyms ws on ws.saved_word_id = sw.id
group by sw.id
order by sw.created_at desc;
