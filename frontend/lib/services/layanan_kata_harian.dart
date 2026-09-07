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

  /// Menghasilkan kata kurasi deterministik untuk tanggal tertentu dari daftar kSumberKataHarian.
  /// Menjamin notifikasi kata harian dan layar aplikasi selalu 100% cocok.
  static String kataUntukTanggal(DateTime dt) {
    final awalTahun = DateTime(dt.year, 1, 1);
    final hariKe = dt.difference(awalTahun).inDays;
    final indeks = (hariKe + (dt.year % 10) * 11) % kSumberKataHarian.length;
    return kSumberKataHarian[indeks.abs()];
  }

  Future<KataHarian> ambilHariIni() async {
    final hariIni = DateTime.now();
    final hariIniTeks =
        '${hariIni.year.toString().padLeft(4, '0')}-${hariIni.month.toString().padLeft(2, '0')}-${hariIni.day.toString().padLeft(2, '0')}';

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
      // 2. Hari baru -> gunakan kata kurasi deterministik yang selaras 100% dengan jadwal notifikasi
      kataTampil = kataUntukTanggal(hariIni);

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
            kataTampil, definisiTampil, contohTampil);
      } catch (e) {
        final teks = e.toString().toLowerCase();
        if (teks.contains('jwt') ||
            teks.contains('pgrst301') ||
            teks.contains('28000')) {
          try {
            await _klien.auth.refreshSession();
            baris = await _panggilSetDailyWord(
                kataTampil, definisiTampil, contohTampil);
          } catch (_) {}
        }
      }
    }

    // Ambil perhitungan streak
    try {
      streak = await ambilStreak();
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
    String contoh,
  ) async {
    final hasil = await _klien.rpc(
      'set_daily_word',
      params: {
        'p_word': kata,
        'p_definition': definisi.isEmpty ? null : definisi,
        'p_example': contoh.isEmpty ? null : contoh,
      },
    );

    // PostgREST bisa mengembalikan objek tunggal atau daftar berisi satu
    // objek, tergantung versi. Ditangani dua-duanya.
    if (hasil is List) {
      return hasil.isEmpty ? {} : Map<String, dynamic>.from(hasil.first as Map);
    }
    if (hasil is Map) return Map<String, dynamic>.from(hasil);
    return {};
  }

  Future<int> ambilStreak() async {
    final hasil = await _klien.rpc('get_streak');
    return hasil is num ? hasil.toInt() : 0;
  }
}
