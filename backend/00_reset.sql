-- ============================================================
-- Britishly — 00_reset.sql
--
-- ⚠️⚠️  HATI-HATI  ⚠️⚠️
-- Skrip ini MENGHAPUS SEMUA tabel, function, dan SELURUH DATA
-- kosakata yang sudah tersimpan. Tidak bisa dibatalkan.
--
-- Pakai HANYA kalau ingin membangun ulang database dari nol
-- (misalnya salah jalankan urutan file, atau mau demo bersih).
--
-- Akun user di auth.users TIDAK ikut terhapus.
-- ============================================================
--
-- Setelah menjalankan file ini, ulangi dari:
--   01_schema.sql -> 02_rls.sql -> 03_transaction_function.sql ->
--   04_daily_word.sql -> 05_delete_account.sql -> 06_sync_local_time.sql
--
-- Jangan berhenti di 04: tanpa 05 fitur hapus akun hilang, dan tanpa 06
-- kata harian & streak kembali memakai tanggal server (UTC), bukan tanggal
-- lokal HP pengguna.
-- ============================================================


-- Hapus function lebih dulu (tidak boleh ada yang mengacu ke tabel)
--
-- PENTING: di PostgreSQL, DROP FUNCTION mencocokkan sampai ke daftar
-- parameternya. Signature yang salah tidak error — cuma tidak menghapus
-- apa-apa (karena ada IF EXISTS), jadi function lamanya diam-diam tertinggal.
--
-- 06_sync_local_time.sql menambahkan parameter tanggal ke dua function di
-- bawah, jadi versi yang berlaku sekarang adalah get_streak(date) dan
-- set_daily_word(text, text, text, date). Versi tanpa parameter tanggal
-- ikut didaftarkan di sini supaya database yang belum sempat menjalankan 06
-- juga ikut bersih.
drop function if exists public.get_streak(date);
drop function if exists public.get_streak();
drop function if exists public.set_daily_word(text, text, text, date);
drop function if exists public.set_daily_word(text, text, text);
drop function if exists public.hapus_akun_saya();
drop function if exists public.replace_synonyms(uuid, jsonb);
drop function if exists public.save_word_with_synonyms(text, text, text, text, jsonb);

-- Hapus tabel. CASCADE ikut membuang policy dan index-nya.
drop table if exists public.daily_words   cascade;
drop table if exists public.word_synonyms cascade;
drop table if exists public.saved_words   cascade;

-- Hapus tipe enum
drop type if exists public.status_hafalan;
