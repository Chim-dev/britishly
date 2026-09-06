import 'package:flutter/material.dart';
import '../services/layanan_audio.dart';

/// Tombol audio pengucapan aksen British yang minimalis dan estetis.
class TombolAudio extends StatefulWidget {
  const TombolAudio({
    super.key,
    required this.teks,
    this.ukuran = 38,
    this.warnaIkon,
    this.warnaLatar,
    this.tooltip = 'Dengarkan pengucapan British',
  });

  final String teks;
  final double ukuran;
  final Color? warnaIkon;
  final Color? warnaLatar;
  final String tooltip;

  @override
  State<TombolAudio> createState() => _TombolAudioState();
}

class _TombolAudioState extends State<TombolAudio>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _putar() async {
    _animCtrl.forward(from: 0.0);
    await LayananAudio.instance.lafalkan(widget.teks);
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final latar = widget.warnaLatar ?? skema.primary.withValues(alpha: 0.08);
    final ikon = widget.warnaIkon ?? skema.primary;
    final targetBersih = widget.teks.trim().toLowerCase();

    return ValueListenableBuilder<String?>(
      valueListenable: LayananAudio.instance.kataAktifDiputar,
      builder: (context, kataAktif, _) {
        // Hanya tombol dengan teks yang SAMA yang aktif beranimasi
        final memutar = kataAktif != null && kataAktif.toLowerCase() == targetBersih;

        return Tooltip(
          message: widget.tooltip,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _putar,
              borderRadius: BorderRadius.circular(widget.ukuran / 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: widget.ukuran,
                height: widget.ukuran,
                decoration: BoxDecoration(
                  color: memutar ? skema.primary.withValues(alpha: 0.16) : latar,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: memutar
                        ? skema.primary.withValues(alpha: 0.45)
                        : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    memutar
                        ? Icons.volume_up_rounded
                        : Icons.volume_down_rounded,
                    size: widget.ukuran * 0.52,
                    color: ikon,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
