import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../services/layanan_auth.dart';

/// Menampilkan dialog konfirmasi penghapusan akun dengan verifikasi checklist
/// dan tombol 'X' untuk membatalkan sewaktu-waktu.
Future<bool?> tampilkanDialogHapusAkun(
  BuildContext context, {
  Future<void> Function()? onKonfirmasiHapus,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => DialogHapusAkun(
      onKonfirmasiHapus: onKonfirmasiHapus,
    ),
  );
}

/// Widget dialog modal konfirmasi hapus akun permanen.
class DialogHapusAkun extends StatefulWidget {
  const DialogHapusAkun({
    super.key,
    this.onKonfirmasiHapus,
  });

  final Future<void> Function()? onKonfirmasiHapus;

  @override
  State<DialogHapusAkun> createState() => _DialogHapusAkunState();
}

class _DialogHapusAkunState extends State<DialogHapusAkun> {
  bool _setuju = false;
  bool _sedangMemproses = false;

  Future<void> _prosesHapus() async {
    setState(() => _sedangMemproses = true);
    try {
      if (widget.onKonfirmasiHapus != null) {
        await widget.onKonfirmasiHapus!();
      } else {
        await LayananAuth.instance.hapusAkun();
      }
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Akun dan seluruh data Anda telah berhasil dihapus.'),
            backgroundColor: TemaBritishly.tinta,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sedangMemproses = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LayananAuth.pesanRamah(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: skema.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: skema.error,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Hapus Akun Permanen?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: TemaBritishly.tinta,
              ),
            ),
          ),
          // Tombol 'X' untuk membatalkan dialog
          IconButton(
            key: const Key('tombol_tutup_dialog_hapus_akun'),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Batal',
            onPressed: _sedangMemproses ? null : () => Navigator.pop(context, false),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tindakan ini tidak dapat dibatalkan. Jika Anda melanjutkan, data berikut akan dihapus secara permanen:',
              style: TextStyle(
                fontSize: 13.5,
                color: TemaBritishly.tinta,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: skema.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: skema.error.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  _itemKonsekuensi(
                    icon: Icons.bookmark_remove_rounded,
                    teks: 'Seluruh kata tersimpan & catatan sinonim pribadi.',
                  ),
                  const SizedBox(height: 8),
                  _itemKonsekuensi(
                    icon: Icons.local_fire_department_rounded,
                    teks: 'Riwayat progres, streak belajar harian, dan kategori kustom.',
                  ),
                  const SizedBox(height: 8),
                  _itemKonsekuensi(
                    icon: Icons.person_off_rounded,
                    teks: 'Profil dan seluruh hak akses akun Britishly Anda.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              key: const Key('checklist_konfirmasi_hapus_akun'),
              onTap: _sedangMemproses
                  ? null
                  : () => setState(() => _setuju = !_setuju),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _setuju,
                        activeColor: skema.error,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: _sedangMemproses
                            ? null
                            : (val) => setState(() => _setuju = val ?? false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Saya memahami konsekuensi ini dan setuju untuk menghapus akun beserta seluruh data secara permanen.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          color: TemaBritishly.tinta,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('tombol_batal_hapus_akun'),
                onPressed: _sedangMemproses ? null : () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Batal',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('tombol_eksekusi_hapus_akun'),
                onPressed: (!_setuju || _sedangMemproses) ? null : _prosesHapus,
                style: FilledButton.styleFrom(
                  backgroundColor: skema.error,
                  disabledBackgroundColor: skema.error.withValues(alpha: 0.3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _sedangMemproses
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Hapus Akun',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _itemKonsekuensi({required IconData icon, required String teks}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.red.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            teks,
            style: TextStyle(
              fontSize: 12,
              color: Colors.red.shade900,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
