import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/konstanta.dart';
import 'layanan_kamus.dart';

/// Kata hari ini beserta panjang streak.
class KataHarian {
  const KataHarian({
    required this.kata,
    required this.fonetik,
    required this.definisi,
    required this.contoh,
    required this.tanggal,
    required this.streak,
  });

  final String kata;

  /// Pelafalan IPA. Tidak disimpan di database — selalu diambil ulang
  /// dari Dictionary API (yang sudah di-cache), jadi tidak menambah kolom.
  final String fonetik;

  final String definisi;
  final String contoh;
  final DateTime tanggal;
  final int streak;
}

/// Use Case 4 — Melihat Kata Harian.
///
/// Pembagian tugasnya:
///   - Aplikasi memilih kata (berdasarkan tanggal) dan mengambil definisinya
///   - Database menjaga agar satu hari tetap satu kata, dan menghitung streak
class LayananKataHarian {
  LayananKataHarian._();

  static final LayananKataHarian instance = LayananKataHarian._();

  SupabaseClient get _klien => Supabase.instance.client;

  /// Kata kurasi deterministik dari kSumberKataHarian. Sekarang hanya
  /// cadangan bila API tidak bisa dihubungi atau penyimpanan HP gagal.
  static String kataUntukTanggal(DateTime dt) {
    final awalTahun = DateTime(dt.year, 1, 1);
    final hariKe = dt.difference(awalTahun).inDays;
    final indeks = (hariKe + (dt.year % 10) * 11) % kSumberKataHarian.length;
    return kSumberKataHarian[indeks.abs()];
  }

  static String teksTanggal(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Salinan lokal jadwal kata bersama ('yyyy-MM-dd' -> kata).
  ///
  /// Notifikasi lokal harus sudah tahu teksnya saat dijadwalkan, padahal
  /// kata acak dari API baru diketahui setelah diambil. Karena itu kata untuk
  /// beberapa hari ke depan ditetapkan di muka oleh Edge Function
  /// `jadwal-kata` di tabel `daily_word_schedule` (satu kata per tanggal
  /// untuk semua user), lalu disalin ke sini supaya tetap terbaca saat
  /// offline. Layar Kata Harian dan
  /// notifikasi — di HP mana pun — membaca jadwal yang sama.
  ///
  /// Isinya HANYA kata yang sudah dikonfirmasi server. Kata server tidak
  /// pernah berubah, jadi salinan ini tidak bisa basi.
  static const String _kunciJadwal = 'jadwal_kata_harian_bersama';

  /// Antrean pengisian jadwal. Tanpa ini, dua panggilan bersamaan (mis.
  /// notifikasi saat aplikasi dibuka + layar Kata Harian) memanggil server
  /// dua kali untuk hal yang sama.
  Future<void> _antreanJadwal = Future.value();

  /// Memastikan hari ini sampai [jumlahHariKeDepan] hari berikutnya sudah
  /// punya kata, lalu mengembalikan jadwalnya.
  ///
  /// Tanggal yang tidak bisa dipastikan (offline / belum login) TIDAK ada di
  /// hasil. Pemanggil memakai [kataUntukTanggal] sebagai cadangan — rumusnya
  /// sama di semua HP, jadi dua HP yang sama-sama offline tetap kompak.
  Future<Map<String, String>> siapkanJadwal({int jumlahHariKeDepan = 0}) {
    final hasil = _antreanJadwal.then((_) => _isiJadwal(jumlahHariKeDepan));
    _antreanJadwal = hasil.then((_) {}, onError: (_) {});
    return hasil;
  }

  Future<Map<String, String>> _isiJadwal(int jumlahHariKeDepan) async {
    final hariIni = DateTime.now();
    final semuaTanggal = [
      for (var i = 0; i <= jumlahHariKeDepan; i++)
        teksTanggal(DateTime(hariIni.year, hariIni.month, hariIni.day + i)),
    ];
    final dari = semuaTanggal.first;
    final sampai = semuaTanggal.last;

    // 1. Salinan lokal
    SharedPreferences? prefs;
    final jadwal = <String, String>{};
    try {
      prefs = await SharedPreferences.getInstance();
      final mentah = prefs.getString(_kunciJadwal);
      if (mentah != null) {
        jadwal.addAll(Map<String, String>.from(jsonDecode(mentah) as Map));
      }
    } catch (_) {}
    // Tanggal yang sudah lewat tidak diperlukan lagi
    jadwal.removeWhere((tgl, _) => tgl.compareTo(dari) < 0);

    if (semuaTanggal.every(jadwal.containsKey)) return jadwal;

    // 2. Jadwal bersama dari server. Kata untuk tanggal yang masih kosong
    //    dipilih oleh Edge Function jadwal-kata, bukan oleh HP. Bisa gagal
    //    kalau offline, belum login, atau Supabase belum diinisialisasi
    //    (main() menjadwalkan notifikasi sebelum Supabase.initialize) —
    //    cukup pakai yang ada.
    try {
      if (_klien.auth.currentUser == null) return jadwal;

      final respons = await _klien.functions.invoke(
        'jadwal-kata',
        body: {'dari': dari, 'sampai': sampai},
        abortSignal: Future.delayed(const Duration(seconds: 30)),
      );
      final data = respons.data;
      if (data is Map && data['jadwal'] is Map) {
        (data['jadwal'] as Map).forEach((tgl, kata) {
          jadwal[tgl.toString()] = kata.toString();
        });
      }

      try {
        await prefs?.setString(_kunciJadwal, jsonEncode(jadwal));
      } catch (_) {}
    } catch (_) {}

    return jadwal;
  }

  Future<KataHarian> ambilHariIni() async {
    final hariIni = DateTime.now();
    final hariIniTeks = teksTanggal(hariIni);

    Map<String, dynamic> baris = {};
    int streak = 0;

    // 1. Cek apakah di database Supabase user sudah punya kata untuk hari ini
    try {
      final user = _klien.auth.currentUser;
      if (user != null) {
        final resp = await _klien
            .from('daily_words')
            .select()
            .eq('shown_date', hariIniTeks)
            .maybeSingle();
        if (resp != null) {
          baris = Map<String, dynamic>.from(resp);
        }
      }
    } catch (_) {}

    String kataTampil;
    String definisiTampil;
    String contohTampil;
    String fonetikTampil = '';

    if (baris.isNotEmpty && baris['word'] != null) {
      // Sudah ada kata untuk hari ini -> pakai kata yang tersimpan (konsisten seharian)
      kataTampil = (baris['word'] as String).trim();
      definisiTampil = (baris['definition'] as String?)?.trim() ?? '';
      contohTampil = (baris['example'] as String?)?.trim() ?? '';

      // Lengkapi fonetik / pelafalan IPA jika belum ada
      try {
        final def = await LayananKamus.instance.cariDefinisi(kataTampil);
        fonetikTampil = def.fonetik;
        if (definisiTampil.isEmpty) definisiTampil = def.definisiUtama;
        if (contohTampil.isEmpty) contohTampil = def.contohUtama;
      } catch (_) {}
    } else {
      // 2. Hari baru -> pakai kata acak dari API yang sudah dijadwalkan,
      //    yaitu kata yang sama dengan yang tercantum di notifikasi hari ini
      try {
        final jadwal = await siapkanJadwal();
        kataTampil = jadwal[hariIniTeks] ?? kataUntukTanggal(hariIni);
      } catch (_) {
        kataTampil = kataUntukTanggal(hariIni);
      }

      try {
        final def = await LayananKamus.instance.cariDefinisi(kataTampil);
        definisiTampil = def.definisiUtama;
        contohTampil = def.contohUtama;
        fonetikTampil = def.fonetik;
      } catch (_) {
        definisiTampil = '';
        contohTampil = '';
        fonetikTampil = '';
      }

      // Simpan kata unik hari ini ke database Supabase
      try {
        baris = await _panggilSetDailyWord(
          kataTampil,
          definisiTampil,
          contohTampil,
          tanggalTeks: hariIniTeks,
        );
      } catch (e) {
        final teks = e.toString().toLowerCase();
        if (teks.contains('jwt') ||
            teks.contains('pgrst301') ||
            teks.contains('28000')) {
          try {
            await _klien.auth.refreshSession();
            baris = await _panggilSetDailyWord(
              kataTampil,
              definisiTampil,
              contohTampil,
              tanggalTeks: hariIniTeks,
            );
          } catch (_) {}
        }
      }
    }

    // Ambil perhitungan streak berdasarkan waktu lokal HP
    try {
      streak = await ambilStreak(tanggalTeks: hariIniTeks);
    } catch (_) {}

    return KataHarian(
      kata: baris['word'] as String? ?? kataTampil,
      fonetik: fonetikTampil,
      definisi: baris['definition'] as String? ?? definisiTampil,
      contoh: baris['example'] as String? ?? contohTampil,
      tanggal:
          DateTime.tryParse(baris['shown_date'] as String? ?? '') ?? hariIni,
      streak: streak,
    );
  }

  Future<Map<String, dynamic>> _panggilSetDailyWord(
    String kata,
    String definisi,
    String contoh, {
    String? tanggalTeks,
  }) async {
    dynamic hasil;
    try {
      final params = <String, dynamic>{
        'p_word': kata,
        'p_definition': definisi.isEmpty ? null : definisi,
        'p_example': contoh.isEmpty ? null : contoh,
      };
      if (tanggalTeks != null) {
        params['p_date'] = tanggalTeks;
      }
      hasil = await _klien.rpc('set_daily_word', params: params);
    } catch (e) {
      // Fallback ini HANYA untuk database yang function-nya masih versi lama
      // (belum punya parameter p_date).
      //
      // Dulu semua error ikut ditangkap di sini. Akibatnya gangguan jaringan
      // sesaat membuat permintaan diulang tanpa p_date, sehingga tanggalnya
      // jatuh ke tanggal server (UTC). Untuk pengguna WIB (UTC+7) antara
      // pukul 00.00–07.00, barisnya tercatat sebagai kemarin dan streak-nya
      // justru putus. Jadi error selain "function tidak ada" dilempar lagi.
      if (tanggalTeks == null || !_karenaFunctionVersiLama(e)) rethrow;

      hasil = await _klien.rpc(
        'set_daily_word',
        params: {
          'p_word': kata,
          'p_definition': definisi.isEmpty ? null : definisi,
          'p_example': contoh.isEmpty ? null : contoh,
        },
      );
    }

    // PostgREST bisa mengembalikan objek tunggal atau daftar berisi satu
    // objek, tergantung versi. Ditangani dua-duanya.
    if (hasil is List) {
      return hasil.isEmpty ? {} : Map<String, dynamic>.from(hasil.first as Map);
    }
    if (hasil is Map) return Map<String, dynamic>.from(hasil);
    return {};
  }

  /// Benar hanya bila errornya "function dengan parameter itu tidak ada" —
  /// yaitu database masih memakai skrip sebelum 06_sync_local_time.sql.
  /// PostgREST memakai kode PGRST202 untuk kasus ini.
  static bool _karenaFunctionVersiLama(Object error) {
    if (error is! PostgrestException) return false;
    if (error.code == 'PGRST202' || error.code == '42883') return true;

    final pesan = error.message.toLowerCase();
    return pesan.contains('could not find the function') ||
        pesan.contains('does not exist');
  }

  Future<int> ambilStreak({String? tanggalTeks}) async {
    final tgl = tanggalTeks ?? () {
      final now = DateTime.now();
      return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }();

    try {
      final hasil = await _klien.rpc('get_streak', params: {'p_today': tgl});
      return hasil is num ? hasil.toInt() : 0;
    } catch (e) {
      // Sama seperti _panggilSetDailyWord: hanya database versi lama yang
      // boleh dihitung ulang tanpa p_today. Kalau errornya jaringan, streak
      // hasil hitungan UTC bisa lebih kecil dari yang sebenarnya.
      if (!_karenaFunctionVersiLama(e)) return 0;

      try {
        final hasil = await _klien.rpc('get_streak');
        return hasil is num ? hasil.toInt() : 0;
      } catch (_) {
        return 0;
      }
    }
  }
}

