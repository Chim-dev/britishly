import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../services/layanan_level_kata.dart';

/// Badge kecil level CEFR (A1–C2) untuk sebuah kata.
///
/// Tidak menampilkan apa pun selama levelnya belum diketahui atau gagal
/// diambil — kuota AI habis tidak boleh terlihat sebagai error di layar.
class LabelLevel extends StatefulWidget {
  const LabelLevel({super.key, required this.kata, this.ukuranTeks = 11});

  final String kata;
  final double ukuranTeks;

  @override
  State<LabelLevel> createState() => _LabelLevelState();
}

class _LabelLevelState extends State<LabelLevel> {
  String? _level;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void didUpdateWidget(LabelLevel lama) {
    super.didUpdateWidget(lama);
    if (lama.kata != widget.kata) {
      _level = null;
      _muat();
    }
  }

  Future<void> _muat() async {
    final kata = widget.kata;
    final level = await LayananLevelKata.instance.levelUntuk(kata);
    if (!mounted || kata != widget.kata) return;
    setState(() => _level = level);
  }

  @override
  Widget build(BuildContext context) {
    final level = _level;
    if (level == null) return const SizedBox.shrink();

    final (warna, keterangan) = switch (level[0]) {
      'A' => (TemaBritishly.statusSudah, 'Pemula'),
      'B' => (TemaBritishly.hijau, 'Menengah'),
      _ => (TemaBritishly.apiStreak, 'Mahir'),
    };

    return Tooltip(
      message: 'Level CEFR $level · $keterangan (perkiraan AI)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: warna.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          level,
          style: TextStyle(
            fontSize: widget.ukuranTeks,
            fontWeight: FontWeight.w800,
            color: warna,
          ),
        ),
      ),
    );
  }
}
