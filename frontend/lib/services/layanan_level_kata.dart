import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Label level CEFR (A1–C2) per kata, ditentukan Gemini lewat Edge Function
/// `level-kata` (kodenya di `supabase/functions/level-kata/index.ts`).
///
/// Supaya kuota Gemini awet:
///   - Cache memori + HP: kata yang pernah dilihat tidak ditanyakan lagi.
///   - Permintaan dari banyak widget dikumpulkan sebentar lalu dikirim
///     sekaligus (maks 25 kata per permintaan), jadi satu layar penuh kartu
///     cukup satu panggilan.
///   - Kata yang gagal (kuota habis, jatah harian habis, offline, belum
///     login) tidak dicoba lagi sampai aplikasi dibuka ulang — labelnya
///     disembunyikan saja, tanpa pesan error.
class LayananLevelKata {
  LayananLevelKata._();

  static final LayananLevelKata instance = LayananLevelKata._();

  static const _namaFungsi = 'level-kata';
  static const _kunciCache = 'cache_level_kata';
  static const _maksEntriCache = 2000;
  static const _maksPerPermintaan = 25;
  static const _batasWaktu = Duration(seconds: 30);

  /// Jeda pengumpulan. Cukup untuk semua kartu di satu layar ikut masuk.
  static const _jedaKumpul = Duration(milliseconds: 120);

  /// Sama dengan validasi di Edge Function: satu kata, tanpa spasi.
  static final _polaKata = RegExp(r"^[a-z][a-z'-]*$");

  final Map<String, String> _cache = {};
  Future<void>? _pemuatanCache;
  final Set<String> _gagalSesiIni = {};

  /// Kata yang sedang ditunggu (di antrean maupun sedang dikirim), supaya
  /// kata yang sama tidak ditanyakan dua kali bersamaan.
  final Map<String, Completer<String?>> _permintaan = {};
  final Set<String> _antrean = {};
  Timer? _timerKirim;

  /// Level CEFR [kata], atau null kalau belum/tidak bisa diketahui.
  Future<String?> levelUntuk(String kata) async {
    final k = kata.trim().toLowerCase();
    if (k.isEmpty || k.length > 40 || !_polaKata.hasMatch(k)) return null;

    await _muatCache();
    final tersimpan = _cache[k];
    if (tersimpan != null) return tersimpan;
    if (_gagalSesiIni.contains(k)) return null;

    final berjalan = _permintaan[k];
    if (berjalan != null) return berjalan.future;

    final penanti = Completer<String?>();
    _permintaan[k] = penanti;
    _antrean.add(k);
    _timerKirim ??= Timer(_jedaKumpul, _kirimAntrean);
    return penanti.future;
  }

  Future<void> _kirimAntrean() async {
    _timerKirim = null;
    final semua = _antrean.toList();
    _antrean.clear();

    for (var i = 0; i < semua.length; i += _maksPerPermintaan) {
      final bagian =
          semua.sublist(i, min(i + _maksPerPermintaan, semua.length));

      var hasil = <String, String>{};
      try {
        hasil = await _minta(bagian);
      } catch (e) {
        debugPrint('Edge Function $_namaFungsi gagal: $e');
      }

      if (hasil.isNotEmpty) {
        _cache.addAll(hasil);
        await _simpanCache();
      }
      for (final k in bagian) {
        final level = hasil[k];
        if (level == null) _gagalSesiIni.add(k);
        _permintaan.remove(k)?.complete(level);
      }
    }
  }

  Future<Map<String, String>> _minta(List<String> daftarKata) async {
    // Supabase.instance melempar AssertionError (bukan Exception) bila belum
    // diinisialisasi — ditangkap oleh catch di _kirimAntrean.
    final klien = Supabase.instance.client;
    if (klien.auth.currentUser == null) return {};

    final respons = await klien.functions.invoke(
      _namaFungsi,
      body: {'kata': daftarKata},
      abortSignal: Future.delayed(_batasWaktu),
    );

    final data = respons.data;
    if (data is! Map || data['level'] is! Map) return {};
    return (data['level'] as Map).map(
      (k, v) => MapEntry(k.toString(), v.toString()),
    );
  }

  Future<void> _muatCache() => _pemuatanCache ??= () async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final mentah = prefs.getString(_kunciCache);
          if (mentah != null) {
            _cache.addAll(Map<String, String>.from(jsonDecode(mentah) as Map));
          }
        } catch (_) {}
      }();

  /// Menyimpan cache ke HP; entri paling lama dibuang bila melebihi batas.
  Future<void> _simpanCache() async {
    while (_cache.length > _maksEntriCache) {
      _cache.remove(_cache.keys.first);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kunciCache, jsonEncode(_cache));
    } catch (_) {}
  }
}
