// ============================================================
// Edge Function: jadwal-kata
//
// Mengembalikan jadwal kata harian BERSAMA (satu tanggal = satu kata untuk
// semua user) untuk rentang tanggal tertentu, dan mengisi tanggal yang
// masih kosong dengan kata acak dari Datamuse.
//
// KENAPA KATANYA DIPILIH DI SERVER
// Versi sebelumnya membiarkan HP mengusulkan kata lewat RPC
// usulkan_kata_harian, dan usulan pertama yang menang. Artinya siapa pun
// yang memanggil RPC itu langsung bisa menentukan kata harian semua user
// untuk 20 hari ke depan — termasuk kata kasar. Sekarang HP hanya bisa
// MEMINTA jadwal; isinya selalu dipilih di sini.
// ============================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

const HEADER_CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const BASIS_DATAMUSE = "https://api.datamuse.com/words";
const BATAS_WAKTU_MS = 5_000;

/// Rentang yang boleh diminta, dihitung dari tanggal server (UTC).
/// Kemarin s/d +20 hari cukup untuk zona waktu mana pun dan jadwal
/// notifikasi 14 hari.
const MUNDUR_HARI = 1;
const MAJU_HARI = 20;

/// Percobaan per tanggal kalau Datamuse mengembalikan kata kembar/kosong.
const MAKS_PERCOBAAN = 3;

const POLA_TANGGAL = /^\d{4}-\d{2}-\d{2}$/;

function balasError(kode: string, status: number, pesan: string): Response {
  return new Response(JSON.stringify({ error: kode, pesan }), {
    status,
    headers: { ...HEADER_CORS, "Content-Type": "application/json" },
  });
}

/// "YYYY-MM-DD" -> jumlah hari sejak epoch (UTC), atau null bila tidak sah.
function keHari(teks: unknown): number | null {
  if (typeof teks !== "string" || !POLA_TANGGAL.test(teks)) return null;
  const ms = Date.parse(`${teks}T00:00:00Z`);
  return Number.isNaN(ms) ? null : Math.floor(ms / 86_400_000);
}

function keTeks(hari: number): string {
  return new Date(hari * 86_400_000).toISOString().slice(0, 10);
}

/// Kata acak berkualitas dari Datamuse: 5–9 huruf, awalan huruf acak,
/// huruf murni, punya definisi, dan cukup umum (score >= 30000).
/// Sama dengan LayananKamus.ambilKataAcakDinamis di aplikasi.
async function ambilKataAcak(): Promise<string | null> {
  const awalan = "abcdefghijklmnopqrstuvwxyz"[Math.floor(Math.random() * 26)];
  const pola = awalan + "?".repeat(4 + Math.floor(Math.random() * 5));
  try {
    const res = await fetch(
      `${BASIS_DATAMUSE}?sp=${encodeURIComponent(pola)}&md=dpf&max=50`,
      { signal: AbortSignal.timeout(BATAS_WAKTU_MS) },
    );
    if (!res.ok) return null;
    const data = await res.json();
    const calon = (Array.isArray(data) ? data : [])
      .filter((i) =>
        typeof i?.word === "string" &&
        /^[a-z]+$/.test(i.word) &&
        Array.isArray(i.defs) && i.defs.length > 0 &&
        (Number(i.score) || 0) >= 30_000
      )
      .map((i) => i.word as string);
    return calon.length > 0
      ? calon[Math.floor(Math.random() * calon.length)]
      : null;
  } catch {
    return null;
  }
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
    return balasError("BELUM_MASUK", 401, "Masuk dulu untuk memuat kata harian.");
  }

  // ---- 1. Validasi rentang tanggal -----------------------------------
  let dari: number | null;
  let sampai: number | null;
  try {
    const badan = await req.json();
    dari = keHari(badan?.dari);
    sampai = keHari(badan?.sampai);
  } catch {
    return balasError("BADAN_TIDAK_VALID", 400, "Body harus JSON berisi {dari, sampai}.");
  }

  const hariIniServer = Math.floor(Date.now() / 86_400_000);
  if (
    dari === null || sampai === null || dari > sampai ||
    dari < hariIniServer - MUNDUR_HARI || sampai > hariIniServer + MAJU_HARI
  ) {
    return balasError(
      "TANGGAL_TIDAK_VALID",
      400,
      `Rentang tanggal harus di antara kemarin dan ${MAJU_HARI} hari ke depan.`,
    );
  }

  const klienAdmin = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  const bacaJadwal = async () => {
    const { data, error } = await klienAdmin
      .from("daily_word_schedule")
      .select("shown_date, word")
      .gte("shown_date", keTeks(dari!))
      .lte("shown_date", keTeks(sampai!));
    if (error) throw error;
    const jadwal: Record<string, string> = {};
    for (const b of data ?? []) jadwal[b.shown_date] = b.word;
    return jadwal;
  };

  try {
    // ---- 2. Yang sudah ada ---------------------------------------------
    const jadwal = await bacaJadwal();

    const tanggalKosong: string[] = [];
    for (let h = dari; h <= sampai; h++) {
      if (!(keTeks(h) in jadwal)) tanggalKosong.push(keTeks(h));
    }
    if (tanggalKosong.length === 0) return balasJadwal(jadwal);

    // ---- 3. Isi tanggal kosong dengan kata acak dari Datamuse ----------
    const dipakai = new Set(Object.values(jadwal));
    const kataBaru = await Promise.all(tanggalKosong.map(async () => {
      for (let i = 0; i < MAKS_PERCOBAAN; i++) {
        const kata = await ambilKataAcak();
        if (kata && !dipakai.has(kata)) {
          dipakai.add(kata);
          return kata;
        }
      }
      return null;
    }));

    const baris = tanggalKosong
      .map((tgl, i) => ({ shown_date: tgl, word: kataBaru[i] }))
      .filter((b): b is { shown_date: string; word: string } => b.word !== null);

    if (baris.length > 0) {
      // Kalau permintaan lain lebih dulu mengisi tanggal yang sama, kata
      // miliknya yang dipakai — makanya jadwal dibaca ulang sesudahnya.
      const { error } = await klienAdmin
        .from("daily_word_schedule")
        .upsert(baris, { onConflict: "shown_date", ignoreDuplicates: true });
      if (error) throw error;
    }

    return balasJadwal(await bacaJadwal());
  } catch (e) {
    console.error("gagal memproses jadwal:", e instanceof Error ? e.message : e);
    return balasError("DB_BERMASALAH", 502, "Gagal memuat jadwal kata harian.");
  }
});

function balasJadwal(jadwal: Record<string, string>): Response {
  return new Response(JSON.stringify({ jadwal }), {
    status: 200,
    headers: { ...HEADER_CORS, "Content-Type": "application/json" },
  });
}
