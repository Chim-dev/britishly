import 'package:flutter/material.dart';

import '../core/tema.dart';

/// Jenis dialog streak yang akan ditampilkan berdasarkan status streak pengguna.
enum TipeStreakDialog {
  aktif,
  terputus,
  awal,
}

/// Menampilkan dialog animasi modal perayaan atau pemulihan streak harian.
Future<void> tampilkanDialogStreak(
  BuildContext context, {
  required TipeStreakDialog tipe,
  required int streak,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => DialogAnimasiStreak(
      tipe: tipe,
      streak: streak,
    ),
  );
}

/// Widget dialog animasi streak harian.
class DialogAnimasiStreak extends StatefulWidget {
  const DialogAnimasiStreak({
    super.key,
    required this.tipe,
    required this.streak,
  });

  final TipeStreakDialog tipe;
  final int streak;

  @override
  State<DialogAnimasiStreak> createState() => _DialogAnimasiStreakState();
}

class _DialogAnimasiStreakState extends State<DialogAnimasiStreak>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _skala;
  late final Animation<double> _denyut;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Animasi masuk membal (bounce in)
    _skala = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    );

    // Animasi denyut api membara (flame pulse)
    _denyut = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
      ),
    );

    _ctrl.forward().then((_) {
      if (mounted) {
        _ctrl.repeat(reverse: true, period: const Duration(milliseconds: 900));
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAktif = widget.tipe == TipeStreakDialog.aktif;
    final bool isTerputus = widget.tipe == TipeStreakDialog.terputus;

    final Color warnaUtama = isTerputus
        ? const Color(0xFF10B981) // Emerald Green pemulihan & harapan baru
        : TemaBritishly.apiStreak; // Amber Api Streak hangat

    final Color warnaLatarIcon = isTerputus
        ? const Color(0xFFD1FAE5)
        : const Color(0xFFFFEDD5);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: TemaBritishly.putih,
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Baris header dengan tombol silang (X)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: warnaLatarIcon,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isTerputus
                            ? Icons.eco_rounded
                            : Icons.local_fire_department_rounded,
                        size: 15,
                        color: warnaUtama,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isAktif
                            ? 'STREAK AKTIF'
                            : isTerputus
                                ? 'SEMANGAT BARU'
                                : 'MULAI STREAK',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: warnaUtama,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('tombol_tutup_dialog_streak'),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: TemaBritishly.tintaPudar,
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Tutup',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Animasi visual api / tunas berdenyut
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                final skalaTotal = _skala.value * (_ctrl.value > 0.6 ? _denyut.value : 1.0);
                return Transform.scale(
                  scale: skalaTotal.clamp(0.01, 1.2),
                  child: child,
                );
              },
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      warnaUtama.withValues(alpha: 0.25),
                      warnaUtama.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                    stops: const [0.4, 0.7, 1.0],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: warnaLatarIcon,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: warnaUtama.withValues(alpha: 0.3),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      isTerputus
                          ? Icons.refresh_rounded
                          : Icons.local_fire_department_rounded,
                      size: 44,
                      color: warnaUtama,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Badge angka hari
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: TemaBritishly.kremIsi,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TemaBritishly.kremGaris),
              ),
              child: Text(
                isTerputus
                    ? 'Hari ke-1'
                    : '${widget.streak} Hari Berturut-turut',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: TemaBritishly.tinta,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Judul
            Text(
              isAktif
                  ? 'Streak Belajar Terjaga! 🔥'
                  : isTerputus
                      ? 'Streak Mengulang dari Hari ke-1 🌱'
                      : 'Langkah Pertama Dimulai! 🚀',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: TemaBritishly.tinta,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),

            // Pesan persuasif & motivasi
            Text(
              isAktif
                  ? 'Konsistensimu sungguh luar biasa! Luangkan 1 menit untuk membuka kata hari ini dan jaga api belajarmu tetap menyala.'
                  : isTerputus
                      ? 'Jangan patah semangat! Kehilangan streak bukan berarti kehilangan ilmu yang telah kamu pelajari. Perjalanan ribuan mil selalu dimulai dari satu langkah kecil. Mari nyalakan kembali apimu hari ini!'
                      : 'Selamat datang di Britishly! Buka aplikasi setiap hari untuk membangun kebiasaan belajar dan menguasai kosakata baru bahasa Inggris.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: TemaBritishly.tintaPudar,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),

            // Tombol Aksi Utama
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('tombol_aksi_dialog_streak'),
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: warnaUtama,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isAktif
                      ? 'Pelajari Kata Hari Ini ✨'
                      : isTerputus
                          ? 'Nyalakan Kembali Apiku! 🔥'
                          : 'Mulai Belajar Sekarang 🚀',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
