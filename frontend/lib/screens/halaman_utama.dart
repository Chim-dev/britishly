import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../services/layanan_auth.dart';
import '../services/layanan_notifikasi.dart';
import '../widgets/dialog_hapus_akun.dart';
import 'harian/halaman_kata_harian.dart';
import 'kosakata/halaman_kosakata.dart';
import 'pencarian/halaman_cari.dart';

/// Kerangka utama aplikasi: Modern British Minimalist Shell.
class HalamanUtama extends StatefulWidget {
  const HalamanUtama({super.key});

  @override
  State<HalamanUtama> createState() => _HalamanUtamaState();
}

class _HalamanUtamaState extends State<HalamanUtama> {
  int _indeks = 0;

  @override
  void initState() {
    super.initState();
    LayananNotifikasi.instance.padaNotifikasiDiklik.addListener(_tanganiNotifikasi);
  }

  @override
  void dispose() {
    LayananNotifikasi.instance.padaNotifikasiDiklik.removeListener(_tanganiNotifikasi);
    super.dispose();
  }

  void _tanganiNotifikasi() {
    final payload = LayananNotifikasi.instance.padaNotifikasiDiklik.value;
    if (payload != null && mounted) {
      setState(() => _indeks = 0); // Tab Kata Hari Ini
      LayananNotifikasi.instance.padaNotifikasiDiklik.value = null;
    }
  }

  final List<Widget> _halaman = const [
    HalamanKataHarian(),
    HalamanCari(),
    HalamanKosakata(),
  ];

  Future<void> _tampilkanMenuAkun(BuildContext context, String email) async {
    final skema = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      // Tanpa ini tinggi lembar dibatasi 9/16 layar, dan saat HP dimiringkan
      // isinya terpotong.
      isScrollControlled: true,
      builder: (ctx) {
        final lanskap =
            MediaQuery.orientationOf(ctx) == Orientation.landscape;

        final tombolKeluar = SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final konfirmasi = await showDialog<bool>(
                context: context,
                builder: (dCtx) => AlertDialog(
                  title: const Text('Keluar dari Britishly?'),
                  content: const Text(
                    'Kamu perlu masuk kembali untuk membuka kamus dan akronim pribadimu.',
                  ),
                  actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  actions: [
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(dCtx, false),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Batal',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(dCtx, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: skema.error,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Keluar',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              if (konfirmasi == true) {
                await LayananAuth.instance.keluar();
              }
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Keluar dari Akun'),
            style: OutlinedButton.styleFrom(
              foregroundColor: TemaBritishly.tinta,
              side: const BorderSide(color: TemaBritishly.kremGaris),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );

        final tombolHapus = SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('tombol_buka_dialog_hapus_akun'),
            onPressed: () {
              Navigator.pop(ctx);
              tampilkanDialogHapusAkun(context);
            },
            icon: Icon(Icons.delete_forever_rounded, size: 18, color: skema.error),
            label: Text(
              'Hapus Akun',
              style: TextStyle(color: skema.error, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: skema.error,
              side: BorderSide(color: skema.error.withValues(alpha: 0.35)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: skema.primaryContainer,
                      child: Text(
                        email.isNotEmpty ? email[0].toUpperCase() : 'B',
                        style: TextStyle(
                          color: skema.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Akun Pembelajar',
                            style: TextStyle(
                              fontSize: 13,
                              color: TemaBritishly.tintaPudar,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: TemaBritishly.tinta,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (lanskap) ...[
                  // Tinggi layar sempit: kedua tombol dijajarkan.
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: tombolKeluar),
                      const SizedBox(width: 12),
                      Expanded(child: tombolHapus),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  tombolKeluar,
                  const SizedBox(height: 10),
                  tombolHapus,
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Saat HP diputar, IndexedStack pindah dari Column ke Row. Kunci global
  /// membuatnya dipindahkan utuh, jadi hasil pencarian, kartu yang sudah
  /// dibuka, dan posisi scroll tiap tab tidak ter-reset.
  final _kunciHalaman = GlobalKey();

  Widget get _isiHalaman =>
      IndexedStack(key: _kunciHalaman, index: _indeks, children: _halaman);

  /// Tata letak landscape: tinggi layar HP tinggal ~360dp, jadi top bar dan
  /// navigasi bawah diganti satu rail di kiri supaya konten dapat tinggi penuh.
  Widget _kerangkaLanskap(String email, ColorScheme skema) {
    return Scaffold(
      backgroundColor: TemaBritishly.krem,
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: _indeks,
              onDestinationSelected: (i) => setState(() => _indeks = i),
              scrollable: true,
              trailingAtBottom: true,
              leading: Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(top: 4, bottom: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: TemaBritishly.hijauSamar,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'B',
                  style: TextStyle(
                    color: TemaBritishly.hijau,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              trailing: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Tooltip(
                  message: email,
                  child: InkWell(
                    onTap: () => _tampilkanMenuAkun(context, email),
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: skema.primary,
                        child: Text(
                          email.isNotEmpty ? email[0].toUpperCase() : 'B',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.wb_sunny_outlined),
                  selectedIcon: Icon(Icons.wb_sunny_rounded),
                  label: Text('Hari Ini'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.search_rounded),
                  selectedIcon: Icon(Icons.manage_search_rounded),
                  label: Text('Eksplorasi'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.bookmark_border_rounded),
                  selectedIcon: Icon(Icons.bookmark_rounded),
                  label: Text('Koleksi'),
                ),
              ],
            ),
            const VerticalDivider(
              width: 0.8,
              thickness: 0.8,
              color: TemaBritishly.kremGaris,
            ),
            Expanded(child: _isiHalaman),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = LayananAuth.instance.penggunaSaatIni?.email ?? '';
    final skema = Theme.of(context).colorScheme;

    if (MediaQuery.orientationOf(context) == Orientation.landscape) {
      return _kerangkaLanskap(email, skema);
    }

    return Scaffold(
      backgroundColor: TemaBritishly.krem,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar yang minimalis & rapi
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
              decoration: const BoxDecoration(
                color: TemaBritishly.krem,
                border: Border(
                  bottom: BorderSide(color: TemaBritishly.kremGaris, width: 0.8),
                ),
              ),
              child: Row(
                children: [
                  // Branding Wordmark minimalis
                  const Text(
                    'Britishly',
                    style: TextStyle(
                      color: TemaBritishly.hijau,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const Spacer(),
                  // Avatar Chip pengguna
                  InkWell(
                    onTap: () => _tampilkanMenuAkun(context, email),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: TemaBritishly.putih,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: TemaBritishly.kremGaris),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 11,
                            backgroundColor: skema.primary,
                            child: Text(
                              email.isNotEmpty ? email[0].toUpperCase() : 'B',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 130),
                            child: Text(
                              email.split('@').first,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: TemaBritishly.tinta,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: TemaBritishly.tintaPudar,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Konten halaman dengan IndexedStack
            Expanded(child: _isiHalaman),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: TemaBritishly.putih,
          border: Border(
            top: BorderSide(color: TemaBritishly.kremGaris, width: 0.8),
          ),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _indeks,
            onDestinationSelected: (i) => setState(() => _indeks = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.wb_sunny_outlined),
                selectedIcon: Icon(Icons.wb_sunny_rounded),
                label: 'Hari Ini',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_rounded),
                selectedIcon: Icon(Icons.manage_search_rounded),
                label: 'Eksplorasi',
              ),
              NavigationDestination(
                icon: Icon(Icons.bookmark_border_rounded),
                selectedIcon: Icon(Icons.bookmark_rounded),
                label: 'Koleksi',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
