import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// Berapa hari ke depan yang dijadwalkan sekaligus.
  ///
  /// Notifikasi ini sekali-jalan (bukan berulang otomatis), jadi jangkauannya
  /// sebatas jumlah yang dipasang. Sebelumnya 7 hari dan hanya dipasang ulang
  /// ketika layar Kata Harian dibuka — artinya pengguna yang tidak membuka
  /// aplikasi selama seminggu berhenti menerima pengingat, padahal justru
  /// merekalah yang paling perlu diingatkan.
  static const int jumlahHariDijadwalkan = 14;

  /// Tanggal terakhir jadwal dipasang, supaya pemasangan ulang cukup sekali
  /// sehari walaupun aplikasi bolak-balik dibuka.
  static const String _kunciTerakhirDijadwalkan =
      'notifikasi_harian_dijadwalkan_pada';
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
      await _setelZonaWaktuLokal();

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

  /// Menyetel [tz.local] ke zona waktu HP pengguna.
  ///
  /// Kalau pembacaan nama zona gagal, `tz.local` tetap UTC — dan seluruh
  /// jadwal "tengah malam" ikut meleset jadi 07:00 WIB tanpa pesan error
  /// apa pun. Karena itu ada lapis kedua: mencari lokasi mana pun yang
  /// selisih waktunya sama dengan selisih waktu HP saat ini.
  ///
  /// Lapis kedua hanya mencocokkan offset, bukan aturan DST. Untuk Indonesia
  /// (yang tidak memakai DST) hasilnya identik; untuk zona ber-DST jadwalnya
  /// bisa bergeser satu jam setelah pergantian musim — masih jauh lebih baik
  /// daripada meleset tujuh jam.
  Future<void> _setelZonaWaktuLokal() async {
    try {
      final String namaZona = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(namaZona));
      _zonaWaktuAkurat = true;
      return;
    } catch (e) {
      debugPrint(
          'Gagal membaca nama zona waktu HP ($e). Mencoba mencocokkan lewat offset...');
    }

    try {
      final sekarang = DateTime.now();
      final offsetHp = sekarang.timeZoneOffset;
      final sekarangMs = sekarang.millisecondsSinceEpoch;

      for (final lokasi in tz.timeZoneDatabase.locations.values) {
        if (lokasi.timeZone(sekarangMs).offset == offsetHp) {
          tz.setLocalLocation(lokasi);
          _zonaWaktuAkurat = true;
          debugPrint('Zona waktu dicocokkan dari offset HP: ${lokasi.name}');
          return;
        }
      }
    } catch (e) {
      debugPrint('Pencocokan offset zona waktu gagal: $e');
    }

    _zonaWaktuAkurat = false;
    debugPrint(
        'PERINGATAN: zona waktu jatuh ke ${tz.local.name}. Notifikasi kata '
        'harian akan meleset dari tengah malam waktu setempat.');
  }

  bool _zonaWaktuAkurat = false;

  /// `false` bila zona waktu HP tidak terbaca sama sekali, sehingga jadwal
  /// notifikasi memakai UTC dan tidak jatuh tepat tengah malam setempat.
  bool get zonaWaktuAkurat => _zonaWaktuAkurat;

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

  /// Menjadwalkan notifikasi kata harian untuk hari-hari berikutnya tepat pada
  /// pukul 00:00 waktu lokal HP pengguna. Setiap notifikasi mencantumkan kata
  /// spesifik hari tersebut, diambil dari jadwal kata acak API yang sama
  /// dengan yang dibaca layar Kata Harian, jadi isinya selalu cocok.
  ///
  /// Aman dipanggil sesering apa pun: pemasangan ulang dilewati kalau hari ini
  /// sudah pernah dipasang, kecuali [paksa] bernilai `true`.
  Future<void> jadwalkanKataHarian({bool paksa = false}) async {
    if (kIsWeb) return;
    if (!_diinisialisasi) await inisialisasi();

    try {
      final sekarang = tz.TZDateTime.now(tz.local);
      // Penanda ikut membawa panjang window. Kalau versi aplikasi berikutnya
      // memakai jumlah hari yang berbeda, penandanya otomatis tidak cocok dan
      // jadwalnya dipasang ulang hari itu juga — tidak menunggu besok.
      final penandaHariIni = '${sekarang.year.toString().padLeft(4, '0')}-'
          '${sekarang.month.toString().padLeft(2, '0')}-'
          '${sekarang.day.toString().padLeft(2, '0')}'
          '#h$jumlahHariDijadwalkan#api';

      // Memasang ulang berarti belasan panggilan ke alarm sistem. Karena
      // method ini kini ikut dipanggil setiap aplikasi kembali ke depan,
      // sekali sehari sudah cukup.
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
        if (!paksa &&
            prefs.getString(_kunciTerakhirDijadwalkan) == penandaHariIni) {
          return;
        }
      } catch (_) {
        // Penyimpanan bermasalah bukan alasan melewatkan notifikasi.
        prefs = null;
      }

      // Kata diambil dulu (bisa beberapa detik saat pertama kali) sebelum
      // jadwal lama dibatalkan, supaya tidak ada jeda tanpa pengingat
      var jadwalKata = <String, String>{};
      try {
        jadwalKata = await LayananKataHarian.instance.siapkanJadwal(
          jumlahHariKeDepan: jumlahHariDijadwalkan,
        );
      } catch (_) {}

      // Kata cadangan (offline / belum login) bisa berbeda dengan kata yang
      // nanti ditetapkan server. Kalau ada yang memakai cadangan, penanda
      // "sudah dijadwalkan" tidak disimpan supaya dipasang ulang begitu
      // jadwal server bisa diambil.
      var pakaiCadangan = false;

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

      // Jadwalkan tepat pada jam 00:00 waktu lokal pengguna
      for (int i = 0; i <= jumlahHariDijadwalkan; i++) {
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
        final String? kataServer =
            jadwalKata[LayananKataHarian.teksTanggal(dt)];
        if (kataServer == null) pakaiCadangan = true;
        final String kataSpesifik =
            kataServer ?? LayananKataHarian.kataUntukTanggal(dt);

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

      if (!pakaiCadangan) {
        await prefs?.setString(_kunciTerakhirDijadwalkan, penandaHariIni);
      }
    } catch (e) {
      debugPrint('Gagal menjadwalkan notifikasi harian: $e');
    }
  }

  /// Membatalkan seluruh jadwal notifikasi harian yang terdaftar.
  ///
  /// Jangkauannya sengaja dilebihkan dari [jumlahHariDijadwalkan] supaya
  /// jadwal sisa dari versi aplikasi sebelumnya ikut terbersihkan.
  Future<void> batalkanNotifikasiHarian() async {
    if (kIsWeb) return;
    try {
      for (int i = 0; i <= jumlahHariDijadwalkan + 5; i++) {
        await _plugin.cancel(id: idNotifikasiHarian + i);
      }
    } catch (_) {}
  }
}
