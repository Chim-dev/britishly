import 'package:flutter/foundation.dart';
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

  /// Masuk atau mendaftar otomatis menggunakan akun Google (OAuth 2.0 PKCE).
  ///
  /// Membuka peramban aman Google. Setelah disetujui, sesi JWT terenkripsi
  /// dikirimkan kembali melalui deep link dan disimpan di perangkat.
  Future<bool> masukDenganGoogle() async {
    final redirectTo = kIsWeb ? null : 'io.supabase.britishly://login-callback';
    return await _klien.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
    );
  }

  Future<void> keluar() => _klien.auth.signOut();

  /// Menerjemahkan error Supabase (Bahasa Inggris, kadang teknis)
  /// menjadi kalimat yang bisa dimengerti pengguna.
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

    final teks = error.toString();
    if (teks.contains('SocketException') ||
        teks.contains('Failed host lookup') ||
        teks.contains('ClientException')) {
      return 'Tidak ada koneksi internet.';
    }
    return teks.replaceFirst('Exception: ', '');
  }
}
