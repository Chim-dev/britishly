import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../core/konstanta.dart';
import '../models/akronim.dart';
import '../models/hasil_kamus.dart';
import '../models/sinonim.dart';
import 'simpanan_kamus.dart';

/// Dilempar bila kata yang dicari memang tidak ada di kamus.
class KataTidakDitemukan implements Exception {
  const KataTidakDitemukan(this.kata);
  final String kata;

  @override
  String toString() => 'Kata "$kata" tidak ditemukan di kamus.';
}

/// Dilempar bila server kamus yang bermasalah, bukan katanya.
class ServerKamusSibuk implements Exception {
  const ServerKamusSibuk();
}

/// Use Case 2 — Mencari Kata & Melihat Sinonim.
///
/// Dua API luar, keduanya gratis dan tanpa API key, dan keduanya hanya
/// dibaca (operasi Read) — aplikasi tidak pernah mengubah data di sana.
///
/// Hasilnya disimpan berlapis:
///   1. memori  — selama aplikasi berjalan, paling cepat
///   2. HP      — bertahan setelah aplikasi ditutup ([SimpananKamus])
///   3. jaringan— baru menghubungi API kalau dua-duanya kosong
class LayananKamus {
  LayananKamus._();

  static final LayananKamus instance = LayananKamus._();

  static const _basisKamus = 'https://api.dictionaryapi.dev/api/v2/entries/en';
  static const _basisDatamuse = 'https://api.datamuse.com/words';

  /// Batas waktu untuk fallback kamus online.
  static const _batasWaktu = Duration(seconds: 15);
  static const _jedaUlangan = Duration(milliseconds: 400);
  static const _maksUlangan = 1;

  final Map<String, HasilKamus> _memoriDefinisi = {};
  final Map<String, List<Sinonim>> _memoriSinonim = {};

  // ------------------------------------------------------------------

  /// Mencari saran kata instan dari koleksi lokal (tanpa roundtrip jaringan).
  /// Sangat cepat untuk autocomplete instan saat pengguna mengetik.
  List<String> cariSaranLokal(String kataKunci, {int batas = 6}) {
    final bersih = kataKunci.trim().toLowerCase();
    if (bersih.isEmpty) return const [];

    final hasilSet = <String>{};

    // 1. Cek dari memori cache kata yang pernah dibuka
    for (final k in _memoriDefinisi.keys) {
      if (k.startsWith(bersih) || k.contains(bersih)) {
        hasilSet.add(k);
        if (hasilSet.length >= batas) return hasilSet.toList();
      }
    }

    // 2. Cek dari rekomendasi tema
    for (final daftar in kKataRekomendasi.values) {
      for (final k in daftar) {
        final kLower = k.toLowerCase();
        if (kLower.startsWith(bersih) || kLower.contains(bersih)) {
          hasilSet.add(kLower);
          if (hasilSet.length >= batas) return hasilSet.toList();
        }
      }
    }

    // 3. Cek dari sumber kata harian
    for (final k in kSumberKataHarian) {
      final kLower = k.toLowerCase();
      if (kLower.startsWith(bersih) || kLower.contains(bersih)) {
        hasilSet.add(kLower);
        if (hasilSet.length >= batas) return hasilSet.toList();
      }
    }

    return hasilSet.toList();
  }

  /// Definisi, pelafalan (IPA), jenis kata, dan contoh kalimat.
  ///
  /// Menggunakan arsitektur Fast-Path:
  /// 1. Cek Memori Cache
  /// 2. Cek Penyimpanan HP (offline)
  /// 3. FAST-PATH: Datamuse API (instan ~300ms)
  /// 4. Fallback ke Free Dictionary API bila Datamuse tidak menemukan definisi
  Future<HasilKamus> cariDefinisi(
    String kata, {
    void Function(String fonetik)? saatFonetikTiba,
  }) async {
    final bersih = kata.trim().toLowerCase();
    if (bersih.isEmpty) throw const KataTidakDitemukan('');

    // Lapis 1 — memori
    final diMemori = _memoriDefinisi[bersih];
    if (diMemori != null) return diMemori;

    // Lapis 2 — penyimpanan HP
    final diHp = await SimpananKamus.instance.ambilDefinisi(bersih);
    if (diHp != null) {
      final hasil = _uraikanDefinisi(diHp, bersih);
      if (hasil != null) {
        _memoriDefinisi[bersih] = hasil;
        return hasil;
      }
    }

    // Lapis 3 — FAST-PATH Datamuse (~300ms)
    final hasilDatamuse = await _cariDefinisiDatamuse(bersih);
    if (hasilDatamuse != null) {
      _memoriDefinisi[bersih] = hasilDatamuse;
      SimpananKamus.instance.simpanDefinisi(
        bersih,
        jsonEncode([hasilDatamuse.toJson()]),
      );

      // Jalankan pengayaan fonetik IPA dari Dictionary API di latar belakang
      _perkayaFonetikOnline(bersih, hasilDatamuse, saatFonetikTiba);

      return hasilDatamuse;
    }

    // Lapis 4 — Fallback ke Free Dictionary API
    return await _cariDefinisiKamusOnline(bersih);
  }

  Future<HasilKamus> _cariDefinisiKamusOnline(String bersih) async {
    final url = Uri.parse('$_basisKamus/${Uri.encodeComponent(bersih)}');
    final respons = await _ambilDenganUlangan(url);

    if (respons.statusCode == 404) throw KataTidakDitemukan(bersih);
    if (respons.statusCode >= 500) throw const ServerKamusSibuk();
    if (respons.statusCode != 200) {
      throw Exception('Kamus sedang bermasalah (kode ${respons.statusCode}).');
    }

    final mentah = utf8.decode(respons.bodyBytes);
    final hasil = _uraikanDefinisi(mentah, bersih);
    if (hasil == null) throw KataTidakDitemukan(bersih);

    _memoriDefinisi[bersih] = hasil;
    await SimpananKamus.instance.simpanDefinisi(bersih, mentah);
    return hasil;
  }

  void _perkayaFonetikOnline(
    String kata,
    HasilKamus hasilSaatIni,
    void Function(String fonetik)? callback,
  ) {
    _ambilFonetikKamusOnline(kata).then((fonetik) {
      if (fonetik != null && fonetik.isNotEmpty) {
        final hasilKaya = hasilSaatIni.salinDengan(fonetik: fonetik);
        _memoriDefinisi[kata] = hasilKaya;
        SimpananKamus.instance.simpanDefinisi(
          kata,
          jsonEncode([hasilKaya.toJson()]),
        );
        callback?.call(fonetik);
      }
    }).catchError((_) {});
  }

  Future<String?> _ambilFonetikKamusOnline(String kata) async {
    try {
      final url = Uri.parse('$_basisKamus/${Uri.encodeComponent(kata)}');
      final respons = await http.get(url).timeout(const Duration(seconds: 15));
      if (respons.statusCode != 200) return null;
      final mentah = utf8.decode(respons.bodyBytes);
      final hasil = _uraikanDefinisi(mentah, kata);
      return hasil?.fonetik;
    } catch (_) {
      return null;
    }
  }

  /// Mengambil kata acak berkualitas tinggi dari koleksi 100.000+ kata Datamuse API.
  ///
  /// Dilengkapi filter kualitas:
  /// - Panjang kata 5–9 huruf dengan awalan huruf acak (a-z)
  /// - Hanya kata berhuruf murni (tanpa tanda hubung, spasi, atau simbol)
  /// - Memiliki definisi kamus resmi WordNet
  /// - Memiliki frekuensi/skor tinggi (bukan istilah usang atau jargon teknis sempit)
  Future<HasilKamus> ambilKataAcakDinamis({
    void Function(String fonetik)? saatFonetikTiba,
  }) async {
    final rng = Random();
    // Huruf awalan acak (a–z) dan panjang bervariasi (5–9 huruf)
    final awalan = 'abcdefghijklmnopqrstuvwxyz'[rng.nextInt(26)];
    final sisaTandaTanya = 4 + rng.nextInt(5); // 4, 5, 6, 7, atau 8 tanda tanya
    final pola = '$awalan${'?' * sisaTandaTanya}';

    try {
      final url = Uri.parse(
        '$_basisDatamuse?sp=$pola&md=dpf&max=50',
      );
      final respons = await http.get(url).timeout(const Duration(seconds: 4));
      if (respons.statusCode == 200) {
        final dynamic data = jsonDecode(utf8.decode(respons.bodyBytes));
        if (data is List && data.isNotEmpty) {
          final RegExp polaHurufMurni = RegExp(r'^[a-z]+$');

          // Saring kata-kata yang valid, berdefinisi, dan memiliki bobot bagus
          final calonKata = data.where((item) {
            if (item is! Map) return false;
            final w = (item['word'] as String? ?? '').toLowerCase();
            final defs = item['defs'];
            final score = item['score'] as num? ?? 0;
            return polaHurufMurni.hasMatch(w) &&
                defs is List &&
                defs.isNotEmpty &&
                score >= 30000;
          }).toList();

          if (calonKata.isNotEmpty) {
            final terpilih = calonKata[rng.nextInt(calonKata.length)] as Map;
            final kata = (terpilih['word'] as String).toLowerCase();
            final hasil = _bangunHasilKamusDariDatamuse(kata, terpilih);
            if (hasil != null) {
              _memoriDefinisi[kata] = hasil;
              SimpananKamus.instance.simpanDefinisi(
                kata,
                jsonEncode([hasil.toJson()]),
              );
              _perkayaFonetikOnline(kata, hasil, saatFonetikTiba);
              return hasil;
            }
          }
        }
      }
    } catch (_) {
      // Jaringan bermasalah, gunakan fallback lokal
    }

    // Fallback cadangan: ambil kata kurasi lokal jika jaringan offline
    try {
      final kataFallback =
          kSumberKataHarian[rng.nextInt(kSumberKataHarian.length)];
      return await cariDefinisi(kataFallback, saatFonetikTiba: saatFonetikTiba);
    } catch (_) {
      // Jika benar-benar offline atau di lingkungan unit test tanpa internet,
      // sediakan kata kurasi siap pakai agar aplikasi tidak pernah crash
      return HasilKamus(
        kata: 'serendipity',
        fonetik: '/ˌsɛrənˈdɪpɪti/',
        makna: const [
          MaknaKata(
            jenisKata: 'noun',
            definisi: [
              Definisi(
                teks:
                    'The occurrence and development of events by chance in a happy or beneficial way.',
              ),
            ],
          ),
        ],
      );
    }
  }

  Future<HasilKamus?> _cariDefinisiDatamuse(String kata) async {
    try {
      final url = Uri.parse(
        '$_basisDatamuse?sp=${Uri.encodeQueryComponent(kata)}&md=dpf&max=1',
      );
      final respons = await http.get(url).timeout(const Duration(seconds: 4));
      if (respons.statusCode != 200) return null;

      final dynamic data = jsonDecode(utf8.decode(respons.bodyBytes));
      if (data is! List || data.isEmpty) return null;

      final entri = data.first;
      if (entri is! Map) return null;

      return _bangunHasilKamusDariDatamuse(kata, entri);
    } catch (_) {
      return null;
    }
  }

  HasilKamus? _bangunHasilKamusDariDatamuse(String kata, Map entri) {
    final defs = entri['defs'];
    if (defs is! List || defs.isEmpty) return null;

    final Map<String, List<Definisi>> grupMakna = {};

    for (final item in defs) {
      if (item is! String) continue;
      final parts = item.split('\t');
      String jenis = 'general';
      String teksDef = item.trim();

      if (parts.length >= 2) {
        jenis = _terjemahkanJenisKata(parts[0].trim());
        teksDef = parts.sublist(1).join(' ').trim();
      }

      if (teksDef.isEmpty) continue;
      final listDef = grupMakna.putIfAbsent(jenis, () => []);
      if (listDef.length < 3) {
        listDef.add(Definisi(teks: teksDef));
      }
    }

    if (grupMakna.isEmpty) return null;

    final maknaList = grupMakna.entries
        .map((e) => MaknaKata(jenisKata: e.key, definisi: e.value))
        .toList();

    return HasilKamus(
      kata: (entri['word'] as String?)?.trim() ?? kata,
      fonetik: '',
      makna: maknaList,
    );
  }

  static String _terjemahkanJenisKata(String kode) {
    switch (kode.toLowerCase()) {
      case 'n':
        return 'noun';
      case 'v':
        return 'verb';
      case 'adj':
        return 'adjective';
      case 'adv':
        return 'adverb';
      case 'u':
        return 'interjection';
      default:
        return kode;
    }
  }

  /// Kata & frasa yang maknanya mirip, dari Datamuse.
  ///
  /// Dipangkas ke maksimal 10 kata agar respons API sangat cepat (~200ms)
  /// dan tidak membebani kuota pengguna.
  Future<List<Sinonim>> cariSinonim(String kata, {int maksimal = 10}) async {
    final bersih = kata.trim().toLowerCase();
    if (bersih.isEmpty) return const [];

    final diMemori = _memoriSinonim[bersih];
    if (diMemori != null) return _salin(diMemori);

    final diHp = await SimpananKamus.instance.ambilSinonim(bersih);
    if (diHp != null) {
      final hasil = _uraikanSinonim(diHp, bersih);
      _memoriSinonim[bersih] = hasil;
      return _salin(hasil);
    }

    try {
      final url = Uri.parse(
        '$_basisDatamuse?ml=${Uri.encodeQueryComponent(bersih)}'
        '&max=$maksimal&md=d',
      );
      final respons = await http.get(url).timeout(const Duration(seconds: 5));
      if (respons.statusCode != 200) return const [];

      final mentah = utf8.decode(respons.bodyBytes);
      final hasil = _uraikanSinonim(mentah, bersih);

      _memoriSinonim[bersih] = hasil;
      await SimpananKamus.instance.simpanSinonim(bersih, mentah);
      return _salin(hasil);
    } catch (_) {
      return const [];
    }
  }

  /// Sudah tersimpan di HP? Dipakai UI untuk menandai kata yang
  /// pasti tampil instan.
  Future<bool> sudahTersimpan(String kata) async {
    final bersih = kata.trim().toLowerCase();
    if (_memoriDefinisi.containsKey(bersih)) return true;
    return await SimpananKamus.instance.ambilDefinisi(bersih) != null;
  }

  /// Mencari akronim dari koleksi kurasi, dengan pencarian lokal instan.
  List<Akronim> cariAkronim(String kataKunci) {
    final bersih = kataKunci.trim().toLowerCase();
    if (bersih.isEmpty) return List.unmodifiable(kKoleksiAkronim);

    return kKoleksiAkronim.where((a) {
      return a.singkatan.toLowerCase().contains(bersih) ||
          a.kepanjangan.toLowerCase().contains(bersih) ||
          a.arti.toLowerCase().contains(bersih) ||
          a.kategori.toLowerCase().contains(bersih);
    }).toList();
  }

  /// Mencari akronim secara daring (fallback ke Dictionary API jika tidak
  /// ada di daftar lokal).
  Future<Akronim?> cariAkronimOnline(String kata) async {
    final bersih = kata.trim().toUpperCase();
    if (bersih.isEmpty) return null;

    // Cek dulu di lokal
    for (final a in kKoleksiAkronim) {
      if (a.singkatan.toUpperCase() == bersih) return a;
    }

    // Jika tidak ada di lokal, coba ambil definisi dari Dictionary API
    try {
      final hasil = await cariDefinisi(bersih.toLowerCase());
      if (hasil.definisiUtama.isNotEmpty) {
        return Akronim(
          singkatan: bersih,
          kepanjangan: hasil.definisiUtama.split('.').first,
          arti: hasil.definisiUtama,
          kategori: 'Umum',
          contoh: hasil.contohUtama.isNotEmpty
              ? hasil.contohUtama
              : 'Commonly used acronym: $bersih',
        );
      }
    } catch (_) {
      // Tidak ditemukan di kamus online juga
    }
    return null;
  }

  // ------------------------------------------------------------------

  HasilKamus? _uraikanDefinisi(String mentah, String kata) {
    try {
      final data = jsonDecode(mentah);
      if (data is! List || data.isEmpty) return null;
      return HasilKamus.dariJson(data.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  List<Sinonim> _uraikanSinonim(String mentah, String kata) {
    try {
      final data = jsonDecode(mentah);
      if (data is! List) return const [];

      final hasil = <Sinonim>[];
      for (final item in data) {
        if (item is! Map) continue;

        final teks = (item['word'] as String?)?.trim() ?? '';
        // Datamuse kadang mengembalikan kata yang dicari itu sendiri.
        if (teks.isEmpty || teks.toLowerCase() == kata) continue;

        hasil.add(Sinonim(teks: teks, definisi: _ambilDefinisi(item['defs'])));
      }
      return hasil;
    } catch (_) {
      return const [];
    }
  }

  /// Salinan baru supaya centang pilihan tidak terbawa antar pencarian.
  List<Sinonim> _salin(List<Sinonim> asal) => asal
      .map((s) => Sinonim(teks: s.teks, definisi: s.definisi))
      .toList();

  /// Meminta ulang bila server balas 5xx atau tidak merespons.
  ///
  /// Dictionary API kadang mengembalikan 502/522 saat sedang sibuk, dan
  /// percobaan berikutnya biasanya berhasil karena jawabannya sudah
  /// masuk cache mereka.
  Future<http.Response> _ambilDenganUlangan(Uri url) async {
    Object? errorTerakhir;

    for (var percobaan = 0; percobaan <= _maksUlangan; percobaan++) {
      try {
        final respons = await http.get(url).timeout(_batasWaktu);

        if (respons.statusCode >= 500 && percobaan < _maksUlangan) {
          await Future.delayed(_jedaUlangan);
          continue;
        }
        return respons;
      } on TimeoutException catch (e) {
        errorTerakhir = e;
        if (percobaan >= _maksUlangan) break;
      } catch (e) {
        errorTerakhir = e;
        if (percobaan >= _maksUlangan) break;
        await Future.delayed(_jedaUlangan);
      }
    }

    throw errorTerakhir ?? const ServerKamusSibuk();
  }

  /// Datamuse mengirim definisi sebagai "adj\tvery pleased".
  /// Bagian sebelum tab adalah jenis kata, yang dipakai bagian sesudahnya.
  String? _ambilDefinisi(Object? defs) {
    if (defs is! List || defs.isEmpty) return null;

    final pertama = defs.first;
    if (pertama is! String || pertama.isEmpty) return null;

    final bagian = pertama.split('\t');
    return bagian.length > 1 ? bagian.last.trim() : pertama.trim();
  }

  /// Mengubah error jaringan menjadi kalimat yang dimengerti pengguna.
  static String pesanRamah(Object error) {
    if (error is KataTidakDitemukan) {
      return 'Kata "${error.kata}" tidak ada di kamus. Periksa ejaannya — '
          'kamus ini hanya memuat bahasa Inggris.';
    }
    if (error is ServerKamusSibuk || error is TimeoutException) {
      return 'Server kamus sedang lambat merespons. Sudah dicoba beberapa '
          'kali tapi belum berhasil. Coba lagi sebentar lagi.';
    }

    final teks = error.toString();
    if (teks.contains('SocketException') ||
        teks.contains('Failed host lookup') ||
        teks.contains('ClientException')) {
      return 'Tidak ada koneksi internet.';
    }
    if (teks.contains('TimeoutException')) {
      return 'Server kamus tidak merespons. Coba lagi sebentar.';
    }
    return teks.replaceFirst('Exception: ', '');
  }
}
