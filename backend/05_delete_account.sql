-- ============================================================
-- Britishly — 05_delete_account.sql
-- Function untuk menghapus akun pengguna saat ini secara permanen
-- Jalankan di Supabase SQL Editor.
-- ============================================================

create or replace function public.hapus_akun_saya()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  -- Ambil ID user yang sedang login dari sesi autentikasi Supabase
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Tidak ada sesi login yang valid.';
  end if;

  -- Hapus user dari auth.users.
  -- Karena foreign key pada tabel public.saved_words memiliki constraint
  -- ON DELETE CASCADE, semua kata tersimpan dan sinonimnya otomatis terhapus bersih.
  delete from auth.users where id = v_user_id;
end;
$$;

-- Beri izin akses ke pengguna yang sudah login (authenticated)
grant execute on function public.hapus_akun_saya() to authenticated;
