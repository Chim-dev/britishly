import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Layanan pengucapan audio aksen British (en-GB) yang sangat ringan.
class LayananAudio {
  LayananAudio._();

  static final LayananAudio instance = LayananAudio._();

  FlutterTts? _tts;
  bool _diinisialisasi = false;

  /// Menyimpan teks atau kata yang SEDANG aktif diucapkan (null jika diam).
  /// Ini mencegah semua tombol audio di layar ikut beranimasi bersamaan.
  final ValueNotifier<String?> kataAktifDiputar = ValueNotifier<String?>(null);

  Future<void> _siapkan() async {
    if (_diinisialisasi) return;

    try {
      _tts = FlutterTts();
      final tts = _tts!;

      await tts.setLanguage('en-GB');
      await tts.setSpeechRate(0.46);
      await tts.setPitch(1.0);
      await tts.setVolume(1.0);

      tts.setCompletionHandler(() {
        kataAktifDiputar.value = null;
      });

      tts.setCancelHandler(() {
        kataAktifDiputar.value = null;
      });

      tts.setErrorHandler((_) {
        kataAktifDiputar.value = null;
      });

      _diinisialisasi = true;
    } catch (e) {
      debugPrint('Gagal inisialisasi TTS: $e');
      kataAktifDiputar.value = null;
    }
  }

  /// Mengucapkan satu kata atau kalimat dengan aksen British.
  Future<void> lafalkan(String teks) async {
    final bersih = teks.trim();
    if (bersih.isEmpty) return;

    try {
      await _siapkan();
      if (_tts == null) return;

      // Hentikan suara yang sedang aktif
      await _tts!.stop();

      // Tandai hanya kata ini yang aktif
      kataAktifDiputar.value = bersih;

      await _tts!.speak(bersih);
    } catch (e) {
      debugPrint('Error saat memutar audio: $e');
      kataAktifDiputar.value = null;
    }
  }

  /// Menghentikan suara yang sedang diputar.
  Future<void> hentikan() async {
    try {
      await _tts?.stop();
    } catch (_) {}
    kataAktifDiputar.value = null;
  }
}
