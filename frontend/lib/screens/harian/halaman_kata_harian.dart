import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/panduan_nuansa.dart';
import '../../core/penanda_perubahan.dart';
import '../../core/tema.dart';
import '../../models/sinonim.dart';
import '../../services/layanan_auth.dart';
import '../../services/layanan_kamus.dart';
import '../../services/layanan_kata_harian.dart';
import '../../services/layanan_kosakata.dart';
import '../../services/layanan_notifikasi.dart';
import '../../widgets/kartu_penjelasan_ai.dart';
import '../../widgets/lembar_detail_kata.dart';
import '../../widgets/pemilih_kategori.dart';
import '../../widgets/tombol_audio.dart';

/// Use Case 4 — Melihat Kata Harian & Streak Belajar.
/// Tampilan Opsi C: Nordic Calm Sage dengan Flashcard Reveal & Tips Penggunaan.
class HalamanKataHarian extends StatefulWidget {
  const HalamanKataHarian({super.key});

  @override
  State<HalamanKataHarian> createState() => _HalamanKataHarianState();
}

class _HalamanKataHarianState extends State<HalamanKataHarian> {
  KataHarian? _kata;
  List<Sinonim> _cuplikanSinonim = [];
  bool _sedangMuat = true;
  bool _sedangSimpan = false;
  bool _sudahDisimpan = false;
  bool _terbuka = false;
  String? _pesanError;

  @override
  void initState() {
    super.initState();
    _muat();
    // Minta izin notifikasi secara halus; jika ditolak, berjalan aman tanpa error
    LayananNotifikasi.instance.mintaIzin();
  }

  String _kunciRevealHariIni(DateTime dt) =>
      'kata_harian_reveal_${dt.year}_${dt.month}_${dt.day}';

  Future<void> _muat() async {
    setState(() {
      _sedangMuat = true;
      _pesanError = null;
    });

    try {
      final hasil = await LayananKataHarian.instance.ambilHariIni();
      if (!mounted) return;

      // Cek status reveal hari ini di penyimpanan lokal
      final prefs = await SharedPreferences.getInstance();
      final sudahTerbuka =
          prefs.getBool(_kunciRevealHariIni(hasil.tanggal)) ?? false;

      // Ambil 3 sinonim cepat untuk cuplikan
      List<Sinonim> sinonim = [];
      try {
        sinonim = await LayananKamus.instance.cariSinonim(hasil.kata, maksimal: 3);
      } catch (_) {}

      // Cek apakah sudah tersimpan
      bool tersimpan = false;
      try {
        final daftarTersimpan = await LayananKosakata.instance.ambilDaftarKata();
        tersimpan = daftarTersimpan.contains(hasil.kata.toLowerCase());
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _kata = hasil;
        _terbuka = sudahTerbuka;
        _cuplikanSinonim = sinonim;
        _sudahDisimpan = tersimpan;
      });

      // Jadwalkan pengingat harian
      LayananNotifikasi.instance.jadwalkanKataHarian(kata: hasil.kata);
    } catch (e) {
      if (!mounted) return;
      setState(() => _pesanError = LayananKosakata.pesanRamah(e));
    } finally {
      if (mounted) setState(() => _sedangMuat = false);
    }
  }

  Future<void> _bukaMakna() async {
    final kata = _kata;
    if (kata == null) return;

    setState(() => _terbuka = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kunciRevealHariIni(kata.tanggal), true);
    } catch (_) {}
  }

  Future<void> _simpanKeKosakata() async {
    final kata = _kata;
    if (kata == null) return;

    final kategori = await pilihKategori(context);
    if (kategori == null || !mounted) return;

    setState(() => _sedangSimpan = true);
    try {
      await LayananKosakata.instance.simpanKata(
        kata: kata.kata,
        definisi: kata.definisi,
        contoh: kata.contoh,
        kategori: kategori,
        sinonim: _cuplikanSinonim,
      );

      beriTahuKosakataBerubah();
      if (!mounted) return;
      setState(() => _sudahDisimpan = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${kata.kata}" tersimpan ke $kategori.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LayananKosakata.pesanRamah(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _sedangSimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sedangMuat) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5),
            SizedBox(height: 16),
            Text(
              'Menyiapkan kata hari ini...',
              style: TextStyle(color: TemaBritishly.tintaPudar, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_pesanError != null) {
      return _LayarGagal(pesan: _pesanError!, saatUlangi: _muat);
    }

    final kata = _kata!;

    return RefreshIndicator(
      onRefresh: _muat,
      color: TemaBritishly.hijau,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
        children: [
          // Header: Tanggal & Streak Pill
          _barisTanggalStreak(kata),
          const SizedBox(height: 20),

          // Hero Flashcard
          _kartuFlashcard(kata),
          const SizedBox(height: 20),

          // Tombol Simpan (aktif setelah dibuka)
          if (_terbuka) ...[
            _tombolSimpan(),
            const SizedBox(height: 20),
          ],

          // Footer info santai
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: TemaBritishly.amber,
                ),
                const SizedBox(width: 6),
                Text(
                  'Satu kata baru tiap hari',
                  style: TextStyle(
                    fontSize: 12,
                    color: TemaBritishly.tintaPudar.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _barisTanggalStreak(KataHarian kata) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_namaHari(kata.tanggal), style: TemaBritishly.labelBagian),
              const SizedBox(height: 3),
              Text(
                _tanggalPanjang(kata.tanggal),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: TemaBritishly.tinta,
                ),
              ),
            ],
          ),
        ),
        // Streak Badge Nordic Sand
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: kata.streak > 0
                ? TemaBritishly.amberSamar
                : TemaBritishly.putih,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: kata.streak > 0
                  ? TemaBritishly.amber.withValues(alpha: 0.4)
                  : TemaBritishly.kremGaris,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 20,
                color: kata.streak > 0
                    ? TemaBritishly.apiStreak
                    : TemaBritishly.tintaPudar.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 5),
              Text(
                '${kata.streak}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: kata.streak > 0
                      ? TemaBritishly.tinta
                      : TemaBritishly.tintaPudar,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'hari',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: kata.streak > 0
                      ? TemaBritishly.tintaPudar
                      : TemaBritishly.tintaPudar.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kartuFlashcard(KataHarian kata) {
    return Card(
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 320),
        crossFadeState:
            _terbuka ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        // ================================================================
        // COVER: Ditampilkan sebelum di-reveal pada hari ini
        // ================================================================
        firstChild: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: TemaBritishly.hijauSamar,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'KATA HARI INI',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: TemaBritishly.hijau,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TombolAudio(
                    teks: kata.kata,
                    ukuran: 36,
                    warnaLatar: TemaBritishly.hijauSamar,
                    warnaIkon: TemaBritishly.hijau,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                kata.kata,
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  height: 1.1,
                  color: TemaBritishly.tinta,
                ),
              ),

              if (kata.fonetik.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: TemaBritishly.kremIsi,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    kata.fonetik,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: TemaBritishly.tintaPudar,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              // Area petunjuk Flashcard
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TemaBritishly.kremIsi.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: TemaBritishly.kremGaris,
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 20,
                      color: TemaBritishly.amber,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tebak arti kata ini dalam hati, lalu buka untuk melihat definisi dan tips penggunaannya.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: TemaBritishly.tintaPudar,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tombol Reveal
              FilledButton.icon(
                onPressed: _bukaMakna,
                icon: const Icon(Icons.visibility_rounded, size: 18),
                label: const Text('Buka Makna & Detail Kata'),
              ),
            ],
          ),
        ),

        // ================================================================
        // REVEALED: Konten lengkap setelah dibuka
        // ================================================================
        secondChild: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Baris atas kartu
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: TemaBritishly.hijauSamar,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'KATA HARI INI',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: TemaBritishly.hijau,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TombolAudio(
                    teks: kata.kata,
                    ukuran: 36,
                    warnaLatar: TemaBritishly.hijauSamar,
                    warnaIkon: TemaBritishly.hijau,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Kata Utama
              Text(
                kata.kata,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  height: 1.1,
                  color: TemaBritishly.tinta,
                ),
              ),

              if (kata.fonetik.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: TemaBritishly.kremIsi,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    kata.fonetik,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: TemaBritishly.tintaPudar,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              Container(
                width: 32,
                height: 2.5,
                decoration: BoxDecoration(
                  color: TemaBritishly.hijau,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),

              // Definisi
              if (kata.definisi.isNotEmpty)
                Text(
                  kata.definisi,
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.6,
                    color: TemaBritishly.tinta,
                  ),
                )
              else
                const Text(
                  'Definisi belum bisa diambil. Tarik ke bawah untuk memuat ulang.',
                  style:
                      TextStyle(color: TemaBritishly.tintaPudar, fontSize: 14),
                ),

              // Penjelasan Pintar AI (Bilingual & On-Demand)
              const SizedBox(height: 16),
              KartuPenjelasanAi(kata: kata.kata),

              // -------------------------------------------------------------
              // FITUR: Contoh Penggunaan
              // -------------------------------------------------------------
              if (kata.contoh.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: TemaBritishly.kremIsi,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: TemaBritishly.kremGaris.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.format_quote_rounded,
                            size: 16,
                            color: TemaBritishly.hijau,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'CONTOH PENGGUNAAN',
                            style: TemaBritishly.labelBagian.copyWith(
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '"${kata.contoh}"',
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          height: 1.55,
                          fontSize: 14.5,
                          color: TemaBritishly.tinta,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // -------------------------------------------------------------
              // FITUR 3: Cuplikan Sinonim Terkait
              // -------------------------------------------------------------
              if (_cuplikanSinonim.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'CUPLIKAN SINONIM CEPAT',
                  style: TemaBritishly.labelBagian.copyWith(fontSize: 10.5),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _cuplikanSinonim.map((s) {
                    final nuansa = PanduanNuansa.nuansaSinonim(
                      s.teks,
                      definisiAsli: s.definisi,
                    );
                    return Tooltip(
                      message: '$nuansa (Ketuk teks untuk arti, ikon speaker untuk audio)',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => tampilkanLembarDetailKata(context, s.teks),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
                            decoration: BoxDecoration(
                              color: TemaBritishly.kremIsi,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: TemaBritishly.kremGaris),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  s.teks,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: TemaBritishly.tinta,
                                    decoration: TextDecoration.underline,
                                    decorationStyle: TextDecorationStyle.dotted,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                TombolAudio(
                                  teks: s.teks,
                                  ukuran: 22,
                                  warnaLatar: Colors.transparent,
                                  warnaIkon: TemaBritishly.hijau,
                                  tooltip: 'Dengar "${s.teks}"',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tombolSimpan() {
    if (_sudahDisimpan) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: TemaBritishly.hijauSamar,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TemaBritishly.hijau.withValues(alpha: 0.25)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, size: 20, color: TemaBritishly.hijau),
            SizedBox(width: 8),
            Text(
              'Tersimpan di Kosakatamu',
              style: TextStyle(
                color: TemaBritishly.hijau,
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
            ),
          ],
        ),
      );
    }

    return FilledButton.icon(
      onPressed: _sedangSimpan ? null : _simpanKeKosakata,
      icon: _sedangSimpan
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.bookmark_add_rounded, size: 20),
      label: Text(
        _sedangSimpan ? 'Menyimpan...' : 'Simpan ke Kosakata Saya',
      ),
    );
  }

  String _namaHari(DateTime dt) {
    const hari = [
      'SENIN', 'SELASA', 'RABU', 'KAMIS', 'JUMAT', 'SABTU', 'MINGGU',
    ];
    return hari[(dt.weekday - 1).clamp(0, 6)];
  }

  String _tanggalPanjang(DateTime dt) {
    const bulan = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final namaBulan = bulan[(dt.month - 1).clamp(0, 11)];
    return '${dt.day} $namaBulan ${dt.year}';
  }
}

class _LayarGagal extends StatelessWidget {
  const _LayarGagal({required this.pesan, required this.saatUlangi});

  final String pesan;
  final VoidCallback saatUlangi;

  @override
  Widget build(BuildContext context) {
    final warna = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: warna.errorContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_rounded, size: 40, color: warna.error),
            ),
            const SizedBox(height: 18),
            const Text(
              'Belum bisa memuat kata hari ini',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: TemaBritishly.tinta,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              pesan,
              textAlign: TextAlign.center,
              style: const TextStyle(color: TemaBritishly.tintaPudar, fontSize: 13.5),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: saatUlangi,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
            ),
            if (pesan.toLowerCase().contains('sesi') ||
                pesan.toLowerCase().contains('masuk kembali')) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => LayananAuth.instance.keluar(),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Keluar & Masuk Ulang'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
