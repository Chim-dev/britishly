import 'package:flutter/material.dart';

import '../../core/konstanta.dart';
import '../../core/panduan_nuansa.dart';
import '../../core/penanda_perubahan.dart';
import '../../core/tema.dart';
import '../../models/akronim.dart';
import '../../models/hasil_kamus.dart';
import '../../models/sinonim.dart';
import '../../services/layanan_kamus.dart';
import '../../services/layanan_kosakata.dart';
import '../../widgets/pemilih_kategori.dart';
import '../../widgets/tombol_audio.dart';

enum ModePencarian { kosakata, akronim }

/// Use Case 2 — Eksplorasi Kosakata, Sinonim, & Akronim Bahasa Inggris.
/// Sekaligus pintu masuk operasi CREATE (atomik ke Supabase).
class HalamanCari extends StatefulWidget {
  const HalamanCari({super.key});

  @override
  State<HalamanCari> createState() => _HalamanCariState();
}

class _HalamanCariState extends State<HalamanCari> {
  final _ctrl = TextEditingController();
  ModePencarian _mode = ModePencarian.kosakata;

  // State untuk Kosakata
  HasilKamus? _hasil;
  List<Sinonim> _sinonim = [];
  Set<String> _sudahTersimpan = {};
  bool _sedangMuat = false;
  bool _sedangMuatSinonim = false;
  bool _sedangSimpan = false;
  List<String> _saranLokal = [];
  String? _pesanError;
  String _judulError = 'Tidak ditemukan';
  IconData _ikonError = Icons.search_off_rounded;

  // State untuk Akronim
  String _filterKategoriAkronim = 'Semua';
  List<Akronim> _daftarAkronim = [];

  @override
  void initState() {
    super.initState();
    _daftarAkronim = LayananKamus.instance.cariAkronim('');
    _muatDaftarTersimpan();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _muatDaftarTersimpan() async {
    try {
      final tersimpan = await LayananKosakata.instance.ambilDaftarKata();
      if (mounted) setState(() => _sudahTersimpan = tersimpan);
    } catch (_) {}
  }

  // ---- PENCARIAN KOSAKATA & SINONIM ----
  Future<void> _cariKata([String? kataKunci]) async {
    final kata = (kataKunci ?? _ctrl.text).trim();
    if (kata.isEmpty) return;

    if (kataKunci != null) {
      _ctrl.text = kataKunci;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _sedangMuat = true;
      _sedangMuatSinonim = true;
      _pesanError = null;
      _hasil = null;
      _sinonim = [];
      _saranLokal = [];
    });

    // 1. Jalankan pencarian sinonim di latar belakang tanpa menahan render definisi utama
    LayananKamus.instance.cariSinonim(kata).then((daftarSinonim) {
      if (mounted) {
        setState(() {
          _sinonim = daftarSinonim;
          _sedangMuatSinonim = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _sedangMuatSinonim = false);
    });

    // 2. Ambil definisi kata utama (responsif & prioritas tinggi via Fast-Path Datamuse)
    try {
      final definisi = await LayananKamus.instance.cariDefinisi(
        kata,
        saatFonetikTiba: (fonetik) {
          if (mounted && _hasil != null && _hasil!.kata.toLowerCase() == kata.toLowerCase()) {
            setState(() {
              _hasil = _hasil!.salinDengan(fonetik: fonetik);
            });
          }
        },
      );
      _muatDaftarTersimpan();

      if (!mounted) return;
      setState(() {
        _hasil = definisi;
        _sedangMuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sedangMuat = false;
        _sedangMuatSinonim = false;
        _pesanError = LayananKamus.pesanRamah(e);
        final salahKata = e is KataTidakDitemukan;
        _judulError = salahKata ? 'Kata tidak ditemukan' : 'Koneksi bermasalah';
        _ikonError = salahKata ? Icons.search_off_rounded : Icons.cloud_off_rounded;
      });
    }
  }

  Future<void> _simpanKata() async {
    final hasil = _hasil;
    if (hasil == null) return;

    final kategori = await pilihKategori(context);
    if (kategori == null || !mounted) return;

    setState(() => _sedangSimpan = true);
    try {
      final terpilih = _sinonim.where((s) => s.dipilih).toList();

      await LayananKosakata.instance.simpanKata(
        kata: hasil.kata,
        definisi: hasil.definisiUtama,
        contoh: hasil.contohUtama,
        kategori: kategori,
        sinonim: terpilih,
      );

      beriTahuKosakataBerubah();
      await _muatDaftarTersimpan();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            terpilih.isEmpty
                ? '"${hasil.kata}" disimpan ke $kategori.'
                : '"${hasil.kata}" + ${terpilih.length} sinonim disimpan ke $kategori.',
          ),
        ),
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

  // ---- KURASI AKRONIM & SLANG ----
  void _filterAkronim() {
    var hasil = LayananKamus.instance.cariAkronim('');
    if (_filterKategoriAkronim != 'Semua') {
      hasil = hasil.where((a) => a.kategori == _filterKategoriAkronim).toList();
    }
    setState(() => _daftarAkronim = hasil);
  }

  Future<void> _simpanAkronim(Akronim akronim) async {
    setState(() => _sedangSimpan = true);
    try {
      await LayananKosakata.instance.simpanKata(
        kata: akronim.teksLengkap,
        definisi: '${akronim.kepanjangan} — ${akronim.arti}',
        contoh: akronim.contoh,
        kategori: 'Akronim & Slang',
        sinonim: const [],
      );

      beriTahuKosakataBerubah();
      await _muatDaftarTersimpan();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Akronim "${akronim.singkatan}" berhasil disimpan!'),
        ),
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
    return Column(
      children: [
        // Switcher Mode Minimalis: [ Kosakata & Sinonim ] vs [ Akronim & Slang ]
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: TemaBritishly.kremIsi,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TemaBritishly.kremGaris),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _tombolTabMode(
                    label: 'Kata & Sinonim',
                    ikon: Icons.menu_book_rounded,
                    aktif: _mode == ModePencarian.kosakata,
                    onTap: () {
                      if (_mode != ModePencarian.kosakata) {
                        setState(() {
                          _mode = ModePencarian.kosakata;
                          _ctrl.clear();
                          _hasil = null;
                          _pesanError = null;
                        });
                      }
                    },
                  ),
                ),
                Expanded(
                  child: _tombolTabMode(
                    label: 'Akronim & Slang',
                    ikon: Icons.tag_rounded,
                    aktif: _mode == ModePencarian.akronim,
                    onTap: () {
                      if (_mode != ModePencarian.akronim) {
                        setState(() {
                          _mode = ModePencarian.akronim;
                          _ctrl.clear();
                          _filterAkronim();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // Input Pencarian Modern (Hanya untuk Kata & Sinonim)
        if (_mode == ModePencarian.kosakata)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
            child: TextField(
              controller: _ctrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _cariKata(),
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'Ketik kata bahasa Inggris (e.g. delightful)...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _ctrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          setState(() {
                            _ctrl.clear();
                            _hasil = null;
                            _sinonim = [];
                            _saranLokal = [];
                            _pesanError = null;
                          });
                        },
                      ),
              ),
              onChanged: (val) {
                setState(() {
                  _saranLokal = LayananKamus.instance.cariSaranLokal(val);
                });
              },
            ),
          ),

        // Saran Kata Instan (Autocomplete Lokal)
        if (_mode == ModePencarian.kosakata &&
            _saranLokal.isNotEmpty &&
            _hasil == null &&
            !_sedangMuat)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _saranLokal.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final saran = _saranLokal[i];
                  return ActionChip(
                    avatar: const Icon(
                      Icons.bolt_rounded,
                      size: 14,
                      color: TemaBritishly.hijau,
                    ),
                    label: Text(saran),
                    backgroundColor: TemaBritishly.hijauSamar,
                    side: BorderSide(
                      color: TemaBritishly.hijau.withValues(alpha: 0.25),
                    ),
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: TemaBritishly.hijau,
                    ),
                    onPressed: () {
                      _cariKata(saran);
                    },
                  );
                },
              ),
            ),
          ),

        // Isi Halaman
        Expanded(
          child: _mode == ModePencarian.kosakata
              ? _tampilanKosakata()
              : _tampilanAkronim(),
        ),
      ],
    );
  }

  Widget _tombolTabMode({
    required String label,
    required IconData ikon,
    required bool aktif,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: aktif ? TemaBritishly.putih : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: aktif
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              ikon,
              size: 16,
              color: aktif ? TemaBritishly.hijau : TemaBritishly.tintaPudar,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                color: aktif ? TemaBritishly.hijau : TemaBritishly.tintaPudar,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================================================================
  // TAMPILAN KOSAKATA & SINONIM
  // ==================================================================
  Widget _tampilanKosakata() {
    if (_sedangMuat) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5),
            SizedBox(height: 18),
            Text(
              'Menelusuri kamus & relasi sinonim...',
              style: TextStyle(color: TemaBritishly.tintaPudar, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_pesanError != null) {
      return _Pesan(
        ikon: _ikonError,
        judul: _judulError,
        keterangan: _pesanError!,
      );
    }

    if (_hasil == null) return _saranKata();
    return _hasilPencarianKata(_hasil!);
  }

  Widget _saranKata() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        const Text(
          'Eksplorasi Kosakata',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: TemaBritishly.tinta,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Ketik kata di atas, atau sentuh salah satu rekomendasi berikut.',
          style: TextStyle(fontSize: 13, color: TemaBritishly.tintaPudar),
        ),
        const SizedBox(height: 20),

        for (final entri in kKataRekomendasi.entries) ...[
          Text(entri.key.toUpperCase(), style: TemaBritishly.labelBagian),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entri.value.map((kata) {
              return ActionChip(
                label: Text(kata),
                onPressed: () {
                  _ctrl.text = kata;
                  _cariKata();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TemaBritishly.kremIsi,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TemaBritishly.kremGaris),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.bolt_rounded, size: 20, color: TemaBritishly.hijau),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Kata yang pernah kamu cari disimpan di HP secara offline, sehingga dapat diakses cepat kapan saja.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: TemaBritishly.tintaPudar,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hasilPencarianKata(HasilKamus hasil) {
    final sudahAda = _sudahTersimpan.contains(hasil.kata.toLowerCase());
    final jumlahDipilih = _sinonim.where((s) => s.dipilih).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        // Kartu Kata Utama + Pelafalan + Tombol Audio British
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasil.kata,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.9,
                              color: TemaBritishly.tinta,
                            ),
                          ),
                          if (hasil.fonetik.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              hasil.fonetik,
                              style: const TextStyle(
                                fontSize: 14.5,
                                color: TemaBritishly.tintaPudar,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Tombol Audio British
                    TombolAudio(teks: hasil.kata),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: TemaBritishly.hijau,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Spacer(),
                    if (sudahAda)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: TemaBritishly.hijauSamar,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 13,
                              color: TemaBritishly.hijau,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Sudah Tersimpan',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: TemaBritishly.hijau,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Panduan Kapan Harus Menggunakan Kata Ini (Bahasa Indonesia)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TemaBritishly.hijauSamar.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: TemaBritishly.hijau.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.tips_and_updates_rounded,
                    size: 16,
                    color: TemaBritishly.hijau,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'KAPAN HARUS MENGGUNAKAN?',
                    style: TemaBritishly.labelBagian.copyWith(
                      fontSize: 10.5,
                      color: TemaBritishly.hijau,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                PanduanNuansa.tipsPenggunaan(
                  hasil.kata,
                  definisiInggris: hasil.definisiUtama,
                ),
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: TemaBritishly.tinta,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Definisi per jenis kata
        ...hasil.makna.map((m) => _kartuMakna(m)),

        // Bagian Sinonim
        const SizedBox(height: 10),
        Row(
          children: [
            const Text(
              'Makna Serupa (Sinonim)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: TemaBritishly.tinta,
              ),
            ),
            const Spacer(),
            if (_sinonim.isNotEmpty)
              Text(
                '$jumlahDipilih dipilih',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: TemaBritishly.hijau,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Pilih sinonim yang ingin disimpan bersama kata utama.',
          style: TextStyle(fontSize: 12.5, color: TemaBritishly.tintaPudar),
        ),
        const SizedBox(height: 12),

        if (_sedangMuatSinonim)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: TemaBritishly.hijau,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Menghubungkan sinonim terbaik...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: TemaBritishly.tintaPudar,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_sinonim.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Tidak ada kata serupa yang ditemukan untuk "${hasil.kata}".',
                style: const TextStyle(color: TemaBritishly.tintaPudar),
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < _sinonim.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  CheckboxListTile(
                    value: _sinonim[i].dipilih,
                    onChanged: (v) =>
                        setState(() => _sinonim[i].dipilih = v ?? false),
                    title: Row(
                      children: [
                        Text(
                          _sinonim[i].teks,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        TombolAudio(
                          teks: _sinonim[i].teks,
                          ukuran: 28,
                          tooltip: 'Dengar "${_sinonim[i].teks}"',
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        PanduanNuansa.nuansaSinonim(
                          _sinonim[i].teks,
                          definisiAsli: _sinonim[i].definisi,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: TemaBritishly.tintaPudar,
                          height: 1.35,
                        ),
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                ],
              ],
            ),
          ),

        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _sedangSimpan ? null : _simpanKata,
          icon: _sedangSimpan
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.bookmark_add_rounded, size: 20),
          label: Text(
            jumlahDipilih == 0
                ? 'Simpan Kata Ini'
                : 'Simpan Kata + $jumlahDipilih Sinonim',
          ),
        ),
        if (sudahAda) ...[
          const SizedBox(height: 8),
          const Text(
            'Kata ini sudah tersimpan. Kamu dapat mengelola sinonimnya di tab Koleksi.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: TemaBritishly.tintaPudar),
          ),
        ],
      ],
    );
  }

  Widget _kartuMakna(MaknaKata makna) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: TemaBritishly.hijauSamar,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  makna.jenisKata.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: TemaBritishly.hijau,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < makna.definisi.length && i < 3; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                Text(
                  '${i + 1}. ${makna.definisi[i].teks}',
                  style: const TextStyle(height: 1.5, fontSize: 14),
                ),
                if ((makna.definisi[i].contoh ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      '"${makna.definisi[i].contoh}"',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: TemaBritishly.tintaPudar,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==================================================================
  // TAMPILAN AKRONIM & SLANG
  // ==================================================================
  Widget _tampilanAkronim() {
    const kategoriList = [
      'Semua',
      'Internet & Slang',
      'Bisnis',
      'Teknologi',
      'Umum',
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        // Info Banner Akronim
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: TemaBritishly.kremIsi,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: TemaBritishly.kremGaris),
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_stories_outlined, size: 18, color: TemaBritishly.hijau),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Katalog kurasi akronim & slang bahasa Inggris. Pilih kategori di bawah:',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: TemaBritishly.tintaPudar,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Kategori Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: kategoriList.map((kat) {
              final aktif = _filterKategoriAkronim == kat;
              return Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 12),
                child: ChoiceChip(
                  label: Text(kat),
                  selected: aktif,
                  onSelected: (_) {
                    setState(() {
                      _filterKategoriAkronim = kat;
                      _filterAkronim();
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),

        // Daftar Hasil Akronim
        if (_daftarAkronim.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(
                  Icons.find_in_page_outlined,
                  size: 48,
                  color: TemaBritishly.tintaPudar,
                ),
                SizedBox(height: 12),
                Text(
                  'Belum ada akronim untuk kategori ini.',
                  style: TextStyle(color: TemaBritishly.tintaPudar),
                ),
              ],
            ),
          )
        else
          for (final akronim in _daftarAkronim) ...[
            _kartuAkronim(akronim),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Widget _kartuAkronim(Akronim akronim) {
    final sudahAda = _sudahTersimpan.contains(akronim.singkatan.toLowerCase()) ||
        _sudahTersimpan.contains(akronim.teksLengkap.toLowerCase());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Badge Akronim
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: TemaBritishly.hijauSamar,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    akronim.singkatan,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: TemaBritishly.hijau,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: TemaBritishly.kremIsi,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    akronim.kategori,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: TemaBritishly.tintaPudar,
                    ),
                  ),
                ),
                const Spacer(),
                // Audio pronunciation
                TombolAudio(
                  teks: '${akronim.singkatan}. ${akronim.kepanjangan}',
                  ukuran: 32,
                  tooltip: 'Dengarkan pengucapan',
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Kepanjangan (English)
            Text(
              akronim.kepanjangan,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: TemaBritishly.tinta,
              ),
            ),
            const SizedBox(height: 6),

            // Makna / Penjelasan
            Text(
              akronim.arti,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: TemaBritishly.tinta,
              ),
            ),

            if (akronim.contoh.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TemaBritishly.kremIsi,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"${akronim.contoh}"',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 12.5,
                    color: TemaBritishly.tintaPudar,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (sudahAda)
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 15,
                        color: TemaBritishly.hijau,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Tersimpan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: TemaBritishly.hijau,
                        ),
                      ),
                    ],
                  )
                else
                  TextButton.icon(
                    onPressed: _sedangSimpan ? null : () => _simpanAkronim(akronim),
                    icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                    label: const Text('Simpan'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

class _Pesan extends StatelessWidget {
  const _Pesan({
    required this.ikon,
    required this.judul,
    required this.keterangan,
  });

  final IconData ikon;
  final String judul;
  final String keterangan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 48, color: TemaBritishly.tintaPudar),
            const SizedBox(height: 14),
            Text(
              judul,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: TemaBritishly.tinta,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              keterangan,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: TemaBritishly.tintaPudar,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
