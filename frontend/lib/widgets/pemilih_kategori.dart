import 'package:flutter/material.dart';

import '../core/konstanta.dart';
import '../core/tema.dart';

/// Lembar pilihan kategori minimalis & estetis.
Future<String?> pilihKategori(
  BuildContext context, {
  String terpilih = 'Sehari-hari',
  List<String> kategoriTambahan = const [],
}) {
  final semua = <String>{...kKategoriBawaan, ...kategoriTambahan}.toList();

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

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _simpanBaru() {
    final teks = _ctrl.text.trim();
    if (teks.isEmpty) return;
    Navigator.pop(context, teks);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                  decoration: const InputDecoration(
                    hintText: 'Nama kategori baru...',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _simpanBaru,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
