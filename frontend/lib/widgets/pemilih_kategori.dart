import 'package:flutter/material.dart';

import '../core/konstanta.dart';
import '../core/tema.dart';
import '../services/layanan_kosakata.dart';

/// Lembar pilihan kategori minimalis & estetis.
Future<String?> pilihKategori(
  BuildContext context, {
  String terpilih = 'Sehari-hari',
  List<String>? kategoriTambahan,
}) async {
  List<String> tambahan = kategoriTambahan ?? [];
  if (kategoriTambahan == null) {
    try {
      tambahan = await LayananKosakata.instance.ambilDaftarKategori();
    } catch (_) {}
  }
  final semua = <String>{...kKategoriBawaan, ...tambahan}.toList();

  if (!context.mounted) return null;

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _IsiPemilihKategori(
      semuaKategori: semua,
      terpilih: terpilih,
    ),
  );
}

class _IsiPemilihKategori extends StatefulWidget {
  const _IsiPemilihKategori({
    required this.semuaKategori,
    required this.terpilih,
  });

  final List<String> semuaKategori;
  final String terpilih;

  @override
  State<_IsiPemilihKategori> createState() => _IsiPemilihKategoriState();
}

class _IsiPemilihKategoriState extends State<_IsiPemilihKategori> {
  final _ctrl = TextEditingController();
  late String _terpilih = widget.terpilih;
  bool _adaTeks = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final ada = _ctrl.text.trim().isNotEmpty;
    if (ada != _adaTeks) {
      setState(() => _adaTeks = ada);
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _simpanBaru() async {
    final teks = _ctrl.text.trim();
    if (teks.isEmpty) return;
    await LayananKosakata.instance.simpanKategoriKustom(teks);
    if (!mounted) return;
    Navigator.pop(context, teks);
  }

  @override
  Widget build(BuildContext context) {
    // Bisa di-scroll: saat HP dimiringkan, apalagi dengan keyboard terbuka,
    // daftar kategori dan kolom kategori baru tidak muat setinggi layar.
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Kategori Kosakata',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: TemaBritishly.tinta,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.semuaKategori
                  .map(
                    (k) => ChoiceChip(
                      label: Text(k),
                      selected: _terpilih == k,
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() => _terpilih = k);
                        Navigator.pop(context, k);
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            const Text(
              'Atau buat kategori baru',
              style: TextStyle(
                fontSize: 13,
                color: TemaBritishly.tintaPudar,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _simpanBaru(),
                    decoration: InputDecoration(
                      hintText: 'Nama kategori baru...',
                      hintStyle: const TextStyle(
                        color: TemaBritishly.tintaPudar,
                        fontSize: 14,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      filled: true,
                      fillColor: TemaBritishly.kremIsi,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: TemaBritishly.kremGaris),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: TemaBritishly.kremGaris),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: TemaBritishly.hijau,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Tooltip(
                  message: _adaTeks
                      ? 'Gunakan kategori ini'
                      : 'Ketik nama kategori terlebih dahulu',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color:
                          _adaTeks ? TemaBritishly.hijau : TemaBritishly.kremIsi,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _adaTeks
                            ? TemaBritishly.hijau
                            : TemaBritishly.kremGaris,
                        width: 1,
                      ),
                      boxShadow: _adaTeks
                          ? [
                              BoxShadow(
                                color:
                                    TemaBritishly.hijau.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _adaTeks ? _simpanBaru : null,
                        borderRadius: BorderRadius.circular(14),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, anim) =>
                                ScaleTransition(scale: anim, child: child),
                            child: Icon(
                              _adaTeks
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              key: ValueKey<bool>(_adaTeks),
                              color: _adaTeks
                                  ? Colors.white
                                  : TemaBritishly.tintaPudar,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
