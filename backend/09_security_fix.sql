-- ============================================================
-- Britishly — 09_security_fix.sql
-- Perbaikan keamanan untuk database yang SUDAH menjalankan 07 & 08 versi awal.
-- Jalankan KESEMBILAN. Aman dijalankan berulang kali.
-- ============================================================


-- 1. Kata harian kini dipilih server (Edge Function jadwal-kata).
--    RPC lama ini membiarkan siapa pun menentukan kata harian semua user,
--    jadi dihapus. Deploy jadwal-kata DULU sebelum menjalankan baris ini,
--    supaya aplikasi tidak sempat kehilangan sumber kata.
drop function if exists public.usulkan_kata_harian(jsonb, date, date);


-- 2. Dipakai level-kata untuk menghitung kata baru hari ini di seluruh
--    aplikasi (batas global), supaya batas per akun tidak bisa diakali
--    dengan membuat banyak akun.
create index if not exists idx_word_levels_created_at
  on public.word_levels (created_at);
