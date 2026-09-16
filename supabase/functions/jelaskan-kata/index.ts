// ============================================================
// Edge Function: jelaskan-kata
//
// Menggantikan pemanggilan Gemini langsung dari aplikasi.
//
// KENAPA ADA FILE INI
// Sebelumnya GEMINI_API_KEY ditaruh di frontend/.env, dan .env itu
// didaftarkan sebagai asset Flutter — artinya ikut terbungkus apa adanya
// ke dalam APK. Siapa pun yang meng-unzip APK bisa mengambilnya, lalu
// memakai kuota billing Google milik pemilik aplikasi.
//
// Itu tidak bisa ditambal di sisi aplikasi: mau diobfuscate atau dienkripsi
// sekalipun, key-nya tetap harus utuh saat dipakai. Satu-satunya perbaikan
// nyata adalah memindahkan pemanggilannya ke server — file ini.
//
// Key-nya sekarang hidup sebagai secret Supabase, tidak pernah dikirim ke HP.
// Cara memasangnya ada di supabase/README.md
// ============================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

const HEADER_CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/// Daftar model kandidat, dicoba berurutan. Kalau satu model dihentikan
/// Google (404) atau sedang padat (503), otomatis lanjut ke berikutnya.
const DAFTAR_MODEL = [
  "gemini-flash-lite-latest",
  "gemini-3.5-flash-lite",
  "gemini-flash-latest",
  "gemini-3.5-flash",
  "gemini-2.5-flash",
];

/// Batas waktu satu panggilan model sebelum pindah ke cadangan.
const BATAS_WAKTU_MS = 12_000;

/// Hanya menerima satu kata / frasa pendek bahasa Inggris.
const POLA_KATA = /^[a-z][a-z '-]*$/;

/// Jawaban error yang bentuknya konsisten, supaya sisi Flutter bisa
/// memetakannya ke pesan ramah tanpa menebak-nebak isi teks.
function balasError(kode: string, status: number, pesan: string): Response {
  return new Response(JSON.stringify({ error: kode, pesan }), {
    status,
    headers: { ...HEADER_CORS, "Content-Type": "application/json" },
  });
}

/// Membuang pembungkus ```json ... ``` kalau model tetap menambahkannya
/// meski sudah diminta membalas JSON murni.
function bersihkanPagarMarkdown(teks: string): string {
  let hasil = teks.trim();
  if (hasil.startsWith("```json")) hasil = hasil.slice(7);
  else if (hasil.startsWith("```")) hasil = hasil.slice(3);
  if (hasil.endsWith("```")) hasil = hasil.slice(0, -3);
  return hasil.trim();
}

function rakitPrompt(kata: string): string {
  return [
    `Explain the English word "${kata}" clearly for an Indonesian language learner. DO NOT USE ANY EMOTICON OR EMOJI`,
    "Return JSON ONLY with the following schema:",
    "{",
    `  "kata": "${kata}",`,
    '  "arti_indonesia": "Arti utama yang paling tepat dan alami dalam Bahasa Indonesia (1-3 kata) tanpa menggunakan emoji",',
    '  "definisi_simpel": "Definisi dalam bahasa Inggris yang mudah dipahami pembelajar (1 kalimat) tanpa menggunakan emoji",',
    '  "nuansa": "Penjelasan singkat dalam Bahasa Indonesia tentang kapan kata ini tepat dipakai (misal: formal/santai, emosi yang dibawa, atau perbedaan dengan kata umum)",',
    '  "contoh": [',
    "    {",
    '      "en": "Natural English example sentence using the word",',
    '      "id": "Terjemahan kalimat contoh ke Bahasa Indonesia yang alami"',
    "    },",
    "    {",
    '      "en": "A second practical daily example sentence",',
    '      "id": "Terjemahan kalimat kedua ke Bahasa Indonesia"',
    "    }",
    "  ]",
    "}",
  ].join("\n");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: HEADER_CORS });
  }

  if (req.method !== "POST") {
    return balasError("METODE_SALAH", 405, "Gunakan POST.");
  }

  // ---- 0. Pastikan pemanggilnya benar-benar pengguna yang sudah login --
  //
  // JANGAN HAPUS BLOK INI, dan jangan menggantinya dengan mengandalkan
  // verify_jwt saja.
  //
  // verify_jwt bawaan Supabase memang menolak permintaan tanpa header
  // Authorization, tapi yang diverifikasinya cuma "apakah ini JWT sah milik
  // project ini" — dan ANON KEY memenuhi syarat itu. Anon key tertanam di
  // dalam APK, jadi siapa pun yang meng-unzip APK bisa memanggil endpoint ini
  // tanpa pernah punya akun. Sudah diuji: anon key saja lolos sampai ke kode
  // di bawah.
  //
  // getUser() menutup celah itu. Dia menukar token dengan identitas pengguna
  // sungguhan ke server auth; anon key tidak mewakili siapa-siapa, jadi
  // ditolak di sini.
  const headerAuth = req.headers.get("Authorization") ?? "";
  const klienAuth = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    { global: { headers: { Authorization: headerAuth } } },
  );

  const { data: { user }, error: galatAuth } = await klienAuth.auth.getUser();
  if (galatAuth || !user) {
    return balasError(
      "BELUM_MASUK",
      401,
      "Masuk dulu untuk memakai penjelasan AI.",
    );
  }

  // ---- 1. Ambil & validasi input -------------------------------------
  //
  // Validasi ini bukan formalitas. Tanpa batas bentuk, siapa pun yang sudah
  // punya akun bisa mengirim teks apa saja ke sini dan memakai endpoint ini
  // sebagai LLM gratis atas tagihan pemilik aplikasi. Karena prompt dirakit
  // di server dan input yang diterima hanya satu kata bahasa Inggris, ruang
  // penyalahgunaannya nyaris tidak ada.
  let kata: string;
  try {
    const badan = await req.json();
    kata = String(badan?.kata ?? "").trim().toLowerCase();
  } catch {
    return balasError(
      "BADAN_TIDAK_VALID",
      400,
      "Body harus JSON berisi {kata}.",
    );
  }

  if (kata.length === 0) {
    return balasError("KATA_TIDAK_VALID", 400, "Kata tidak boleh kosong.");
  }
  if (kata.length > 40) {
    return balasError("KATA_TIDAK_VALID", 400, "Kata terlalu panjang.");
  }
  if (!POLA_KATA.test(kata)) {
    return balasError(
      "KATA_TIDAK_VALID",
      400,
      "Hanya menerima satu kata atau frasa bahasa Inggris.",
    );
  }

  // ---- 2. Ambil API key dari secret server ----------------------------
  const apiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
  if (!apiKey) {
    return balasError(
      "KUNCI_BELUM_DIATUR",
      503,
      "GEMINI_API_KEY belum dipasang sebagai secret di Supabase.",
    );
  }

  const badanGemini = JSON.stringify({
    contents: [{ parts: [{ text: rakitPrompt(kata) }] }],
    generationConfig: {
      responseMimeType: "application/json",
      temperature: 0.2,
    },
  });

  // ---- 3. Panggil model, dengan cadangan otomatis ----------------------
  let terakhirGagal = "Model AI tidak tersedia.";

  for (const model of DAFTAR_MODEL) {
    let res: Response;
    try {
      res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            // Key dikirim lewat header, bukan query string, supaya tidak ikut
            // tercatat di log akses perantara mana pun.
            "x-goog-api-key": apiKey,
          },
          body: badanGemini,
          signal: AbortSignal.timeout(BATAS_WAKTU_MS),
        },
      );
    } catch (e) {
      // Timeout atau jaringan bermasalah -> coba model berikutnya
      terakhirGagal = `Model ${model} tidak merespons.`;
      console.error(
        `gagal menghubungi ${model}:`,
        e instanceof Error ? e.message : e,
      );
      continue;
    }

    if (res.status === 404 || res.status === 503) {
      terakhirGagal = `Model ${model} tidak tersedia (${res.status}).`;
      continue;
    }

    if (res.status === 429) {
      return balasError(
        "KUOTA_HABIS",
        429,
        "Batas kuota harian AI tercapai atau server AI sedang padat.",
      );
    }

    if (!res.ok) {
      // Isi balasan Google hanya masuk log server, TIDAK diteruskan ke HP —
      // pesan errornya kadang memuat potongan konfigurasi milik project.
      console.error(
        `gemini ${model} status ${res.status}:`,
        await res.text(),
      );
      return balasError(
        "AI_BERMASALAH",
        502,
        `Gagal menghubungi AI (${res.status}).`,
      );
    }

    // ---- 4. Bongkar jawaban -------------------------------------------
    try {
      const data = await res.json();
      const teks = data?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (typeof teks !== "string" || teks.trim() === "") {
        return balasError("AI_KOSONG", 502, "Tidak ada jawaban dari AI.");
      }

      const hasil = JSON.parse(bersihkanPagarMarkdown(teks));
      if (typeof hasil !== "object" || hasil === null || Array.isArray(hasil)) {
        return balasError("FORMAT_SALAH", 502, "Format data AI tidak sesuai.");
      }

      return new Response(JSON.stringify(hasil), {
        status: 200,
        headers: {
          ...HEADER_CORS,
          "Content-Type": "application/json",
          // Nama model yang akhirnya dipakai, berguna saat menelusuri masalah.
          "x-model-dipakai": model,
        },
      });
    } catch (e) {
      console.error(
        "gagal membaca jawaban gemini:",
        e instanceof Error ? e.message : e,
      );
      return balasError("FORMAT_SALAH", 502, "Jawaban AI tidak bisa dibaca.");
    }
  }

  // Seluruh model gagal
  return balasError("AI_TIDAK_TERSEDIA", 502, terakhirGagal);
});
