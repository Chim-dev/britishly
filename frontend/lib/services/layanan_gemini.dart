import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/penjelasan_ai.dart';

/// Exception ketika API key Gemini belum diisi di file .env
class GeminiKunciBelumDiaturException implements Exception {
  const GeminiKunciBelumDiaturException();
  @override
  String toString() =>
      'GEMINI_API_KEY belum dikonfigurasi di file .env aplikasi.';
}

/// Exception ketika kuota gratis per menit atau harian Gemini tercapai (HTTP 429)
class GeminiBatasKuotaException implements Exception {
  const GeminiBatasKuotaException();
  @override
  String toString() =>
      'Batas kuota harian AI tercapai atau server AI sedang padat.';
}

/// Exception ketika terjadi masalah jaringan atau timeout saat memanggil Gemini
class GeminiKoneksiException implements Exception {
  const GeminiKoneksiException(this.pesan);
  final String pesan;
  @override
  String toString() => 'Koneksi ke server AI bermasalah: $pesan';
}

/// Layanan integrasi Google Gemini API untuk penjelasan kosakata cerdas.
class LayananGemini {
  LayananGemini._();

  static final LayananGemini instance = LayananGemini._();

  /// Model aktif yang berhasil digunakan (disimpan agar panggilan berikutnya instan tanpa perlu fallback)
  String? _modelAktif;

  /// Getter model aktif saat ini
  String get modelAktif => _modelAktif ?? _daftarModel.first;

  /// Daftar model kandidat berdasarkan prioritas kecepatan dan ketersediaan di Google AI Studio
  List<String> get _daftarModel {
    final dariEnv = dotenv.env['GEMINI_MODEL']?.trim();
    if (dariEnv != null && dariEnv.isNotEmpty) {
      String normalisasi = dariEnv;
      if (dariEnv == '2.5') normalisasi = 'gemini-2.5-flash';
      if (dariEnv == '3.5') normalisasi = 'gemini-3.5-flash';
      if (dariEnv == '3.6') normalisasi = 'gemini-3.6-flash';
      if (dariEnv == '1.5') normalisasi = 'gemini-1.5-flash';

      return [
        normalisasi,
        'gemini-flash-lite-latest',
        'gemini-3.5-flash-lite',
        'gemini-flash-latest',
        'gemini-3.5-flash',
      ];
    }

    if (_modelAktif != null) {
      return [
        _modelAktif!,
        'gemini-flash-lite-latest',
        'gemini-3.5-flash-lite',
        'gemini-flash-latest',
      ];
    }

    return const [
      'gemini-flash-lite-latest',
      'gemini-3.5-flash-lite',
      'gemini-flash-latest',
      'gemini-3.5-flash',
      'gemini-3.6-flash',
      'gemini-2.5-flash',
      'gemini-1.5-flash',
    ];
  }

  /// Cache memori agar kata yang baru dicari tidak perlu memanggil API lagi
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

  /// Mengambil API key dari .env
  String? get _apiKey {
    try {
      final key = dotenv.env['GEMINI_API_KEY']?.trim();
      if (key != null && key.isNotEmpty && !key.contains('xxxx')) {
        return key;
      }
    } catch (_) {}
    return null;
  }

  /// Mengecek apakah API key sudah terpasang
  bool get adaKunci => _apiKey != null;

  /// Meminta penjelasan kosakata cerdas dari Gemini AI.
  /// Dilengkapi sistem 2-tier caching (Memori + SharedPreferences)
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

    // 3. Validasi API Key
    final key = _apiKey;
    if (key == null) {
      throw const GeminiKunciBelumDiaturException();
    }

    // 4. Prompt penjelasan interaktif bilingual
    final prompt = '''
Explain the English word "$kataBersih" clearly for an Indonesian language learner. DO NOT USE ANY EMOTICON OR EMOJI
Return JSON ONLY with the following schema:
{
  "kata": "$kataBersih",
  "arti_indonesia": "Arti utama yang paling tepat dan alami dalam Bahasa Indonesia (1-3 kata) tanpa menggunakan emoji",
  "definisi_simpel": "Definisi dalam bahasa Inggris yang mudah dipahami pembelajar (1 kalimat) tanpa menggunakan emoji",
  "nuansa": "Penjelasan singkat dalam Bahasa Indonesia tentang kapan kata ini tepat dipakai (misal: formal/santai, emosi yang dibawa, atau perbedaan dengan kata umum)",
  "contoh": [
    {
      "en": "Natural English example sentence using the word",
      "id": "Terjemahan kalimat contoh ke Bahasa Indonesia yang alami"
    },
    {
      "en": "A second practical daily example sentence",
      "id": "Terjemahan kalimat kedua ke Bahasa Indonesia"
    }
  ]
}
''';

    final bodyJson = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.2,
      }
    });

    http.Response? respons;
    String? modelBerhasil;

    try {
      // 5. Panggil model dengan toleransi fallback otomatis jika model tertentu deprecated (404), padat (503), atau timeout
      for (final model in _daftarModel) {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key',
        );

        try {
          final res = await http
              .post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: bodyJson,
              )
              .timeout(const Duration(seconds: 12));

          if (res.statusCode == 404 || res.statusCode == 503) {
            debugPrint('Gemini model $model status ${res.statusCode}, mencoba model cadangan...');
            continue;
          }

          if (res.statusCode == 429) {
            throw const GeminiBatasKuotaException();
          }

          respons = res;
          if (res.statusCode == 200) {
            modelBerhasil = model;
          }
          break;
        } on TimeoutException {
          debugPrint('Gemini model $model timeout, mencoba model cadangan...');
          continue;
        } on http.ClientException {
          continue;
        }
      }

    if (respons == null) {
      throw const GeminiKoneksiException('Model AI tidak tersedia atau koneksi terputus.');
    }

    if (respons.statusCode != 200) {
      final pesan = 'Gagal menghubungi AI (Status ${respons.statusCode})';
      debugPrint('$pesan: ${respons.body}');
      throw GeminiKoneksiException(pesan);
    }

    if (modelBerhasil != null) {
      _modelAktif = modelBerhasil;
    }

      final dataRespons = jsonDecode(utf8.decode(respons.bodyBytes));
      final candidates = dataRespons['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw const GeminiKoneksiException('Tidak ada jawaban dari AI.');
      }

      final parts = candidates.first['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw const GeminiKoneksiException('Format respons AI kosong.');
      }

      String rawText = (parts.first['text'] as String? ?? '').trim();

      // Bersihkan jika ada blok markdown ```json ... ```
      if (rawText.startsWith('```json')) {
        rawText = rawText.substring(7);
      }
      if (rawText.startsWith('```')) {
        rawText = rawText.substring(3);
      }
      if (rawText.endsWith('```')) {
        rawText = rawText.substring(0, rawText.length - 3);
      }
      rawText = rawText.trim();

      final jsonParsed = jsonDecode(rawText);
      if (jsonParsed is! Map<String, dynamic>) {
        throw const GeminiKoneksiException('Format data AI tidak sesuai.');
      }

      final hasil = PenjelasanAi.fromJson(jsonParsed);

      // Simpan ke Cache Memori & Penyimpanan HP
      _cacheMemori[kataBersih] = hasil;
      await _simpanKeHp(kataBersih, hasil);

      return hasil;
    } on TimeoutException {
      throw const GeminiKoneksiException('Koneksi ke server AI melebihi batas waktu (timeout).');
    } on http.ClientException catch (e) {
      throw GeminiKoneksiException(e.message);
    } catch (e) {
      if (e is GeminiBatasKuotaException ||
          e is GeminiKunciBelumDiaturException ||
          e is GeminiKoneksiException) {
        rethrow;
      }
      throw GeminiKoneksiException(e.toString());
    }
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
