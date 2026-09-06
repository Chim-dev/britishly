import 'package:flutter/material.dart';

import '../../core/konstanta.dart';
import '../../core/penanda_perubahan.dart';
import '../../core/tema.dart';
import '../../models/kata_tersimpan.dart';
import '../../services/layanan_kosakata.dart';
import '../../widgets/tombol_audio.dart';
import 'halaman_detail_kosakata.dart';

/// Use Case 3 — Mengelola Daftar Kosakata & Akronim Pribadi.
/// Tampilan Modern British Minimalist Catalog.
class HalamanKosakata extends StatefulWidget {
  const HalamanKosakata({super.key});

  @override
  State<HalamanKosakata> createState() => _HalamanKosakataState();
}

class _HalamanKosakataState extends State<HalamanKosakata> {
  final _cariCtrl = TextEditingController();

  List<KataTersimpan> _daftar = [];
  bool _sedangMuat = true;
  String? _pesanError;

  String? _filterKategori;
  bool _filterFavorit = false;
  StatusHafalan? _filterStatus;

  @override
  void initState() {
    super.initState();
    _muat();
    penandaKosakataBerubah.addListener(_muat);
  }

  @override
  void dispose() {
    penandaKosakataBerubah.removeListener(_muat);
    _cariCtrl.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    if (!mounted) return;
    setState(() {
      _sedangMuat = true;
      _pesanError = null;
    });

    try {
      final data = await LayananKosakata.instance.ambilSemua(
        kategori: _filterKategori,
        hanyaFavorit: _filterFavorit,
        status: _filterStatus,
        cari: _cariCtrl.text,
      );
      if (!mounted) return;
      setState(() => _daftar = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _pesanError = LayananKosakata.pesanRamah(e));
    } finally {
      if (mounted) setState(() => _sedangMuat = false);
    }
  }

  Future<void> _gantiFavorit(KataTersimpan kata) async {
    try {
      await LayananKosakata.instance.ubahFavorit(kata.id, !kata.favorit);
      await _muat();
    } catch (e) {
      _tampilkanError(e);
    }
  }

  Future<void> _gantiStatus(KataTersimpan kata) async {
    final pilihan = await showModalBottomSheet<StatusHafalan>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ubah Status Hafalan',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              const SizedBox(height: 14),
              for (final s in StatusHafalan.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.circle, size: 12, color: warnaStatus(s)),
                  title: Text(
                    s.label,
                    style: TextStyle(
                      fontWeight: kata.status == s ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  trailing: kata.status == s
                      ? const Icon(Icons.check_rounded, color: TemaBritishly.hijau)
                      : null,
                  onTap: () => Navigator.pop(ctx, s),
                ),
            ],
          ),
        ),
      ),
    );

    if (pilihan == null || pilihan == kata.status) return;

    try {
      await LayananKosakata.instance.ubahStatus(kata.id, pilihan);
      await _muat();
    } catch (e) {
      _tampilkanError(e);
    }
  }

  Future<void> _hapus(KataTersimpan kata) async {
    final setuju = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus "${kata.kata}"?'),
        content: Text(
          kata.sinonim.isEmpty
              ? 'Item ini akan dihapus permanen dari daftarmu.'
              : 'Item ini beserta ${kata.sinonim.length} sinonimnya akan dihapus permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (setuju != true) return;

    try {
      await LayananKosakata.instance.hapus(kata.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${kata.kata}" telah dihapus.')),
      );
      await _muat();
    } catch (e) {
      _tampilkanError(e);
    }
  }

  void _tampilkanError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LayananKosakata.pesanRamah(e)),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Input Pencarian di Kosakata
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: TextField(
            controller: _cariCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _muat(),
            decoration: InputDecoration(
              hintText: 'Cari kata atau akronim tersimpan...',
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _cariCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _cariCtrl.clear();
                        _muat();
                      },
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),

        // Filter Carousel Pills
        _barisFilter(),

        // Konten List
        Expanded(child: _isi()),
      ],
    );
  }

  Widget _barisFilter() {
    final kategoriTersedia = <String>{
      ...kKategoriBawaan,
      ..._daftar.map((k) => k.kategori),
    }.toList();

    return Container(
      height: 46,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          // Filter Favorit
          FilterChip(
            label: const Text('Favorit'),
            avatar: Icon(
              _filterFavorit ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 17,
              color: _filterFavorit ? TemaBritishly.amber : TemaBritishly.tintaPudar,
            ),
            selected: _filterFavorit,
            onSelected: (v) {
              setState(() => _filterFavorit = v);
              _muat();
            },
          ),
          const SizedBox(width: 8),

          // Filter Status
          for (final s in StatusHafalan.values) ...[
            FilterChip(
              label: Text(s.label),
              avatar: Icon(Icons.circle, size: 8, color: warnaStatus(s)),
              selected: _filterStatus == s,
              onSelected: (v) {
                setState(() => _filterStatus = v ? s : null);
                _muat();
              },
            ),
            const SizedBox(width: 8),
          ],

          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            color: TemaBritishly.kremGaris,
          ),
          const SizedBox(width: 8),

          // Filter Kategori
          for (final k in kategoriTersedia) ...[
            FilterChip(
              label: Text(k),
              selected: _filterKategori == k,
              onSelected: (v) {
                setState(() => _filterKategori = v ? k : null);
                _muat();
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _isi() {
    if (_sedangMuat && _daftar.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_pesanError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: TemaBritishly.tintaPudar),
              const SizedBox(height: 12),
              Text(_pesanError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _muat, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
    }
    if (_daftar.isEmpty) {
      final adaFilter = _filterKategori != null ||
          _filterFavorit ||
          _filterStatus != null ||
          _cariCtrl.text.isNotEmpty;

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                adaFilter ? Icons.filter_alt_off_rounded : Icons.bookmark_border_rounded,
                size: 52,
                color: TemaBritishly.kremGaris,
              ),
              const SizedBox(height: 16),
              Text(
                adaFilter ? 'Tidak ada kata yang cocok' : 'Koleksimu masih kosong',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                adaFilter
                    ? 'Coba atur ulang atau longgarkan filter pencarianmu.'
                    : 'Cari kata atau akronim di tab Eksplorasi lalu simpan di sini.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: TemaBritishly.tintaPudar, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _muat,
      color: TemaBritishly.hijau,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        itemCount: _daftar.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _kartuKata(_daftar[i]),
      ),
    );
  }

  Widget _kartuKata(KataTersimpan kata) {
    // Teks untuk pengucapan audio (ambil singkatan/kata dasarnya saja jika ada tanda kurung)
    final teksLafal = kata.kata.contains('(')
        ? kata.kata.split('(').first.trim()
        : kata.kata;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HalamanDetailKosakata(kata: kata),
            ),
          );
          await _muat();
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: warnaStatus(kata.status), width: 4),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        kata.kata,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: TemaBritishly.tinta,
                        ),
                      ),
                    ),
                    // Tombol Audio British
                    TombolAudio(
                      teks: teksLafal,
                      ukuran: 32,
                      tooltip: 'Dengarkan "$teksLafal"',
                    ),
                    const SizedBox(width: 4),
                    // Tombol Favorit
                    IconButton(
                      tooltip: kata.favorit ? 'Lepas favorit' : 'Jadikan favorit',
                      icon: Icon(
                        kata.favorit ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: kata.favorit ? TemaBritishly.amber : TemaBritishly.tintaPudar,
                        size: 22,
                      ),
                      onPressed: () => _gantiFavorit(kata),
                    ),
                    // Menu opsi
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: TemaBritishly.tintaPudar,
                        size: 20,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      onSelected: (nilai) {
                        if (nilai == 'status') _gantiStatus(kata);
                        if (nilai == 'hapus') _hapus(kata);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'status',
                          child: Row(
                            children: [
                              Icon(Icons.flag_rounded, size: 18, color: TemaBritishly.hijau),
                              SizedBox(width: 10),
                              Text('Ubah Status Hafalan'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'hapus',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 18, color: TemaBritishly.merah),
                              SizedBox(width: 10),
                              Text('Hapus Item'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                if (kata.definisi.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 4, bottom: 12),
                    child: Text(
                      kata.definisi,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: TemaBritishly.tintaPudar,
                      ),
                    ),
                  ),

                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _label(kata.kategori, TemaBritishly.kremIsi, TemaBritishly.tinta),
                    _labelStatus(kata.status),
                    if (kata.sinonim.isNotEmpty)
                      _label(
                        '${kata.sinonim.length} sinonim',
                        TemaBritishly.hijauSamar,
                        TemaBritishly.hijau,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String teks, Color latar, Color warnaTeks) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: latar,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          teks,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: warnaTeks,
          ),
        ),
      );

  Widget _labelStatus(StatusHafalan status) {
    final warna = warnaStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: warna),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: warna,
            ),
          ),
        ],
      ),
    );
  }
}

Color warnaStatus(StatusHafalan status) => switch (status) {
      StatusHafalan.belum => TemaBritishly.statusBelum,
      StatusHafalan.sedang => TemaBritishly.statusSedang,
      StatusHafalan.sudah => TemaBritishly.statusSudah,
    };
