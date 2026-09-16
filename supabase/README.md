# Edge Functions — Supabase

Folder ini berisi kode yang berjalan **di server Supabase**, bukan di HP.

Saat ini ada satu function: **`jelaskan-kata`** — perantara ke Google Gemini
untuk fitur penjelasan AI.

---

## Kenapa ini ada

Dulu aplikasi memanggil Gemini langsung dari HP, dengan `GEMINI_API_KEY`
dibaca dari `frontend/.env`. Masalahnya, `.env` didaftarkan sebagai **asset
Flutter** di `pubspec.yaml`, jadi file itu ikut terbungkus apa adanya ke dalam
APK:

```
app-release.apk
└── assets/flutter_assets/.env      ← plaintext, tinggal di-unzip
```

Untuk anon key Supabase itu tidak masalah — key itu memang dirancang publik,
dan yang menjaga data tetap Row Level Security. Tapi **Gemini API key adalah
kredensial billing**. Tidak ada RLS yang menjaganya; siapa pun yang
mengambilnya bisa memakai kuota atas tagihan pemilik aplikasi.

Ini tidak bisa ditambal di sisi aplikasi. Mau diobfuscate atau dienkripsi
sekalipun, key-nya tetap harus utuh di memori saat dipakai — jadi selalu bisa
diambil. Satu-satunya perbaikan nyata adalah memindahkan pemanggilannya ke
server, yaitu function ini.

### Apa yang berubah

|  | Sebelum | Sesudah |
|---|---|---|
| Lokasi key | `frontend/.env` → ikut ke APK | Secret di server Supabase |
| Pemanggil Gemini | HP pengguna | Edge Function |
| Siapa yang boleh memakai | siapa pun yang punya APK | hanya akun yang sudah login (JWT diverifikasi) |
| Isi prompt | dirakit di HP | dirakit di server |

Poin terakhir juga penting: karena prompt dirakit di server dan input yang
diterima hanya **satu kata bahasa Inggris** (divalidasi dengan regex),
endpoint ini tidak bisa dibajak jadi layanan AI gratis untuk teks sembarang.

---

## Cara memasang

### 1. Pasang Supabase CLI

```powershell
npm install -g supabase
```

Alternatif tanpa Node: `scoop install supabase`, atau unduh dari
<https://github.com/supabase/cli/releases>.

Cek berhasil:

```powershell
supabase --version
```

### 2. Login & hubungkan ke project

```powershell
supabase login
supabase init      # lewati kalau supabase/config.toml sudah ada
supabase link --project-ref <PROJECT_REF>
```

`supabase init` cuma membuat `config.toml`; folder `functions/` yang sudah ada
tidak akan ditimpa. Kalau dia menolak karena folder `supabase/` sudah ada,
tambahkan `--force`.

`<PROJECT_REF>` adalah bagian subdomain dari `SUPABASE_URL` di
`frontend/.env` — pada `https://abcdefgh.supabase.co`, ref-nya `abcdefgh`.

### 3. Pasang API key sebagai secret

> ⚠️ **Pakai key yang BARU.** Key lama pernah ikut terbungkus ke dalam APK,
> jadi harus dianggap sudah bocor. Buat key baru di
> <https://aistudio.google.com/apikey>, lalu **hapus key lama** di sana.

```powershell
supabase secrets set GEMINI_API_KEY=AIza...key_baru...
```

Cek sudah masuk (yang ditampilkan cuma nama + hash, bukan isinya):

```powershell
supabase secrets list
```

### 4. Deploy

```powershell
supabase functions deploy jelaskan-kata
```

### 5. Bersihkan `.env` aplikasi

Hapus baris `GEMINI_API_KEY=...` dari `frontend/.env`. Aplikasi sudah tidak
membacanya lagi, dan membiarkannya di sana berarti key tetap ikut ke APK
tanpa guna.

---

## Menguji

### Dari terminal

```powershell
supabase functions serve jelaskan-kata
```

Lalu di terminal lain:

```powershell
curl -X POST http://localhost:54321/functions/v1/jelaskan-kata `
  -H "Authorization: Bearer <ANON_KEY>" `
  -H "Content-Type: application/json" `
  -d '{\"kata\":\"eloquent\"}'
```

### Dari aplikasi

Buka satu kata, tekan kartu penjelasan AI. Kalau berhasil, tampilannya sama
persis seperti sebelumnya — perubahan ini memang tidak mengubah apa pun yang
dilihat pengguna.

### Melihat log

```powershell
supabase functions logs jelaskan-kata
```

Isi balasan Google hanya masuk log server, tidak pernah diteruskan ke HP —
pesan error Gemini kadang memuat potongan konfigurasi project.

---

## Kode error

Function selalu membalas JSON berbentuk `{ "error": "KODE", "pesan": "..." }`.
Sisi Flutter memetakannya di `LayananGemini._terjemahkanError`, berdasarkan
**kode**, bukan mencocokkan potongan teks — supaya tidak patah kalau redaksi
pesannya diubah.

| Kode | HTTP | Arti |
|---|:--:|---|
| `KATA_TIDAK_VALID` | 400 | Input bukan satu kata bahasa Inggris |
| `BADAN_TIDAK_VALID` | 400 | Body bukan JSON `{kata}` |
| `BELUM_MASUK` | 401 | Token bukan milik pengguna sungguhan (mis. anon key) |
| *(tanpa kode)* | 401 | Tanpa header `Authorization` — ditolak Supabase sebelum function jalan |
| `METODE_SALAH` | 405 | Bukan POST |
| `KUOTA_HABIS` | 429 | Kuota Gemini tercapai |
| `KUNCI_BELUM_DIATUR` | 503 | Secret `GEMINI_API_KEY` belum dipasang |
| `AI_BERMASALAH` | 502 | Gemini membalas error |
| `AI_KOSONG` / `FORMAT_SALAH` | 502 | Jawaban Gemini tidak bisa dibaca |
| `AI_TIDAK_TERSEDIA` | 502 | Seluruh model kandidat gagal |

---

## Catatan

**`verify_jwt` saja TIDAK cukup.** Ini sudah diuji langsung, bukan dugaan.

`verify_jwt` bawaan Supabase menolak permintaan tanpa header `Authorization`,
tapi yang diperiksanya hanya *"apakah ini JWT sah milik project ini"* — dan
**anon key memenuhi syarat itu**. Anon key tertanam di dalam APK, jadi
mengandalkan `verify_jwt` saja berarti siapa pun yang meng-unzip APK tetap
bisa memakai kuota Gemini-mu tanpa punya akun.

Hasil uji pada versi tanpa penjagaan tambahan:

| Permintaan | Hasil |
|---|---|
| Tanpa `Authorization` | `401 Missing authorization header` |
| Dengan **anon key** dari APK | **lolos** sampai ke kode function |

Karena itu ada blok `getUser()` di awal `index.ts`. Fungsinya menukar token
dengan identitas pengguna sungguhan; anon key tidak mewakili siapa-siapa, jadi
ditolak dengan `BELUM_MASUK`. Biarkan `verify_jwt` tetap menyala — keduanya
saling melengkapi, bukan saling menggantikan.

**Tidak ada rate limit per pengguna — ini disengaja.** Membatasi jumlah
penjelasan yang boleh diminta terasa janggal untuk aplikasi belajar kosakata:
orang yang sedang rajin justru yang paling kena.

Keputusan itu berpijak pada dua syarat. Selama keduanya benar, kerugian
terburuk sudah terbatas dengan sendirinya:

1. **Billing tidak aktif** di project Google-nya. Kuota habis berarti fitur AI
   mati sampai besok — tidak ada tagihan yang jalan.
2. **Aplikasi hanya dibagikan ke lingkaran terbatas**, bukan dipublikasikan.

Perlu dicatat: cache dua tingkat di sisi aplikasi **tidak** menggantikan rate
limit. Cache mencegah kata yang sama dipanggil dua kali — hemat untuk
pemakaian wajar, tapi tidak menghalangi siapa pun yang sengaja meminta kata
berbeda terus-menerus.

**Kapan ini harus ditinjau ulang:** begitu billing diaktifkan, atau aplikasi
dipublikasikan ke Play Store. Saat itu batas atas kerugiannya hilang, dan
pembatasan berbasis tabel di function ini jadi perlu.
