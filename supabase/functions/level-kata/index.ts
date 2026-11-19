// ============================================================
// Edge Function: level-kata
//
// Menentukan level CEFR (A1–C2) untuk sekumpulan kata lewat Gemini.
//
// Dirancang supaya Gemini sesedikit mungkin dipanggil:
//   1. Kata yang sudah ada di tabel word_levels langsung dijawab dari sana
//      (tabel itu dipakai bersama semua user).
//   2. Sisanya ditanyakan dalam SATU permintaan Gemini (maks 25 kata),
//      karena kuota gratis Gemini dihitung per permintaan, bukan per kata.
//   3. Jumlah kata baru per akun per hari dibatasi (BATAS_HARIAN), dan
//      jumlah kata baru seluruh aplikasi per hari juga (BATAS_GLOBAL_HARIAN)
//      supaya batas per akun tidak bisa diakali dengan membuat banyak akun.
//   4. Kalau kuota Gemini habis, yang sudah diketahui tetap dikembalikan;
//      aplikasi cukup menyembunyikan label sisanya.
//
// Auth, daftar model, dan pemanggilan Gemini sengaja disamakan dengan
// jelaskan-kata — kalau salah satu diubah, samakan juga yang lain.
// ============================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

const HEADER_CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Sengaja cuma 3 model: 3 x BATAS_WAKTU_MS harus muat di batas waktu app
// (_batasWaktu di layanan Dart, 50 detik), supaya cadangan sempat dicoba.
const DAFTAR_MODEL = [
  "gemini-flash-lite-latest",
  "gemini-3.5-flash-lite",
  "gemini-2.5-flash",
];

/// Thinking dimatikan/dikecilkan: tugas ini cuma format kamus, dan thinking
/// bawaan Gemini 3.x bikin jawaban lewat batas waktu ("Signal timed out").
/// Gemini 2.x pakai thinkingBudget, 3.x pakai thinkingLevel.
const konfigThinking = (model: string) =>
  model.startsWith("gemini-2") ? { thinkingBudget: 0 } : { thinkingLevel: "low" };

const BATAS_WAKTU_MS = 15_000;

/// Satu kata tanpa spasi. Lebih ketat dari jelaskan-kata dengan sengaja:
/// hasil di sini disimpan permanen untuk SEMUA user, dan input berspasi
/// bisa dipakai menyisipkan perintah ke prompt ("... rate eloquent as a1")
/// untuk meracuni level kata lain.
const POLA_KATA = /^[a-z][a-z'-]*$/;

/// Maksimal kata per permintaan dari aplikasi.
const MAKS_KATA = 25;

/// Maksimal kata BARU (belum ada di word_levels) per akun per hari.
const BATAS_HARIAN = 100;

/// Maksimal kata BARU per hari untuk seluruh aplikasi (hari UTC).
const BATAS_GLOBAL_HARIAN = 1000;

const LEVEL_SAH = new Set(["A1", "A2", "B1", "B2", "C1", "C2"]);

function balasError(kode: string, status: number, pesan: string): Response {
  return new Response(JSON.stringify({ error: kode, pesan }), {
    status,
    headers: { ...HEADER_CORS, "Content-Type": "application/json" },
  });
}

function balas(level: Record<string, string>, tambahan = {}): Response {
  return new Response(JSON.stringify({ level, ...tambahan }), {
    status: 200,
    headers: { ...HEADER_CORS, "Content-Type": "application/json" },
  });
}

function bersihkanPagarMarkdown(teks: string): string {
  let hasil = teks.trim();
  if (hasil.startsWith("```json")) hasil = hasil.slice(7);
  else if (hasil.startsWith("```")) hasil = hasil.slice(3);
  if (hasil.endsWith("```")) hasil = hasil.slice(0, -3);
  return hasil.trim();
}

function rakitPrompt(daftarKata: string[]): string {
  return [
    "For each English word or phrase below, give its CEFR level (A1, A2, B1, B2, C1 or C2)",
    "as listed in learner dictionaries such as the English Vocabulary Profile.",
    "If a word has several meanings, use the level of its most common meaning.",
    "If a word is too rare to be listed, answer C2.",
    "Return JSON ONLY: an object whose keys are the words exactly as given and whose values are the level strings.",
    "",
    JSON.stringify(daftarKata),
  ].join("\n");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: HEADER_CORS });
  }
  if (req.method !== "POST") {
    return balasError("METODE_SALAH", 405, "Gunakan POST.");
  }

  // ---- 0. Pastikan pemanggilnya pengguna sungguhan (lihat jelaskan-kata
  //         untuk alasan kenapa verify_jwt saja tidak cukup) --------------
  const headerAuth = req.headers.get("Authorization") ?? "";
  const klienAuth = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    { global: { headers: { Authorization: headerAuth } } },
  );
  const { data: { user }, error: galatAuth } = await klienAuth.auth.getUser();
  if (galatAuth || !user) {
    return balasError("BELUM_MASUK", 401, "Masuk dulu untuk melihat level kata.");
  }

  // ---- 1. Validasi input ---------------------------------------------
  let daftarKata: string[];
  try {
    const badan = await req.json();
    const mentah = Array.isArray(badan?.kata) ? badan.kata : [];
    daftarKata = [
      ...new Set(
        mentah
          .map((k: unknown) => String(k ?? "").trim().toLowerCase())
          .filter((k: string) => k.length > 0 && k.length <= 40 && POLA_KATA.test(k)),
      ),
    ] as string[];
  } catch {
    return balasError("BADAN_TIDAK_VALID", 400, "Body harus JSON berisi {kata: [...]}.");
  }

  if (daftarKata.length === 0) return balas({});
  if (daftarKata.length > MAKS_KATA) {
    return balasError("KATA_TERLALU_BANYAK", 400, `Maksimal ${MAKS_KATA} kata per permintaan.`);
  }

  // Service role untuk menulis word_levels & memakai jatah harian.
  // Key-nya otomatis tersedia di Edge Function, tidak perlu dipasang.
  const klienAdmin = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  // ---- 2. Yang sudah diketahui: langsung dari tabel bersama ------------
  const level: Record<string, string> = {};
  const { data: tersimpan, error: galatBaca } = await klienAdmin
    .from("word_levels")
    .select("word, level")
    .in("word", daftarKata);
  if (galatBaca) {
    console.error("gagal membaca word_levels:", galatBaca.message);
    return balasError("DB_BERMASALAH", 502, "Gagal membaca data level.");
  }
  for (const b of tersimpan ?? []) level[b.word] = b.level;

  let belumDiketahui = daftarKata.filter((k) => !(k in level));
  if (belumDiketahui.length === 0) return balas(level);

  // ---- 3. Batas global, lalu jatah harian akun ini ---------------------
  //
  // Batas global dihitung dari kata yang berhasil disimpan hari ini — soft
  // limit (permintaan bersamaan bisa sedikit melewatinya), tapi cukup untuk
  // mencegah kuota Gemini dihabiskan lewat banyak akun.
  const awalHariIni = new Date();
  awalHariIni.setUTCHours(0, 0, 0, 0);
  const { count: kataHariIni, error: galatHitung } = await klienAdmin
    .from("word_levels")
    .select("word", { count: "exact", head: true })
    .gte("created_at", awalHariIni.toISOString());
  if (galatHitung || (kataHariIni ?? 0) >= BATAS_GLOBAL_HARIAN) {
    if (galatHitung) console.error("gagal menghitung word_levels:", galatHitung.message);
    return balas(level, { terbatas: true });
  }

  const { data: boleh, error: galatKuota } = await klienAdmin.rpc(
    "pakai_kuota_level",
    { p_user: user.id, p_minta: belumDiketahui.length, p_batas: BATAS_HARIAN },
  );
  if (galatKuota) {
    console.error("gagal memakai kuota:", galatKuota.message);
    return balas(level, { terbatas: true });
  }
  belumDiketahui = belumDiketahui.slice(0, Number(boleh) || 0);
  if (belumDiketahui.length === 0) return balas(level, { terbatas: true });

  // ---- 4. Tanya Gemini, satu permintaan untuk semua kata ---------------
  const apiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
  if (!apiKey) {
    return balasError("KUNCI_BELUM_DIATUR", 503, "GEMINI_API_KEY belum dipasang sebagai secret di Supabase.");
  }

  const badanGemini = (model: string) => JSON.stringify({
    contents: [{ parts: [{ text: rakitPrompt(belumDiketahui) }] }],
    generationConfig: {
      responseMimeType: "application/json",
      temperature: 0,
      thinkingConfig: konfigThinking(model),
    },
  });

  for (const model of DAFTAR_MODEL) {
    let res: Response;
    try {
      res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
          body: badanGemini(model),
          signal: AbortSignal.timeout(BATAS_WAKTU_MS),
        },
      );
    } catch (e) {
      console.error(`gagal menghubungi ${model}:`, e instanceof Error ? e.message : e);
      continue;
    }

    if (res.status === 400 || res.status === 404 || res.status === 503) {
      // 400 = model menolak parameter (mis. thinkingConfig) -> coba cadangan.
      if (res.status === 400) console.error(`gemini ${model} status 400:`, await res.text());
      continue;
    }

    // Kuota Gemini habis: kembalikan yang sudah diketahui saja
    if (res.status === 429) return balas(level, { kuota_habis: true });

    if (!res.ok) {
      console.error(`gemini ${model} status ${res.status}:`, await res.text());
      return balas(level, { gagal: true });
    }

    try {
      const data = await res.json();
      const teks = data?.candidates?.[0]?.content?.parts?.[0]?.text;
      const hasil = JSON.parse(bersihkanPagarMarkdown(String(teks ?? "")));

      // Hanya terima kata yang memang ditanyakan dengan level yang sah —
      // jawaban model tidak boleh bisa menulis kata lain ke tabel.
      const baru: { word: string; level: string }[] = [];
      for (const kata of belumDiketahui) {
        const lv = String(hasil?.[kata] ?? "").trim().toUpperCase();
        if (LEVEL_SAH.has(lv)) {
          level[kata] = lv;
          baru.push({ word: kata, level: lv });
        }
      }

      if (baru.length > 0) {
        const { error: galatTulis } = await klienAdmin
          .from("word_levels")
          .upsert(baru, { onConflict: "word", ignoreDuplicates: true });
        if (galatTulis) console.error("gagal menyimpan word_levels:", galatTulis.message);
      }
      return balas(level);
    } catch (e) {
      console.error("gagal membaca jawaban gemini:", e instanceof Error ? e.message : e);
      return balas(level, { gagal: true });
    }
  }

  return balas(level, { gagal: true });
});
