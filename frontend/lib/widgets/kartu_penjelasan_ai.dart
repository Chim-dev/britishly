import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../models/penjelasan_ai.dart';
import '../services/layanan_gemini.dart';

enum StatusPenjelasanAi { awal, memuat, sukses, gagal }

/// Widget interaktif untuk memuat penjelasan cerdas dari Gemini AI secara on-demand.
/// Dirancang responsif dan fleksibel agar aman di semua ukuran layar ponsel.
class KartuPenjelasanAi extends StatefulWidget {
  const KartuPenjelasanAi({
    super.key,
    required this.kata,
  });

  final String kata;

  @override
  State<KartuPenjelasanAi> createState() => _KartuPenjelasanAiState();
}

class _KartuPenjelasanAiState extends State<KartuPenjelasanAi> {
  StatusPenjelasanAi _status = StatusPenjelasanAi.awal;
  PenjelasanAi? _hasil;

  @override
  void didUpdateWidget(covariant KartuPenjelasanAi oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kata.toLowerCase() != widget.kata.toLowerCase()) {
      setState(() {
        _status = StatusPenjelasanAi.awal;
        _hasil = null;
      });
    }
  }

  Future<void> _muatPenjelasan() async {
    setState(() {
      _status = StatusPenjelasanAi.memuat;
    });

    try {
      final res = await LayananGemini.instance.ambilPenjelasan(widget.kata);
      if (!mounted) return;
      setState(() {
        _hasil = res;
        _status = StatusPenjelasanAi.sukses;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = StatusPenjelasanAi.gagal;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case StatusPenjelasanAi.awal:
        return _wadahAwal();
      case StatusPenjelasanAi.memuat:
        return _wadahMemuat();
      case StatusPenjelasanAi.sukses:
        return _wadahSukses(_hasil!);
      case StatusPenjelasanAi.gagal:
        return _wadahGagal();
    }
  }

  /// 1. Tampilan Awal: Tombol / Kartu Persuasif Interaktif
  Widget _wadahAwal() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: TemaBritishly.hijauSamar.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: TemaBritishly.hijau.withValues(alpha: 0.25),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _muatPenjelasan,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: TemaBritishly.hijau.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: TemaBritishly.hijau,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Want to understand deeper? ✨',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: TemaBritishly.hijau,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'AI will help you understand this word',
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 12,
                          color: TemaBritishly.tinta,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: TemaBritishly.hijau,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 2. Tampilan Memuat: Spinner Halus
  Widget _wadahMemuat() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: TemaBritishly.hijauSamar.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: TemaBritishly.hijau.withValues(alpha: 0.2),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: TemaBritishly.hijau,
            ),
          ),
          SizedBox(width: 12),
          Flexible(
            child: Text(
              'Menghubungkan ke Gemini AI...',
              softWrap: true,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: TemaBritishly.hijau,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Tampilan Sukses: Penjelasan Pintar AI Responsif
  Widget _wadahSukses(PenjelasanAi ai) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TemaBritishly.hijauSamar.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: TemaBritishly.hijau.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: TemaBritishly.hijau,
                size: 17,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'PENJELASAN PINTAR AI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: TemaBritishly.hijau,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() => _status = StatusPenjelasanAi.awal),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'Tutup',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: TemaBritishly.tintaPudar,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Arti Bahasa Indonesia (Badge Highlight)
          if (ai.artiIndonesia.isNotEmpty) ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                const Text(
                  '🇮🇩 Arti:',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: TemaBritishly.tinta,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: TemaBritishly.hijau,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ai.artiIndonesia,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Definisi Simpel Bahasa Inggris
          if (ai.definisiSimpel.isNotEmpty) ...[
            Text(
              ai.definisiSimpel,
              softWrap: true,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: TemaBritishly.tinta,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Nuansa / Kapan Digunakan (Dinamis dari AI)
          if (ai.nuansa.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ai.nuansa,
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: TemaBritishly.tinta,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Contoh Kalimat Dwibahasa
          if (ai.contoh.isNotEmpty) ...[
            const Text(
              'Contoh Penggunaan:',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: TemaBritishly.tintaPudar,
              ),
            ),
            const SizedBox(height: 6),
            for (final c in ai.contoh) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• "${c.kalimatInggris}"',
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: TemaBritishly.tinta,
                      ),
                    ),
                    if (c.terjemahanIndonesia.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 10, top: 1),
                        child: Text(
                          c.terjemahanIndonesia,
                          softWrap: true,
                          style: const TextStyle(
                            fontSize: 12,
                            color: TemaBritishly.tintaPudar,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// 4. Tampilan Gagal / Kuota Habis (Graceful Fallback)
  Widget _wadahGagal() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: TemaBritishly.kremIsi,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: TemaBritishly.kremGaris,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: TemaBritishly.merah,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'AI explanation is currently unavailable',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: TemaBritishly.merah,
              ),
            ),
          ),
          TextButton(
            onPressed: _muatPenjelasan,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: TemaBritishly.hijau,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            child: const Text(
              'Try Again',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            icon: const Icon(
              Icons.close_rounded,
              size: 16,
              color: TemaBritishly.tintaPudar,
            ),
            tooltip: 'Tutup',
            onPressed: () => setState(() => _status = StatusPenjelasanAi.awal),
          ),
        ],
      ),
    );
  }
}
