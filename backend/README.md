# Backend — Supabase

Folder ini berisi **skrip SQL**, bukan server terpisah. Supabase yang bertindak
sebagai backend; file di sini adalah rancangan database yang dijalankan lewat
**SQL Editor** di dashboard Supabase.

---

## Urutan menjalankan

Buka [supabase.com](https://supabase.com) → project kamu → menu **SQL Editor** →
**New query** → copy-paste isi file → klik **Run**. Lakukan **berurutan**:

| # | File | Isi |
|:--:|---|---|
| 1 | `01_schema.sql` | Enum `status_hafalan`, tabel `saved_words` & `word_synonyms`, index |
| 2 | `02_rls.sql` | Row Level Security — wajib, jangan dilewat |
| 3 | `03_transaction_function.sql` | Transaction function `save_word_with_synonyms` |
| 4 | `04_daily_word.sql` | Tabel `daily_words` + function streak |
| — | `99_test.sql` | Opsional — untuk mengecek semuanya jalan |
| — | `00_reset.sql` | ⚠️ Hapus semuanya. Hanya kalau mau mengulang dari nol |

Urutannya tidak boleh diacak: `02` butuh tabel dari `01`, `03` butuh keduanya.

---

## Setelah selesai

Ambil kredensial dari `Settings → API Keys`, lalu simpan di **`frontend/.env`**
(bukan di root — Flutter hanya bisa membaca file di dalam folder project-nya):

```env
SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOi...
```

> Pakai **anon public** atau **publishable key**, bukan `service_role` /
> `secret key`. Yang terakhir mem-bypass seluruh RLS — kalau tertanam di
> dalam APK, siapa pun bisa membaca dan menghapus data semua user.

---

## Cara memanggil dari Flutter

Tabel biasa (CRUD langsung):

```dart
// READ — daftar kosakata milik user yang sedang login
final data = await supabase
    .from('saved_words')
    .select('*, word_synonyms(*)')
    .order('created_at', ascending: false);

// UPDATE — ubah status hafalan
await supabase
    .from('saved_words')
    .update({'status_hafalan': 'sudah'})
    .eq('id', wordId);

// DELETE — sinonim ikut terhapus otomatis (ON DELETE CASCADE)
await supabase.from('saved_words').delete().eq('id', wordId);
```

Function (dipanggil pakai `.rpc()`):

```dart
// CREATE — kata + sinonim sekaligus, atomic
final newId = await supabase.rpc('save_word_with_synonyms', params: {
  'p_word': 'happy',
  'p_definition': 'feeling or showing pleasure',
  'p_example': 'She was happy to see him.',
  'p_category': 'Sehari-hari',
  'p_synonyms': [
    {'text': 'delighted', 'definition': 'very pleased'},
    {'text': 'thrilled',  'definition': 'extremely happy'},
  ],
});

// Kata harian + streak
final daily  = await supabase.rpc('set_daily_word', params: {
  'p_word': 'serendipity',
  'p_definition': 'finding something good without looking for it',
});
final streak = await supabase.rpc('get_streak');
```

Perhatikan: **tidak perlu mengirim `user_id`**. Function mengambilnya sendiri
dari `auth.uid()`, dan RLS memastikan user tidak bisa menyentuh data orang lain.

---

## Catatan penting

**1. ERD perlu ditambah satu entitas.**
`04_daily_word.sql` menambahkan tabel `DAILY_WORDS` yang belum ada di ERD.
Tanpa tabel ini, streak hilang setiap user ganti HP. Penjelasan lengkap ada
di komentar paling atas file tersebut.

**2. Soal `BEGIN ... COMMIT / ROLLBACK`.**
Di PostgreSQL, isi sebuah function otomatis berjalan dalam satu transaksi —
`COMMIT` / `ROLLBACK` eksplisit justru tidak boleh ditulis di dalamnya.
Sifat atomic-nya tetap terpenuhi penuh: `RETURN` = commit, error = rollback
seluruhnya. Baca komentar di `03_transaction_function.sql` sebelum presentasi,
karena ini sering ditanyakan.

**3. Aktifkan email confirmation sesuai kebutuhan.**
Di `Authentication → Providers → Email`, kalau **Confirm email** aktif, user
harus klik link di email dulu sebelum bisa login. Untuk mempermudah demo,
kamu boleh mematikannya sementara.
