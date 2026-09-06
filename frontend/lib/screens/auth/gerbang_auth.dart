import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/layanan_auth.dart';
import '../halaman_utama.dart';
import 'halaman_masuk.dart';

/// Penjaga pintu masuk aplikasi.
///
/// Memantau status login secara langsung, jadi begitu user berhasil masuk
/// atau menekan keluar, halamannya berganti sendiri — tidak perlu
/// Navigator.push manual di mana-mana.
class GerbangAuth extends StatelessWidget {
  const GerbangAuth({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: LayananAuth.instance.perubahanStatus,
      builder: (context, snapshot) {
        // Sebelum event pertama datang, pakai sesi yang sudah dipulihkan
        // Supabase dari penyimpanan lokal (fitur "tetap login").
        final sesi = snapshot.data?.session ??
            Supabase.instance.client.auth.currentSession;

        if (sesi == null) return const HalamanMasuk();
        return const HalamanUtama();
      },
    );
  }
}
