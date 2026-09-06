import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/kata_tersimpan.dart';
import '../models/sinonim.dart';

/// Use Case 3 — Mengelola Daftar Kosakata.
///
/// Semua operasi CRUD ke Supabase dikumpulkan di sini:
///   CREATE : [simpanKata]      -> transaction function
///   READ   : [ambilSemua]
///   UPDATE : [ubahStatus], [ubahFavorit], [ubahDetail], [gantiSinonim]
///   DELETE : [hapus]
///
/// Tidak ada satu pun yang mengirim `user_id` — database mengambilnya
/// sendiri dari sesi login, dan RLS memastikan user hanya menyentuh
/// datanya sendiri.
class LayananKosakata {
  LayananKosakata._();

  static final LayananKosakata instance = LayananKosakata._();

  SupabaseClient get _klien => Supabase.instance.client;

  // ------------------------------------------------------------------
  // CREATE
  // ------------------------------------------------------------------

  /// Menyimpan kata utama beserta sinonim terpilih sebagai satu kesatuan.
  ///
  /// Memakai function `save_word_with_synonyms` supaya bersifat atomic:
  /// kalau ada satu sinonim yang gagal, kata utamanya ikut batal tersimpan
  /// dan tidak meninggalkan data setengah jadi.
  Future<String> simpanKata({
    required String kata,
    String? definisi,
    String? contoh,
    required String kategori,
    required List<Sinonim> sinonim,
  }) async {
    final id = await _klien.rpc(
      'save_word_with_synonyms',
      params: {
        'p_word': kata,
        'p_definition': definisi,
        'p_example': contoh,
        'p_category': kategori,
        'p_synonyms': sinonim.map((s) => s.keJson()).toList(),
      },
    );
    return id as String;
  }

  // ------------------------------------------------------------------
  // READ
  // ------------------------------------------------------------------

  /// Mengambil daftar kosakata milik user, dengan penyaringan opsional.
  ///
  /// `word_synonyms(*)` membuat sinonim ikut terambil dalam satu
  /// permintaan, jadi tidak perlu query terpisah per kata.
  Future<List<KataTersimpan>> ambilSemua({
    String? kategori,
    bool hanyaFavorit = false,
    StatusHafalan? status,
    String? cari,
  }) async {
    var kueri = _klien.from('saved_words').select('*, word_synonyms(*)');

    if (kategori != null && kategori.isNotEmpty) {
      kueri = kueri.eq('category', kategori);
    }
    if (hanyaFavorit) {
      kueri = kueri.eq('is_favorite', true);
    }
    if (status != null) {
      kueri = kueri.eq('status_hafalan', status.nilaiDb);
    }
    if (cari != null && cari.trim().isNotEmpty) {
      kueri = kueri.ilike('word', '%${cari.trim()}%');
    }

    final data = await kueri.order('created_at', ascending: false);
    return data.map(KataTersimpan.dariBaris).toList();
  }

  static const _kunciKategoriKustom = 'kategori_kustom_pengguna';

  /// Mengambil seluruh kategori unik (dari kata tersimpan di Supabase & SharedPreferences lokal).
  Future<List<String>> ambilDaftarKategori() async {
    final hasil = <String>{};

    // 1. Ambil kategori kustom yang pernah disimpan di SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final lokal = prefs.getStringList(_kunciKategoriKustom) ?? [];
      for (final k in lokal) {
        final bersih = k.trim();
        if (bersih.isNotEmpty) hasil.add(bersih);
      }
    } catch (_) {}

    // 2. Ambil kategori unik yang ada di tabel saved_words Supabase
    try {
      final data = await _klien.from('saved_words').select('category');
      for (final baris in data) {
        final kat = (baris['category'] as String?)?.trim();
        if (kat != null && kat.isNotEmpty) {
          hasil.add(kat);
        }
      }
    } catch (_) {}

    return hasil.toList();
  }

  /// Menyimpan nama kategori kustom baru ke SharedPreferences agar langsung muncul di pilihan selanjutnya.
  Future<void> simpanKategoriKustom(String kategori) async {
    final bersih = kategori.trim();
    if (bersih.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lokal = prefs.getStringList(_kunciKategoriKustom) ?? [];
      if (!lokal.contains(bersih)) {
        lokal.add(bersih);
        await prefs.setStringList(_kunciKategoriKustom, lokal);
      }
    } catch (_) {}
  }

  /// Dipakai halaman pencarian untuk menandai kata yang sudah tersimpan.
  Future<Set<String>> ambilDaftarKata() async {
    final data = await _klien.from('saved_words').select('word');
    return data
        .map((baris) => (baris['word'] as String? ?? '').toLowerCase())
        .toSet();
  }

  // ------------------------------------------------------------------
  // UPDATE
  // ------------------------------------------------------------------

  Future<void> ubahStatus(String id, StatusHafalan status) async {
    await _klien
        .from('saved_words')
        .update({'status_hafalan': status.nilaiDb}).eq('id', id);
  }

  Future<void> ubahFavorit(String id, bool favorit) async {
    await _klien
        .from('saved_words')
        .update({'is_favorite': favorit}).eq('id', id);
  }

  Future<void> ubahDetail(
    String id, {
    required String definisi,
    required String contoh,
    required String kategori,
  }) async {
    await _klien.from('saved_words').update({
      'definition': definisi,
      'example': contoh,
      'category': kategori,
    }).eq('id', id);
  }

  /// Mengganti seluruh sinonim sebuah kata dalam satu transaksi.
  /// Mengembalikan jumlah sinonim yang tersimpan.
  Future<int> gantiSinonim(String idKata, List<Sinonim> sinonim) async {
    final jumlah = await _klien.rpc(
      'replace_synonyms',
      params: {
        'p_saved_word_id': idKata,
        'p_synonyms': sinonim.map((s) => s.keJson()).toList(),
      },
    );
    return (jumlah as num).toInt();
  }

  // ------------------------------------------------------------------
  // DELETE
  // ------------------------------------------------------------------

  /// Menghapus kata. Sinonimnya ikut terhapus otomatis oleh
  /// `ON DELETE CASCADE` di database — tidak perlu dihapus manual.
  Future<void> hapus(String id) async {
    await _klien.from('saved_words').delete().eq('id', id);
  }

  /// Menghapus banyak kata sekaligus (batch delete).
  Future<void> hapusBanyak(List<String> ids) async {
    if (ids.isEmpty) return;
    await _klien.from('saved_words').delete().inFilter('id', ids);
  }

  // ------------------------------------------------------------------

  static String pesanRamah(Object error) {
    if (error is PostgrestException) {
      final pesan = error.message;
      final pesanLower = pesan.toLowerCase();

      if (pesanLower.contains('jwt') ||
          pesanLower.contains('token') ||
          pesanLower.contains('expired') ||
          error.code == 'PGRST301' ||
          error.code == '28000') {
        return 'Sesi masuk telah berakhir. Silakan masuk kembali.';
      }
      if (pesan.contains('sudah ada di daftar')) return pesan;
      if (error.code == '23505') return 'Kata ini sudah ada di daftarmu.';
      if (error.code == '42501' || pesanLower.contains('row-level security')) {
        return 'Kamu tidak memiliki izin untuk mengakses data ini.';
      }
      return pesan;
    }

    if (error is AuthException) {
      final pesan = error.message.toLowerCase();
      if (pesan.contains('jwt') ||
          pesan.contains('expired') ||
          pesan.contains('session')) {
        return 'Sesi masuk telah berakhir. Silakan masuk kembali.';
      }
      return error.message;
    }

    final teks = error.toString().toLowerCase();
    if (teks.contains('socketexception') ||
        teks.contains('failed host lookup') ||
        teks.contains('clientexception') ||
        teks.contains('timeoutexception') ||
        teks.contains('network is unreachable')) {
      return 'Tidak dapat terhubung ke internet. Periksa koneksi kamu dan coba lagi.';
    }

    if (teks.contains('jwt') ||
        teks.contains('pgrst301') ||
        teks.contains('28000')) {
      return 'Sesi masuk telah berakhir. Silakan masuk kembali.';
    }

    return error.toString().replaceFirst('Exception: ', '');
  }
}
