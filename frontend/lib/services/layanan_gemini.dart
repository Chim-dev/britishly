import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/penjelasan_ai.dart';

/// Nama Edge Function di Supabase. Kodenya ada di
/// `supabase/functions/jelaskan-kata/index.ts`
const _namaFungsi = 'jelaskan-kata';

/// Exception ketika GEMINI_API_KEY belum dipasang sebagai secret di Supabase.
///
/// Ini urusan pemilik aplikasi, bukan pengguna — dan tidak lagi bisa dicek
/// dari sisi HP, karena key-nya memang tidak pernah sampai ke sini.
class GeminiKunciBelumDiaturException implements Exception {
  const GeminiKunciBelumDiaturException();
  @override
  String toString() =>
      'GEMINI_API_KEY belum dipasang sebagai secret di Supabase.';
}

/// Exception ketika kuota gratis per menit atau harian Gemini tercapai (HTTP 429)
class GeminiBatasKuotaException implements Exception {
  const GeminiBatasKuotaException();
  @override
  String toString() =>
      'Batas kuota harian AI tercapai atau server AI sedang padat.';
}

/// Exception ketika jatah harian penjelasan AI milik pengguna ini habis.
///
/// Berbeda dengan [GeminiBatasKuotaException] (kuota Gemini seluruh aplikasi):
/// ini batas per akun dari Edge Function, dan baru pulih besok.
class GeminiJatahHabisException implements Exception {
  const GeminiJatahHabisException(this.pesan);
  final String pesan;
  @override
  String toString() => pesan;
}

/// Exception ketika pengguna belum masuk.
///
/// Edge Function memverifikasi JWT, jadi penjelasan AI hanya tersedia untuk
/// akun yang sudah login. Ini yang mencegah endpoint-nya dipakai orang lain
/// sebagai layanan AI gratis atas tagihan pemilik aplikasi.
class GeminiBelumMasukException implements Exception {
  const GeminiBelumMasukException();
  @override
  String toString() => 'Masuk dulu untuk memakai penjelasan AI.';
}

/// Exception ketika terjadi masalah jaringan atau timeout.
class GeminiKoneksiException implements Exception {
  const GeminiKoneksiException(this.pesan);
  final String pesan;
  @override
  String toString() => 'Koneksi ke server AI bermasalah: $pesan';
}

/// Layanan penjelasan kosakata cerdas.
///
/// CATATAN PENTING SOAL KEAMANAN
/// Layanan ini TIDAK lagi memanggil Google Gemini secara langsung, dan tidak
/// lagi memegang API key apa pun. Dulu key-nya dibaca dari `.env`, dan karena
/// `.env` didaftarkan sebagai asset Flutter di pubspec.yaml, key itu ikut
/// terbungkus apa adanya ke dalam APK — siapa pun yang meng-unzip APK bisa
/// mengambilnya lalu memakai kuota billing Google milik pemilik aplikasi.
///
/// Sekarang panggilannya lewat Edge Function `jelaskan-kata` di Supabase.
/// Key-nya hidup sebagai secret di server dan tidak pernah dikirim ke HP.
///
/// Yang tidak berubah: cache 2 tingkat di bawah ini. Justru makin berguna:
/// kata yang sudah ada di HP tidak pernah sampai ke server, jadi tidak
/// memakan jatah harian (5/hari) maupun kuota Gemini. Di server masih ada
/// lapis ketiga — cache bersama 7 hari di tabel ai_explanations.
class LayananGemini {
  LayananGemini._();

  static final LayananGemini instance = LayananGemini._();

  SupabaseClient get _klien => Supabase.instance.client;

  /// Cache memori agar kata yang baru dicari tidak perlu memanggil server lagi
  final Map<String, PenjelasanAi> _cacheMemori = {};

  /// Awalan key dan batas jumlah entri di penyimpanan HP.
  ///
  /// Sama seperti [SimpananKamus], simpanan AI dibatasi jumlahnya. Sebelumnya
  /// tidak ada indeks maupun batas, jadi setiap kata yang pernah dijelaskan
  /// meninggalkan satu key permanen di SharedPreferences yang tidak pernah
  /// terhapus lagi.
  static const _awalanCache = 'cache_ai_';
  static const _kunciIndeksCache = 'cache_ai_indeks';
  static const _maksEntriCache = 200;

  /// Batas waktu menunggu Edge Function. Dibuat lebih longgar daripada batas
  /// per-model di server (12 detik), supaya server sempat mencoba model
  /// cadangan sebelum aplikasi menyerah lebih dulu.
  static const _batasWaktu = Duration(seconds: 30);

  /// Meminta penjelasan kosakata cerdas.
  /// Dilengkapi sistem 2-tier caching (Memori + SharedPreferences).
  Future<PenjelasanAi> ambilPenjelasan(String kata) async {
    final kataBersih = kata.trim().toLowerCase();
    if (kataBersih.isEmpty) {
      throw Exception('Kata yang dicari tidak boleh kosong.');
    }

    // 1. Cek Cache Memori (Tingkat 1 - Kecepatan 0ms)
    final diMemori = _cacheMemori[kataBersih];
    if (diMemori != null) return diMemori;

    // 2. Cek Cache Penyimpanan HP (Tingkat 2 - Kecepatan <10ms)
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTersimpan = prefs.getString(_awalanCache + kataBersih);
      if (cacheTersimpan != null && cacheTersimpan.isNotEmpty) {
        final data = jsonDecode(cacheTersimpan);
        if (data is Map<String, dynamic>) {
          final hasil = PenjelasanAi.fromJson(data);
          _cacheMemori[kataBersih] = hasil;
          return hasil;
        }
      }
    } catch (_) {}

    // 3. Belum masuk berarti tidak ada JWT untuk dikirim. Dicegat di sini
    //    supaya tidak perlu bolak-balik ke server hanya untuk ditolak 401.
    //
    //    Aksesnya dibungkus try/catch karena `Supabase.instance` melempar
    //    AssertionError — sebuah Error, BUKAN Exception — bila Supabase belum
    //    sempat diinisialisasi (misalnya .env bermasalah, jadi main.dart
    //    berhenti di layar konfigurasi). Error yang lolos dari sini akan
    //    menembus penanganan `on ... catch` mana pun di pemanggil.
    final User? pengguna;
    try {
      pengguna = _klien.auth.currentUser;
    } catch (_) {
      throw const GeminiKoneksiException(
        'Aplikasi belum siap terhubung ke server.',
      );
    }
    if (pengguna == null) {
      throw const GeminiBelumMasukException();
    }

    // 4. Panggil Edge Function. JWT pengguna ikut otomatis, tidak perlu
    //    dipasang manual — itu yang diverifikasi server sebelum memproses.
    final Map<String, dynamic> jsonHasil;
    try {
      final respons = await _klien.functions.invoke(
        _namaFungsi,
        body: {'kata': kataBersih},
        abortSignal: Future.delayed(_batasWaktu),
      );

      final data = respons.data;
      if (data is! Map) {
        throw const GeminiKoneksiException('Format data AI tidak sesuai.');
      }
      jsonHasil = Map<String, dynamic>.from(data);
    } on FunctionException catch (e) {
      throw _terjemahkanError(e);
    } on RequestAbortedException {
      throw const GeminiKoneksiException(
        'Koneksi ke server AI melebihi batas waktu (timeout).',
      );
    }

    final hasil = PenjelasanAi.fromJson(jsonHasil);

    // Simpan ke Cache Memori & Penyimpanan HP
    _cacheMemori[kataBersih] = hasil;
    await _simpanKeHp(kataBersih, hasil);

    return hasil;
  }

  /// Memetakan kegagalan Edge Function ke exception yang sudah dikenal UI.
  ///
  /// Kode error-nya dibaca dari field `error` pada badan balasan (lihat
  /// `balasError` di index.ts), bukan dari mencocokkan potongan teks — supaya
  /// tidak gampang patah kalau redaksi pesannya sewaktu-waktu diubah.
  Exception _terjemahkanError(FunctionException e) {
    final detail = e.details;
    final kode = (detail is Map ? detail['error'] : null)?.toString();
    final pesan = (detail is Map ? detail['pesan'] : null)?.toString();

    debugPrint('Edge Function $_namaFungsi gagal (status ${e.status}, kode $kode)');

    if (e is FunctionsFetchException) {
      return const GeminiKoneksiException('Tidak ada koneksi internet.');
    }

    switch (kode) {
      case 'BELUM_MASUK':
        return const GeminiBelumMasukException();
      case 'KUOTA_HABIS':
        return const GeminiBatasKuotaException();
      case 'JATAH_HABIS':
        return GeminiJatahHabisException(
          pesan ?? 'Jatah penjelasan AI hari ini sudah habis. Coba lagi besok.',
        );
      case 'KUNCI_BELUM_DIATUR':
        return const GeminiKunciBelumDiaturException();
      case 'KATA_TIDAK_VALID':
        return GeminiKoneksiException(
          pesan ?? 'Kata itu tidak bisa dijelaskan AI.',
        );
    }

    // Belum/tidak lagi terautentikasi — JWT ditolak sebelum fungsi berjalan,
    // jadi badannya belum tentu berbentuk JSON milik kita.
    if (e.status == 401 || e.status == 403) {
      return const GeminiBelumMasukException();
    }
    if (e.status == 429) {
      return const GeminiBatasKuotaException();
    }

    return GeminiKoneksiException(
      pesan ?? 'Gagal menghubungi AI (status ${e.status}).',
    );
  }

  /// Menyimpan hasil ke penyimpanan HP sambil menjaga jumlah entrinya.
  /// Yang paling lama dipakai dibuang lebih dulu.
  Future<void> _simpanKeHp(String kata, PenjelasanAi hasil) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_awalanCache + kata, jsonEncode(hasil.toJson()));

      final indeks = prefs.getStringList(_kunciIndeksCache) ?? [];
      indeks.remove(kata);
      indeks.add(kata);

      while (indeks.length > _maksEntriCache) {
        await prefs.remove(_awalanCache + indeks.removeAt(0));
      }
      await prefs.setStringList(_kunciIndeksCache, indeks);
    } catch (_) {
      // Simpanan bermasalah bukan alasan menggagalkan penjelasan yang sudah
      // berhasil diambil.
    }
  }

  /// Membersihkan cache memori saja.
  void bersihkanCache() {
    _cacheMemori.clear();
  }

  /// Membersihkan cache memori sekaligus simpanan di HP.
  Future<void> bersihkanSimpanan() async {
    _cacheMemori.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final kata in prefs.getStringList(_kunciIndeksCache) ?? <String>[]) {
        await prefs.remove(_awalanCache + kata);
      }
      await prefs.remove(_kunciIndeksCache);
    } catch (_) {}
  }
}
