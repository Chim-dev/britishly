import 'package:flutter/material.dart';

import '../../core/penanda_perubahan.dart';
import '../../core/tema.dart';
import '../../models/kata_tersimpan.dart';
import '../../models/sinonim.dart';
import '../../services/layanan_kamus.dart';
import '../../services/layanan_kosakata.dart';
import '../../widgets/lembar_detail_kata.dart';
import '../../widgets/pemilih_kategori.dart';
import '../../widgets/tombol_audio.dart';
import 'halaman_kosakata.dart' show warnaStatus;

/// Use Case 3 — bagian UPDATE penuh dan DELETE.
/// Tampilan Modern British Minimalist Detail & Editor.
class HalamanDetailKosakata extends StatefulWidget {
  const HalamanDetailKosakata({super.key, required this.kata});

  final KataTersimpan kata;

  @override
  State<HalamanDetailKosakata> createState() => _HalamanDetailKosakataState();
}

class _HalamanDetailKosakataState extends State<HalamanDetailKosakata> {
  late final TextEditingController _definisiCtrl =
      TextEditingController(text: widget.kata.definisi);
  late final TextEditingController _contohCtrl =
      TextEditingController(text: widget.kata.contoh);
  final _sinonimBaruCtrl = TextEditingController();

  late String _kategori = widget.kata.kategori;
  late StatusHafalan _status = widget.kata.status;
  late bool _favorit = widget.kata.favorit;
  late final List<Sinonim> _sinonim = List.of(widget.kata.sinonim);

  bool _sedangSimpan = false;
  bool _sedangCariSinonim = false;
  bool _adaPerubahan = false;

  @override
  void dispose() {
    _definisiCtrl.dispose();
    _contohCtrl.dispose();
    _sinonimBaruCtrl.dispose();
    super.dispose();
  }

  void _tandaiBerubah() {
    if (!_adaPerubahan) setState(() => _adaPerubahan = true);
  }

  Future<void> _simpan() async {
    setState(() => _sedangSimpan = true);

    // Menyimpan sekarang cuma dua langkah: satu UPDATE untuk seluruh kolom
    // kata (definisi, contoh, kategori, status, favorit sekaligus), lalu satu
    // RPC untuk sinonim. Dulu langkah pertama dipecah jadi tiga permintaan,
    // jadi kegagalan di tengah menyimpan sebagian perubahan tanpa pemberitahuan.
    //
    // Langkah kedua tetap terpisah karena memang tabel lain. Kalau yang itu
    // gagal, perubahan kata SUDAH tersimpan — dan itu yang dikatakan ke user,
    // bukan "gagal menyimpan" yang menyesatkan.
    var detailTersimpan = false;
    try {
      await LayananKosakata.instance.ubahDetail(
        widget.kata.id,
        definisi: _definisiCtrl.text.trim(),
        contoh: _contohCtrl.text.trim(),
        kategori: _kategori,
        status: _status != widget.kata.status ? _status : null,
        favorit: _favorit != widget.kata.favorit ? _favorit : null,
      );
      detailTersimpan = true;

      await LayananKosakata.instance.gantiSinonim(widget.kata.id, _sinonim);

      beriTahuKosakataBerubah();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perubahan berhasil disimpan.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      // Daftar di halaman sebelumnya tetap perlu disegarkan kalau kolom
      // katanya sempat tersimpan.
      if (detailTersimpan) beriTahuKosakataBerubah();
      if (!mounted) return;

      final pesan = LayananKosakata.pesanRamah(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detailTersimpan
                ? 'Detail kata tersimpan, tetapi sinonimnya gagal diperbarui. '
                    '$pesan'
                : pesan,
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _sedangSimpan = false);
    }
  }

  Future<void> _hapus() async {
    final setuju = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus "${widget.kata.kata}"?'),
        content: Text(
          _sinonim.isEmpty
              ? 'Item ini akan dihapus permanen dari daftar pribadimu.'
              : 'Item ini beserta ${_sinonim.length} sinonimnya akan dihapus permanen.',
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
      await LayananKosakata.instance.hapus(widget.kata.id);
      beriTahuKosakataBerubah();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${widget.kata.kata}" telah dihapus.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LayananKosakata.pesanRamah(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _tambahSinonimManual() {
    final teks = _sinonimBaruCtrl.text.trim();
    if (teks.isEmpty) return;

    final sudahAda =
        _sinonim.any((s) => s.teks.toLowerCase() == teks.toLowerCase());
    if (sudahAda) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sinonim tersebut sudah terdaftar.')),
      );
      return;
    }

    setState(() {
      _sinonim.add(Sinonim(teks: teks, dipilih: true));
      _sinonimBaruCtrl.clear();
      _adaPerubahan = true;
    });
  }

  Future<void> _cariSinonimLagi() async {
    setState(() => _sedangCariSinonim = true);
    try {
      final kataCari = widget.kata.kata.split('(').first.trim();
      final hasil = await LayananKamus.instance.cariSinonim(kataCari);
      if (!mounted) return;

      final sudahAda = _sinonim.map((s) => s.teks.toLowerCase()).toSet();
      final kandidat =
          hasil.where((s) => !sudahAda.contains(s.teks.toLowerCase())).toList();

      if (kandidat.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada sinonim baru dari kamus.')),
        );
        return;
      }

      final dipilih = await showModalBottomSheet<List<Sinonim>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _LembarPilihSinonim(kandidat: kandidat),
      );

      if (dipilih == null || dipilih.isEmpty || !mounted) return;
      setState(() {
        _sinonim.addAll(dipilih);
        _adaPerubahan = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LayananKamus.pesanRamah(e))),
      );
    } finally {
      if (mounted) setState(() => _sedangCariSinonim = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teksLafal = widget.kata.kata.split('(').first.trim();

    return Scaffold(
      backgroundColor: TemaBritishly.krem,
      appBar: AppBar(
        title: Text(widget.kata.kata),
        actions: [
          TombolAudio(teks: teksLafal, ukuran: 34),
          const SizedBox(width: 4),
          IconButton(
            tooltip: _favorit ? 'Lepas favorit' : 'Jadikan favorit',
            icon: Icon(
              _favorit ? Icons.star_rounded : Icons.star_outline_rounded,
              color: _favorit ? TemaBritishly.amber : TemaBritishly.tintaPudar,
              size: 24,
            ),
            onPressed: () {
              setState(() => _favorit = !_favorit);
              _tandaiBerubah();
            },
          ),
          IconButton(
            tooltip: 'Hapus',
            icon: const Icon(Icons.delete_outline_rounded,
                size: 22, color: TemaBritishly.merah),
            onPressed: _hapus,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          // ---- Status hafalan ----
          _judulBagian('STATUS HAFALAN'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: StatusHafalan.values.map((s) {
              final aktif = _status == s;
              return ChoiceChip(
                label: Text(s.label),
                selected: aktif,
                showCheckmark: false,
                avatar: Icon(Icons.circle, size: 9, color: warnaStatus(s)),
                onSelected: (_) {
                  setState(() => _status = s);
                  _tandaiBerubah();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ---- Kategori ----
          _judulBagian('KATEGORI'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final hasil = await pilihKategori(context, terpilih: _kategori);
              if (hasil == null || !mounted) return;
              setState(() => _kategori = hasil);
              _tandaiBerubah();
            },
            icon: const Icon(Icons.folder_open_rounded, size: 18),
            label: Row(
              children: [
                Text(_kategori),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: TemaBritishly.tintaPudar),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ---- Definisi ----
          _judulBagian('DEFINISI / MAKNA'),
          const SizedBox(height: 8),
          TextField(
            controller: _definisiCtrl,
            maxLines: null,
            minLines: 2,
            onChanged: (_) => _tandaiBerubah(),
            decoration: const InputDecoration(
              hintText: 'Definisi atau arti kata ini...',
            ),
          ),
          const SizedBox(height: 22),

          // ---- Contoh Kalimat ----
          _judulBagian('CONTOH PENGGUNAAN'),
          const SizedBox(height: 8),
          TextField(
            controller: _contohCtrl,
            maxLines: null,
            minLines: 2,
            onChanged: (_) => _tandaiBerubah(),
            decoration: const InputDecoration(
              hintText: 'Contoh dalam kalimat atau percakapan...',
            ),
          ),
          const SizedBox(height: 24),

          // ---- Sinonim ----
          Row(
            children: [
              _judulBagian('MAKNA SERUPA (${_sinonim.length})'),
              const Spacer(),
              TextButton.icon(
                onPressed: _sedangCariSinonim ? null : _cariSinonimLagi,
                icon: _sedangCariSinonim
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text('Cari Lagi'),
              ),
            ],
          ),
          const SizedBox(height: 6),

          if (_sinonim.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Center(
                  child: Text(
                    'Belum ada sinonim yang disimpan.',
                    style: TextStyle(
                        color: TemaBritishly.tintaPudar.withValues(alpha: 0.8)),
                  ),
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < _sinonim.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      title: Row(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => tampilkanLembarDetailKata(
                              context,
                              _sinonim[i].teks,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _sinonim[i].teks,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      decorationStyle: TextDecorationStyle.dotted,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    size: 14,
                                    color: TemaBritishly.hijau,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          TombolAudio(
                            teks: _sinonim[i].teks,
                            ukuran: 28,
                            tooltip: 'Dengarkan "${_sinonim[i].teks}"',
                          ),
                        ],
                      ),
                      subtitle: _sinonim[i].definisi == null
                          ? null
                          : Text(
                              _sinonim[i].definisi!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                      trailing: IconButton(
                        tooltip: 'Hapus sinonim',
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: TemaBritishly.tintaPudar,
                        ),
                        onPressed: () {
                          setState(() => _sinonim.removeAt(i));
                          _tandaiBerubah();
                        },
                      ),
                      dense: true,
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sinonimBaruCtrl,
                  onSubmitted: (_) => _tambahSinonimManual(),
                  decoration: const InputDecoration(
                    hintText: 'Tambah kata serupa manual...',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _tambahSinonimManual,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: const BoxDecoration(
          color: TemaBritishly.putih,
          border: Border(
            top: BorderSide(color: TemaBritishly.kremGaris, width: 0.8),
          ),
        ),
        child: SafeArea(
          top: false,
          child: FilledButton(
            onPressed: (!_adaPerubahan || _sedangSimpan) ? null : _simpan,
            child: _sedangSimpan
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_adaPerubahan
                    ? 'Simpan Perubahan'
                    : 'Belum Ada Perubahan'),
          ),
        ),
      ),
    );
  }

  Widget _judulBagian(String teks) => Text(
        teks,
        style: TemaBritishly.labelBagian,
      );
}

class _LembarPilihSinonim extends StatefulWidget {
  const _LembarPilihSinonim({required this.kandidat});

  final List<Sinonim> kandidat;

  @override
  State<_LembarPilihSinonim> createState() => _LembarPilihSinonimState();
}

class _LembarPilihSinonimState extends State<_LembarPilihSinonim> {
  @override
  Widget build(BuildContext context) {
    final jumlah = widget.kandidat.where((s) => s.dipilih).length;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (_, kontrolerScroll) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'Pilih Sinonim Tambahan',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              controller: kontrolerScroll,
              itemCount: widget.kandidat.length,
              itemBuilder: (_, i) => CheckboxListTile(
                value: widget.kandidat[i].dipilih,
                onChanged: (v) =>
                    setState(() => widget.kandidat[i].dipilih = v ?? false),
                title: Text(
                  widget.kandidat[i].teks,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: widget.kandidat[i].definisi == null
                    ? null
                    : Text(
                        widget.kandidat[i].definisi!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: SafeArea(
              top: false,
              child: FilledButton(
                onPressed: jumlah == 0
                    ? null
                    : () => Navigator.pop(
                          context,
                          widget.kandidat.where((s) => s.dipilih).toList(),
                        ),
                child: Text(
                  jumlah == 0
                      ? 'Pilih minimal 1 sinonim'
                      : 'Tambahkan $jumlah Sinonim',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
