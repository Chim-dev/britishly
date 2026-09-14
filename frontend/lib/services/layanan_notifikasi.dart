import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'layanan_kata_harian.dart';

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
      // Inisialisasi database zona waktu
      tz.initializeTimeZones();

      // Sinkronisasi ke zona waktu lokal perangkat HP pengguna
      try {
        final String namaZona = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(namaZona));
      } catch (e) {
        debugPrint('Catatan: Gagal menyetel timezone lokal ($e), menggunakan zona default.');
      }

      const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
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

  /// Menjadwalkan notifikasi kata harian untuk hari-hari berikutnya tepat pada pukul 00:00 (12 malam waktu lokal HP pengguna).
  /// Setiap notifikasi secara eksplisit mencantumkan kata spesifik hari tersebut.
  Future<void> jadwalkanKataHarian({String? kata}) async {
    if (kIsWeb) return;
    if (!_diinisialisasi) await inisialisasi();

    try {
      final sekarang = tz.TZDateTime.now(tz.local);

      // Batalkan jadwal lama agar tidak terjadi duplikasi
      await batalkanNotifikasiHarian();

      // Gunakan exact alarm bila diizinkan agar tidak tertahan Doze Mode malam hari
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final bool canExact =
          await androidPlugin?.canScheduleExactNotifications() ?? false;
      final scheduleMode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
      );

      // Jadwalkan untuk 7 hari ke depan tepat pada jam 00:00 (12 malam waktu lokal pengguna)
      for (int i = 0; i <= 7; i++) {
        final waktuJadwal = tz.TZDateTime(
          tz.local,
          sekarang.year,
          sekarang.month,
          sekarang.day + i,
          0, // Jam 00:00 (12 malam waktu lokal pengguna)
          0,
        );

        // Jika jam 12 malam untuk hari ini (i == 0) sudah lewat, lewati
        if (waktuJadwal.isBefore(sekarang)) {
          continue;
        }

        final dt = DateTime(sekarang.year, sekarang.month, sekarang.day + i);
        final String kataSpesifik = (i == 0 && kata != null && kata.trim().isNotEmpty)
            ? kata.trim()
            : LayananKataHarian.kataUntukTanggal(dt);

        final judul = 'Kata Hari Ini: "$kataSpesifik" 🇬🇧';
        const isi = 'Yuk pelajari arti, pelafalan audio, dan contoh penggunaannya!';

        await _plugin.zonedSchedule(
          id: idNotifikasiHarian + i,
          title: judul,
          body: isi,
          scheduledDate: waktuJadwal,
          notificationDetails: const NotificationDetails(android: androidDetails),
          androidScheduleMode: scheduleMode,
          payload: 'kata_harian:$kataSpesifik',
        );
      }
    } catch (e) {
      debugPrint('Gagal menjadwalkan notifikasi harian: $e');
    }
  }

  /// Membatalkan seluruh jadwal notifikasi harian yang terdaftar.
  Future<void> batalkanNotifikasiHarian() async {
    if (kIsWeb) return;
    try {
      for (int i = 0; i < 15; i++) {
        await _plugin.cancel(id: idNotifikasiHarian + i);
      }
    } catch (_) {}
  }
}
