# Edge Functions — Supabase

Folder ini berisi kode yang berjalan **di server Supabase**, bukan di HP.

Ada tiga function:

- **`jelaskan-kata`** — perantara ke Google Gemini untuk fitur penjelasan AI.
- **`level-kata`** — perantara ke Gemini untuk label level CEFR (A1–C2).
  Lihat bagian [level-kata](#level-kata).
- **`jadwal-kata`** — memilih kata harian bersama dari Datamuse. Lihat bagian
  [jadwal-kata](#jadwal-kata).

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
supabase functions deploy level-kata
supabase functions deploy jadwal-kata
```

`jelaskan-kata` butuh tabel dari `backend/10_ai_explanation_limit.sql`,
`level-kata` dari `backend/08_word_levels.sql`, dan `jadwal-kata`
dari `backend/07_daily_word_schedule.sql` — jalankan file-file itu di SQL
Editor lebih dulu. Untuk database yang sudah menjalankan 07 & 08 versi awal,
deploy `jadwal-kata` dulu, baru jalankan `backend/09_security_fix.sql`.

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
| `JATAH_HABIS` | 429 | Jatah 5 penjelasan per hari milik user ini habis |
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

**Batas 5 panggilan Gemini per pengguna per hari** (`BATAS_HARIAN` di
`index.ts`, tabel dari `backend/10_ai_explanation_limit.sql`). Dulu sengaja
tanpa batas, tapi cache di HP tidak menghalangi siapa pun yang memanggil
function ini langsung dengan kata berbeda terus-menerus — dan kuota Gemini
dipakai bersama `level-kata`, jadi satu akun bisa mematikan keduanya.

Supaya batas seketat itu tidak terasa, ada tiga lapis cache, dan **hanya
panggilan yang benar-benar sampai ke Gemini yang memakan jatah**:

| Lapis | Tempat | Memakan jatah? |
|---|---|:--:|
| Memori + simpanan HP (maks 200 kata) | aplikasi (`LayananGemini`) | tidak |
| Tabel `ai_explanations`, dipakai bersama semua user, umur 7 hari | server | tidak |
| Panggilan Gemini | server | **ya** |

Kalau Gemini gagal menjawab (model tidak tersedia, format salah, kuota
Gemini habis), jatahnya dikembalikan. Entri cache yang lebih dari 7 hari
dihapus tiap malam oleh pg_cron (job `hapus-cache-penjelasan-ai`).

---

## level-kata

Menentukan level CEFR banyak kata sekaligus. Body: `{"kata": ["eloquent", ...]}`
(maks 25), balasan: `{"level": {"eloquent": "C1", ...}}`.

Berbeda dengan `jelaskan-kata`, function ini **punya batas per pengguna**:
maksimal **100 kata baru per akun per hari** (`BATAS_HARIAN` di `index.ts`),
plus **1000 kata baru per hari untuk seluruh aplikasi**
(`BATAS_GLOBAL_HARIAN`) supaya batas per akun tidak bisa diakali dengan
membuat banyak akun.
Alasannya: label level dimuat otomatis setiap kali kartu tampil, bukan karena
pengguna menekan tombol — jadi lebih gampang menghabiskan kuota tanpa sadar.

Lapisan penghematnya:

| Lapisan | Tempat |
|---|---|
| Tabel `word_levels` dipakai bersama semua user — satu kata cukup ditanyakan sekali | server |
| Banyak kata dalam satu permintaan Gemini | server + aplikasi |
| Cache memori + HP (maks 2000 kata) | aplikasi (`LayananLevelKata`) |
| Hanya kata yang sedang tampil di layar yang ditanyakan | aplikasi (`LabelLevel`) |
| Jatah 100 kata baru / akun / hari | server (`pakai_kuota_level`) |
| Batas 1000 kata baru / hari untuk seluruh aplikasi | server |
| Kuota habis / gagal → label disembunyikan, tidak dicoba lagi sampai app dibuka ulang | aplikasi |

Kalau kuota Gemini habis, balasan tetap `200` berisi level yang sudah diketahui
plus `"kuota_habis": true`; jatah harian habis ditandai `"terbatas": true`.

Input hanya menerima **satu kata tanpa spasi**. Hasilnya disimpan permanen
untuk semua user, dan input berspasi bisa dipakai menyisipkan perintah ke
prompt untuk meracuni level kata lain.

---

## jadwal-kata

Mengembalikan jadwal kata harian bersama untuk rentang tanggal tertentu.
Body: `{"dari": "2026-10-16", "sampai": "2026-10-30"}`, balasan:
`{"jadwal": {"2026-10-16": "eloquent", ...}}`. Tanggal yang masih kosong
diisi kata acak dari Datamuse **oleh server**.

Rentang dibatasi kemarin s/d 20 hari ke depan (tanggal server, UTC).

**Kenapa kata dipilih di server, bukan di HP:** versi awal membiarkan HP
mengusulkan kata lewat RPC `usulkan_kata_harian`, dan usulan pertama yang
menang. Siapa pun yang memanggil RPC itu langsung bisa menentukan kata harian
semua user untuk 20 hari ke depan — termasuk kata kasar. RPC itu dihapus di
`backend/09_security_fix.sql`; tabel `daily_word_schedule` kini hanya bisa
ditulis function ini.
