import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Layanan Notifikasi Lokal (Local Scheduled Notifications).
///
/// Bertanggung jawab menjadwalkan notifikasi "Kata Hari Ini" setiap hari
/// tanpa memerlukan server backend atau koneksi internet saat jam berbunyi.
class LayananNotifikasi {
  LayananNotifikasi._();

  static final LayananNotifikasi instance = LayananNotifikasi._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Listener jika notifikasi diklik oleh user
  final ValueNotifier<String?> padaNotifikasiDiklik =
      ValueNotifier<String?>(null);

  bool _diinisialisasi = false;

  static const int idNotifikasiHarian = 101;
  static const String channelId = 'kata_harian_britishly';
  static const String channelName = 'Kata Hari Ini Britishly';
  static const String channelDesc =
      'Pengingat harian untuk mempelajari kosakata baru bahasa Inggris';

  /// Inisialisasi plugin, timezone, dan notification channel.
  Future<void> inisialisasi() async {
    if (_diinisialisasi) return;

    if (kIsWeb) {
      _diinisialisasi = true;
      return;
    }

    try {
      // Inisialisasi database zona waktu lokal
      tz.initializeTimeZones();

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);

      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          padaNotifikasiDiklik.value = response.payload ?? 'kata_harian';
        },
      );

      // Daftarkan channel notifikasi untuk Android 8.0+
      const channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDesc,
        importance: Importance.high,
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      _diinisialisasi = true;
    } catch (e) {
      debugPrint('Gagal inisialisasi LayananNotifikasi: $e');
    }
  }

  /// Meminta izin notifikasi (wajib untuk Android 13+).
  ///
  /// Jika ditolak oleh pengguna, fungsi ini mengembalikan `false` secara aman
  /// tanpa melempar error atau mengganggu alur aplikasi.
  Future<bool> mintaIzin() async {
    if (kIsWeb) return false;

    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;

      final diizinkan = await android.requestNotificationsPermission();
      return diizinkan ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Menjadwalkan notifikasi berulang setiap hari pada pukul 08:00 pagi.
  ///
  /// Jika [kata] disediakan, notifikasi akan mencantumkan kata tersebut secara spesifik.
  Future<void> jadwalkanKataHarian({String? kata}) async {
    if (kIsWeb) return;
    if (!_diinisialisasi) await inisialisasi();

    try {
      final sekarang = tz.TZDateTime.now(tz.local);
      var waktuJadwal = tz.TZDateTime(
        tz.local,
        sekarang.year,
        sekarang.month,
        sekarang.day,
        8, // Jam 08:00 pagi
        0,
      );

      // Jika jam 8 pagi hari ini sudah lewat, jadwalkan untuk besok pagi
      if (waktuJadwal.isBefore(sekarang)) {
        waktuJadwal = waktuJadwal.add(const Duration(days: 1));
      }

      final judul = (kata != null && kata.trim().isNotEmpty)
          ? 'Kata Hari Ini: "${kata.trim()}" 🇬🇧'
          : 'Kata Hari Ini dari Britishly 🇬🇧';

      final isi = (kata != null && kata.trim().isNotEmpty)
          ? 'Ketuk untuk melihat arti, pelafalan audio, dan contoh penggunaannya!'
          : 'Yuk buka aplikasi untuk memperluas kosakata bahasa Inggrismu hari ini!';

      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      await _plugin.zonedSchedule(
        id: idNotifikasiHarian,
        title: judul,
        body: isi,
        scheduledDate: waktuJadwal,
        notificationDetails: const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'kata_harian',
      );
    } catch (e) {
      debugPrint('Gagal menjadwalkan notifikasi harian: $e');
    }
  }

  /// Membatalkan jadwal notifikasi harian jika pengguna ingin mematikan notifikasi.
  Future<void> batalkanNotifikasiHarian() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(id: idNotifikasiHarian);
    } catch (_) {}
  }
}
