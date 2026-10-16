import 'package:flutter/material.dart';

import '../core/penanda_perubahan.dart';
import '../core/tema.dart';
import '../models/hasil_kamus.dart';
import '../services/layanan_kamus.dart';
import '../services/layanan_kosakata.dart';
import 'label_level.dart';
import 'pemilih_kategori.dart';
import 'tombol_audio.dart';

/// Membuka lembar pop-up cepat untuk melihat definisi lengkap kata/sinonim.
Future<void> tampilkanLembarDetailKata(
  BuildContext context,
  String kata, {
  VoidCallback? saatBukaDiCari,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _IsiLembarDetailKata(
      kata: kata,
      saatBukaDiCari: saatBukaDiCari,
    ),
  );
}

class _IsiLembarDetailKata extends StatefulWidget {
  const _IsiLembarDetailKata({
    required this.kata,
    this.saatBukaDiCari,
  });

  final String kata;
  final VoidCallback? saatBukaDiCari;

  @override
  State<_IsiLembarDetailKata> createState() => _IsiLembarDetailKataState();
}

class _IsiLembarDetailKataState extends State<_IsiLembarDetailKata> {
  HasilKamus? _hasil;
  bool _sedangMuat = true;
  String? _pesanError;
  bool _sudahTersimpan = false;
  bool _sedangSimpan = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _sedangMuat = true;
      _pesanError = null;
    });

    try {
      final daftarKata = await LayananKosakata.instance.ambilDaftarKata();
      if (mounted) {
        setState(() {
          _sudahTersimpan = daftarKata.contains(widget.kata.toLowerCase().trim());
        });
      }

      final hasil = await LayananKamus.instance.cariDefinisi(widget.kata);
      if (!mounted) return;
      setState(() {
        _hasil = hasil;
        _sedangMuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sedangMuat = false;
        _pesanError = LayananKamus.pesanRamah(e);
      });
    }
  }

  Future<void> _simpan() async {
    final hasil = _hasil;
    if (hasil == null) return;

    final kategori = await pilihKategori(context);
    if (kategori == null || !mounted) return;

    setState(() => _sedangSimpan = true);
    try {
      await LayananKosakata.instance.simpanKata(
        kata: hasil.kata,
        definisi: hasil.definisiUtama,
        contoh: hasil.contohUtama,
        kategori: kategori,
        sinonim: const [],
      );

      beriTahuKosakataBerubah();
      if (!mounted) return;
      setState(() => _sudahTersimpan = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${hasil.kata}" berhasil disimpan ke $kategori.')),
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
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                // Header Kata & Audio
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.kata,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.6,
                                    color: TemaBritishly.tinta,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              LabelLevel(kata: widget.kata, ukuranTeks: 12),
                            ],
                          ),
                          if (_hasil?.fonetik.isNotEmpty ?? false) ...[
                            const SizedBox(height: 2),
                            Text(
                              _hasil!.fonetik,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: TemaBritishly.tintaPudar,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    TombolAudio(
                      teks: widget.kata,
                      ukuran: 36,
                      warnaLatar: TemaBritishly.hijauSamar,
                      warnaIkon: TemaBritishly.hijau,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_sedangMuat)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: TemaBritishly.hijau,
                      ),
                    ),
                  )
                else if (_pesanError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          size: 40,
                          color: TemaBritishly.tintaPudar,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "We couldn't find the word you're looking for",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: TemaBritishly.tinta,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _pesanError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: TemaBritishly.tintaPudar,
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton(
                          onPressed: _muat,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  )
                else if (_hasil != null) ...[
                  // Definisi
                  for (final makna in _hasil!.makna) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: TemaBritishly.kremIsi,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TemaBritishly.kremGaris),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: TemaBritishly.hijauSamar,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              makna.jenisKata.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: TemaBritishly.hijau,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (var i = 0;
                              i < makna.definisi.length && i < 2;
                              i++) ...[
                            if (i > 0) const SizedBox(height: 6),
                            Text(
                              '${i + 1}. ${makna.definisi[i].teks}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                height: 1.4,
                              ),
                            ),
                            if ((makna.definisi[i].contoh ?? '').isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                '"${makna.definisi[i].contoh}"',
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  fontSize: 12.5,
                                  color: TemaBritishly.tintaPudar,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Tombol Tindakan
                  if (_sudahTersimpan)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: TemaBritishly.hijauSamar,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: TemaBritishly.hijau.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: TemaBritishly.hijau,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Sudah Tersimpan di Koleksimu',
                            style: TextStyle(
                              color: TemaBritishly.hijau,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _sedangSimpan ? null : _simpan,
                      icon: _sedangSimpan
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.bookmark_add_rounded, size: 18),
                      label: const Text('Simpan Kata Ini ke Koleksi'),
                    ),

                  if (widget.saatBukaDiCari != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.saatBukaDiCari!();
                      },
                      icon: const Icon(Icons.search_rounded, size: 17),
                      label: const Text('Buka Lengkap di Tab Eksplorasi'),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
