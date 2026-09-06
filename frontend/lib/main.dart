import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/tema.dart';
import 'screens/auth/gerbang_auth.dart';
import 'services/layanan_notifikasi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LayananNotifikasi.instance.inisialisasi();

  String? errorInit;

  try {
    await dotenv.load(fileName: '.env');

    final url = dotenv.env['SUPABASE_URL']?.trim() ?? '';

    // Supabase sedang beralih dari "anon public key" (format JWT, diawali
    // eyJ...) ke "publishable key" (diawali sb_publishable_...). Keduanya
    // sama-sama aman ditanam di aplikasi, dan keduanya diterima di sini —
    // tergantung project-mu menampilkan yang mana.
    final key =
        (dotenv.env['SUPABASE_PUBLISHABLE_KEY']?.trim().isNotEmpty ?? false)
            ? dotenv.env['SUPABASE_PUBLISHABLE_KEY']!.trim()
            : (dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '');

    if (url.isEmpty || key.isEmpty) {
      throw 'SUPABASE_URL atau SUPABASE_ANON_KEY masih kosong di file .env';
    }
    if (url.contains('xxxx') || key.contains('xxxx')) {
      throw 'File .env masih berisi contoh. Ganti dengan nilai asli dari '
          'dashboard Supabase (Settings -> API Keys).';
    }
    if (key.startsWith('sb_secret_') || key.contains('service_role')) {
      throw 'Kamu memakai secret / service_role key. Key itu mem-bypass '
          'seluruh keamanan RLS dan tidak boleh ditanam di aplikasi. '
          'Pakai anon public atau publishable key.';
    }

    await Supabase.initialize(url: url, publishableKey: key);
  } catch (e) {
    errorInit = e.toString();
  }

  runApp(BritishlyApp(errorInit: errorInit));
}

class BritishlyApp extends StatelessWidget {
  const BritishlyApp({super.key, this.errorInit});

  /// Diisi hanya bila koneksi ke Supabase gagal disiapkan.
  final String? errorInit;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Britishly',
      debugShowCheckedModeBanner: false,
      theme: TemaBritishly.terang(),
      home: errorInit == null
          ? const GerbangAuth()
          : LayarKonfigurasiBermasalah(pesan: errorInit!),
    );
  }
}

/// Ditampilkan kalau aplikasi tidak bisa tersambung ke Supabase.
/// Lebih membantu daripada layar putih atau crash tanpa keterangan.
class LayarKonfigurasiBermasalah extends StatelessWidget {
  const LayarKonfigurasiBermasalah({super.key, required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    final warna = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 56, color: warna.error),
                  const SizedBox(height: 20),
                  Text(
                    'Konfigurasi bermasalah',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: warna.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      pesan,
                      style: TextStyle(color: warna.onErrorContainer),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Perbaiki file frontend/.env, lalu hentikan aplikasi '
                    'dan jalankan ulang. Hot reload tidak cukup — file .env '
                    'hanya dibaca sekali saat aplikasi mulai.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: warna.outline, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
