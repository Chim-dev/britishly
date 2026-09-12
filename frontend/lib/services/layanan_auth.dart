import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Use Case 1 — Mendaftar & Masuk Akun.
///
/// Semua urusan autentikasi lewat sini, supaya halaman-halaman UI tidak
/// perlu tahu detail Supabase.
class LayananAuth {
  LayananAuth._();

  static final LayananAuth instance = LayananAuth._();

  SupabaseClient get _klien => Supabase.instance.client;

  /// User yang sedang login, `null` kalau belum.
  User? get penggunaSaatIni => _klien.auth.currentUser;

  /// Dipantau [GerbangAuth] untuk berpindah halaman otomatis
  /// saat user login atau logout.
  Stream<AuthState> get perubahanStatus => _klien.auth.onAuthStateChange;

  /// Mendaftar akun baru.
  ///
  /// Mengembalikan `true` bila user langsung ikut masuk (konfirmasi email
  /// dimatikan), `false` bila masih harus klik tautan di email dulu.
  Future<bool> daftar({
    required String email,
    required String password,
  }) async {
    final hasil = await _klien.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo:
          kIsWeb ? null : 'io.supabase.britishly://login-callback',
    );
    return hasil.session != null;
  }

  Future<void> masuk({
    required String email,
    required String password,
  }) async {
    await _klien.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Masuk atau mendaftar otomatis menggunakan akun Google.
  ///
  /// Di Android/iOS, mengutamakan Native Google Sign-In (Google Play Services)
  /// agar muncul dialog resmi bawaan sistem tanpa membuka browser web.
  /// Bila GOOGLE_WEB_CLIENT_ID belum diisi di .env, otomatis fallback ke Web OAuth.
  Future<bool> masukDenganGoogle() async {
    final webClientId =
        (dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim().isNotEmpty ?? false)
            ? dotenv.env['GOOGLE_WEB_CLIENT_ID']!.trim()
            : (dotenv.env['GOOGLE_WEB_CLIENT']?.trim() ?? '');

    final redirectTo = kIsWeb ? null : 'io.supabase.britishly://login-callback';

    if (!kIsWeb && webClientId.isNotEmpty) {
      try {
        final googleSignIn = GoogleSignIn(serverClientId: webClientId);

        // Bersihkan sesi lama agar pemilih akun Google selalu segar
        try {
          await googleSignIn.signOut();
        } catch (_) {}

        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          // Pengguna sengaja membatalkan / menutup dialog pemilihan akun Google
          return false;
        }

        final googleAuth = await googleUser.authentication;
        final idToken = googleAuth.idToken;
        final accessToken = googleAuth.accessToken;

        if (idToken == null) {
          throw 'Gagal mendapatkan ID Token dari akun Google.';
        }

        await _klien.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );
        return true;
      } on PlatformException catch (e) {
        debugPrint(
            'Native Google Sign-In error ($e). Melakukan fallback otomatis ke Web OAuth browser...');
        // Jika Google Play Services di HP gagal (misal: SHA-1 debug/release APK belum terdaftar),
        // otomatis alihkan ke Web OAuth browser agar user tetap bisa login tanpa terblokir.
        return await _klien.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirectTo,
        );
      } catch (e) {
        debugPrint(
            'Native Google Sign-In gagal ($e). Melakukan fallback otomatis ke Web OAuth browser...');
        return await _klien.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirectTo,
        );
      }
    }

    // Fallback Web OAuth murni bila webClientId kosong
    return await _klien.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
    );
  }

  Future<void> keluar() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _klien.auth.signOut();
  }

  /// Menghapus akun pengguna beserta seluruh data tersimpan secara permanen.
  ///
  /// Memanggil fungsi RPC `hapus_akun_saya` di Supabase untuk menghapus user dari auth.users
  /// (yang cascade ke saved_words dan word_synonyms).
  /// Juga membersihkan cache lokal (SharedPreferences) dan melakukan logout.
  Future<void> hapusAkun() async {
    final user = _klien.auth.currentUser;
    if (user == null) return;

    try {
      await _klien.rpc('hapus_akun_saya');
    } catch (e) {
      debugPrint('RPC hapus_akun_saya gagal: $e. Fallback menghapus data kata...');
      try {
        await _klien.from('saved_words').delete().eq('user_id', user.id);
      } catch (_) {}
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}

    await keluar();
  }


  /// Menerjemahkan error Supabase & Google Play Services
  /// menjadi kalimat yang ramah dan mudah dimengerti pengguna.
  static String pesanRamah(Object error) {
    if (error is AuthException) {
      final pesan = error.message.toLowerCase();

      if (pesan.contains('user cancelled') ||
          pesan.contains('cancelled') ||
          pesan.contains('access_denied')) {
        return 'Proses masuk dengan Google dibatalkan.';
      }
      if (pesan.contains('invalid login credentials')) {
        return 'Email atau password salah.';
      }
      if (pesan.contains('user already registered') ||
          pesan.contains('already been registered')) {
        return 'Email ini sudah terdaftar. Coba masuk saja.';
      }
      if (pesan.contains('email not confirmed')) {
        return 'Email belum dikonfirmasi. Cek kotak masukmu dulu.';
      }
      if (pesan.contains('password should be at least')) {
        return 'Password minimal 6 karakter.';
      }
      if (pesan.contains('unable to validate email') ||
          pesan.contains('invalid email')) {
        return 'Format email tidak valid.';
      }
      if (pesan.contains('rate limit') ||
          pesan.contains('too many requests')) {
        return 'Terlalu sering mencoba. Tunggu sebentar lalu ulangi.';
      }
      return error.message;
    }

    if (error is PlatformException) {
      final teks = error.toString().toLowerCase();
      final detail = (error.message ?? '').toLowerCase();

      if (teks.contains('10') || detail.contains('developer_error')) {
        return 'Konfigurasi Google Sign-In (SHA-1/Client ID) belum terdaftar untuk APK ini.';
      }
      if (teks.contains('12500') || detail.contains('sign_in_failed')) {
        return 'Gagal masuk via Google Play Services. Pastikan akun Google aktif di HP.';
      }
      if (teks.contains('canceled') ||
          teks.contains('cancelled') ||
          detail.contains('cancel')) {
        return 'Proses masuk dengan Google dibatalkan.';
      }
      if (teks.contains('network') || detail.contains('network')) {
        return 'Tidak dapat terhubung ke server Google.';
      }
      return 'Gagal masuk dengan Google: ${error.message ?? error.code}';
    }

    final teks = error.toString();
    if (teks.contains('SocketException') ||
        teks.contains('Failed host lookup') ||
        teks.contains('ClientException')) {
      return 'Tidak ada koneksi internet.';
    }
    return teks.replaceFirst('Exception: ', '');
  }
}
