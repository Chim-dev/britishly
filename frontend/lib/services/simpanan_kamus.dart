import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Simpanan hasil API di penyimpanan HP.
///
/// Dictionary API bisa perlu 20–30 detik untuk kata yang belum pernah
/// diminta. Dengan disimpan permanen, kata yang sudah pernah dicari tetap
/// instan walau aplikasi ditutup dan dibuka lagi — dan tetap terbaca
/// meski sedang tidak ada internet.
///
/// Definisi kata tidak berubah-ubah, jadi simpanannya tidak perlu
/// kedaluwarsa. Yang dijaga hanya jumlahnya supaya tidak menumpuk.
class SimpananKamus {
  SimpananKamus._();

  static final SimpananKamus instance = SimpananKamus._();

  static const _awalanDefinisi = 'kamus_def_';
  static const _awalanSinonim = 'kamus_syn_';
  static const _kunciIndeks = 'kamus_indeks';
  static const _maksEntri = 200;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  // ------------------------------------------------------------------

  Future<String?> ambilDefinisi(String kata) => _ambil(_awalanDefinisi + kata);

  Future<String?> ambilSinonim(String kata) => _ambil(_awalanSinonim + kata);

  Future<void> simpanDefinisi(String kata, String jsonMentah) =>
      _simpan(_awalanDefinisi + kata, jsonMentah);

  Future<void> simpanSinonim(String kata, String jsonMentah) =>
      _simpan(_awalanSinonim + kata, jsonMentah);

  /// Menghapus seluruh simpanan. Dipakai kalau user ingin memaksa
  /// mengambil ulang dari server.
  Future<void> bersihkan() async {
    final prefs = await _p;
    final indeks = prefs.getStringList(_kunciIndeks) ?? [];
    for (final kunci in indeks) {
      await prefs.remove(kunci);
    }
    await prefs.remove(_kunciIndeks);
  }

  Future<int> jumlahTersimpan() async =>
      (await _p).getStringList(_kunciIndeks)?.length ?? 0;

  // ------------------------------------------------------------------

  Future<String?> _ambil(String kunci) async {
    try {
      return (await _p).getString(kunci);
    } catch (_) {
      // Penyimpanan bermasalah bukan alasan untuk menggagalkan pencarian.
      return null;
    }
  }

  Future<void> _simpan(String kunci, String isi) async {
    try {
      final prefs = await _p;
      await prefs.setString(kunci, isi);

      // Indeks dipakai untuk membatasi jumlah entri: yang paling lama
      // dipakai dibuang lebih dulu.
      final indeks = prefs.getStringList(_kunciIndeks) ?? [];
      indeks.remove(kunci);
      indeks.add(kunci);

      while (indeks.length > _maksEntri) {
        await prefs.remove(indeks.removeAt(0));
      }
      await prefs.setStringList(_kunciIndeks, indeks);
    } catch (_) {
      // sengaja diabaikan
    }
  }

  /// Pembantu kecil supaya pemanggil tidak perlu mengurus jsonEncode.
  static String keTeks(Object data) => jsonEncode(data);
}
