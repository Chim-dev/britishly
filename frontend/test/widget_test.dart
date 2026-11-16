// Tes ini memakai jalur "konfigurasi bermasalah" supaya tidak perlu
// menghubungi Supabase sungguhan — bisa jalan tanpa internet dan tanpa
// file .env yang valid.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:frontend/core/panduan_nuansa.dart';
import 'package:frontend/main.dart';
import 'package:frontend/models/hasil_kamus.dart';
import 'package:frontend/models/penjelasan_ai.dart';
import 'package:frontend/screens/auth/halaman_masuk.dart';
import 'package:frontend/services/layanan_auth.dart';
import 'package:frontend/services/layanan_gemini.dart';
import 'package:frontend/services/layanan_kamus.dart';
import 'package:frontend/services/layanan_kata_harian.dart';
import 'package:frontend/services/layanan_kosakata.dart';
import 'package:frontend/widgets/dialog_animasi_streak.dart';
import 'package:frontend/widgets/dialog_hapus_akun.dart';
import 'package:frontend/widgets/logo_google.dart';
import 'package:frontend/widgets/pemilih_kategori.dart';

void main() {
  testWidgets('Menampilkan layar kesalahan bila .env bermasalah',
      (WidgetTester tester) async {
    const pesan = 'SUPABASE_URL atau SUPABASE_ANON_KEY masih kosong '
        'di file .env';

    await tester.pumpWidget(const BritishlyApp(errorInit: pesan));
    await tester.pumpAndSettle();

    expect(find.text('Konfigurasi bermasalah'), findsOneWidget);
    expect(find.text(pesan), findsOneWidget);
  });

  group('validasiEmail', () {
    test('menolak email kosong', () {
      expect(validasiEmail(''), 'Email belum diisi');
      expect(validasiEmail(null), 'Email belum diisi');
    });

    test('menolak format yang salah', () {
      expect(validasiEmail('andi'), 'Format email tidak valid');
      expect(validasiEmail('andi@'), 'Format email tidak valid');
      expect(validasiEmail('andi@mail'), 'Format email tidak valid');
    });

    test('menerima email yang benar', () {
      expect(validasiEmail('andi@mail.com'), isNull);
      expect(validasiEmail('  andi.b+tes@sub.mail.co.id  '), isNull);
    });
  });

  group('LayananKamus - Akronim', () {
    test('dapat menemukan akronim populer seperti FOMO dan ASAP', () {
      final hasilFomo = LayananKamus.instance.cariAkronim('FOMO');
      expect(hasilFomo, isNotEmpty);
      expect(hasilFomo.first.singkatan, 'FOMO');
      expect(hasilFomo.first.kepanjangan, 'Fear Of Missing Out');

      final hasilAsap = LayananKamus.instance.cariAkronim('asap');
      expect(hasilAsap, isNotEmpty);
      expect(hasilAsap.first.singkatan, 'ASAP');
    });

    test('pencarian kosong mengembalikan semua koleksi akronim', () {
      final semua = LayananKamus.instance.cariAkronim('');
      expect(semua.length, greaterThanOrEqualTo(20));
    });

    test('cariSaranLokal mengembalikan saran instan lokal berdasarkan awalan', () {
      final saran = LayananKamus.instance.cariSaranLokal('gr');
      expect(saran, isNotEmpty);
      expect(saran.any((s) => s.startsWith('gr')), isTrue);
    });

    test('HasilKamus serialisasi dan parsing makna berjalan dengan benar', () {
      final json = {
        'word': 'eloquent',
        'phonetic': '/ˈɛləkwənt/',
        'meanings': [
          {
            'partOfSpeech': 'adjective',
            'definitions': [
              {'definition': 'Fluently persuasive and articulate.'}
            ]
          }
        ]
      };
      final hasil = HasilKamus.dariJson(json);
      expect(hasil.kata, 'eloquent');
      expect(hasil.fonetik, '/ˈɛləkwənt/');
      expect(hasil.definisiUtama, 'Fluently persuasive and articulate.');
      expect(hasil.toJson()['word'], 'eloquent');
    });
  });

  group('PanduanNuansa', () {
    test('tipsPenggunaan mengembalikan kurasi kata terdaftar', () {
      final tips = PanduanNuansa.tipsPenggunaan('delighted');
      expect(tips, contains('sangat senang dan puas'));
    });

    test('tipsPenggunaan menggunakan fallback cerdas berbasis konteks formal', () {
      final tips = PanduanNuansa.tipsPenggunaan('unregistered_word',
          definisiInggris: 'An official or formal statement');
      expect(tips, contains('formal'));
    });

    test('nuansaSinonim mengembalikan penjelasan nuansa bahasa Indonesia', () {
      final nuansa = PanduanNuansa.nuansaSinonim('content');
      expect(nuansa, contains('Merasa cukup'));
    });
  });

  group('LayananKosakata - pesanRamah', () {
    test('menerjemahkan error JWT expired menjadi pesan ramah', () {
      expect(
        LayananKosakata.pesanRamah('JWT expired'),
        contains('Sesi masuk telah berakhir'),
      );
    });

    test('menerjemahkan error koneksi menjadi pesan ramah', () {
      expect(
        LayananKosakata.pesanRamah('SocketException: OS Error: Connection refused'),
        contains('Tidak dapat terhubung ke internet'),
      );
    });
  });

  group('LayananAuth - pesanRamah & LogoGoogle', () {
    test('menerjemahkan pembatalan Google Sign-In', () {
      expect(
        LayananAuth.pesanRamah(const AuthException('user cancelled')),
        contains('dibatalkan'),
      );
    });

    testWidgets('LogoGoogle merender tanpa error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LogoGoogle(ukuran: 24),
          ),
        ),
      );
      expect(find.byType(LogoGoogle), findsOneWidget);
    });

    test('LayananKamus - ambilKataAcakDinamis mengembalikan kata berdefinisi', () async {
      final hasil = await LayananKamus.instance.ambilKataAcakDinamis();
      expect(hasil.kata.isNotEmpty, isTrue);
      expect(hasil.makna.isNotEmpty, isTrue);
    });

    test('LayananKataHarian - kataUntukTanggal menghasilkan kata yang konsisten', () {
      final tgl1 = DateTime(2026, 9, 8);
      final kata1 = LayananKataHarian.kataUntukTanggal(tgl1);
      final kata2 = LayananKataHarian.kataUntukTanggal(tgl1);
      expect(kata1, kata2);
      expect(kata1.isNotEmpty, isTrue);

      final tglBesok = DateTime(2026, 9, 9);
      final kataBesok = LayananKataHarian.kataUntukTanggal(tglBesok);
      expect(kataBesok.isNotEmpty, isTrue);
    });

    test('PenjelasanAi - fromJson & toJson serialisasi berjalan dengan benar', () {
      final json = {
        'kata': 'curious',
        'arti_indonesia': 'penasaran, ingin tahu',
        'definisi_simpel': 'Eager to learn or know something new.',
        'nuansa': 'Dipakai untuk rasa ingin tahu yang kuat atau hal yang unik.',
        'contoh': [
          {
            'en': 'Children are naturally curious.',
            'id': 'Anak-anak secara alami selalu penasaran.'
          }
        ]
      };
      final ai = PenjelasanAi.fromJson(json);
      expect(ai.kata, 'curious');
      expect(ai.artiIndonesia, 'penasaran, ingin tahu');
      expect(ai.contoh.length, 1);
      expect(ai.contoh.first.kalimatInggris, 'Children are naturally curious.');
      expect(ai.contoh.first.terjemahanIndonesia, 'Anak-anak secara alami selalu penasaran.');

      final exported = ai.toJson();
      expect(exported['kata'], 'curious');
      expect(exported['arti_indonesia'], 'penasaran, ingin tahu');
    });

    // Aplikasi sudah tidak memegang API key Gemini sama sekali — panggilannya
    // lewat Edge Function Supabase. Yang dijaga di sini tetap sama: saat
    // servernya tidak bisa dihubungi, kegagalannya harus berupa Exception yang
    // bisa ditangani, bukan Error yang menembus penanganan di pemanggil.
    test('LayananGemini - gagal dengan aman saat server tak terjangkau',
        () async {
      expect(
        () => LayananGemini.instance.ambilPenjelasan('curious'),
        throwsA(isA<Exception>()),
      );
    });

    testWidgets(
        'PemilihKategori - tombol tambah berubah menjadi centang saat mengetik kategori baru',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    pilihKategori(context, kategoriTambahan: const []),
                child: const Text('Buka Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Modal'));
      await tester.pumpAndSettle();

      // Modal terbuka, kondisi awal teks kosong
      expect(find.text('Pilih Kategori Kosakata'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      // Ketik nama kategori baru
      await tester.enterText(find.byType(TextField), 'Slang Gaul');
      await tester.pumpAndSettle();

      // Ikon bertransformasi menjadi check_rounded dan aktif
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsNothing);
    });
  });

  group('Fitur Hapus Akun', () {
    testWidgets(
        'DialogHapusAkun menampilkan peringatan, tombol X membatalkan penghapusan',
        (tester) async {
      bool? hasilDialog;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  hasilDialog = await tampilkanDialogHapusAkun(context);
                },
                child: const Text('Buka Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Dialog'));
      await tester.pumpAndSettle();

      // Memastikan dialog, judul, dan konsekuensi tampil
      expect(find.text('Hapus Akun Permanen?'), findsOneWidget);
      expect(find.textContaining('Tindakan ini tidak dapat dibatalkan'), findsOneWidget);
      expect(find.textContaining('Seluruh kata tersimpan'), findsOneWidget);

      // Tombol X ada di header
      final tombolX = find.byKey(const Key('tombol_tutup_dialog_hapus_akun'));
      expect(tombolX, findsOneWidget);

      // Tombol hapus awal mula dalam kondisi nonaktif (disabled)
      final tombolHapus = tester.widget<FilledButton>(
        find.byKey(const Key('tombol_eksekusi_hapus_akun')),
      );
      expect(tombolHapus.onPressed, isNull);

      // Klik tombol 'X' untuk batal
      await tester.tap(tombolX);
      await tester.pumpAndSettle();

      // Dialog tertutup dan hasil false
      expect(find.text('Hapus Akun Permanen?'), findsNothing);
      expect(hasilDialog, isFalse);
    });

    testWidgets(
        'Checklist persetujuan mengaktifkan tombol Hapus Akun dan mengeksekusi callback',
        (tester) async {
      bool aksiHapusDipanggil = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => tampilkanDialogHapusAkun(
                  context,
                  onKonfirmasiHapus: () async {
                    aksiHapusDipanggil = true;
                  },
                ),
                child: const Text('Buka Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Dialog'));
      await tester.pumpAndSettle();

      // Awal mula tombol hapus disabled
      var tombolHapus = tester.widget<FilledButton>(
        find.byKey(const Key('tombol_eksekusi_hapus_akun')),
      );
      expect(tombolHapus.onPressed, isNull);

      // Klik checklist persetujuan
      await tester.tap(find.byKey(const Key('checklist_konfirmasi_hapus_akun')));
      await tester.pumpAndSettle();

      // Sekarang tombol hapus aktif
      tombolHapus = tester.widget<FilledButton>(
        find.byKey(const Key('tombol_eksekusi_hapus_akun')),
      );
      expect(tombolHapus.onPressed, isNotNull);

      // Tekan tombol Hapus Akun
      await tester.tap(find.byKey(const Key('tombol_eksekusi_hapus_akun')));
      await tester.pumpAndSettle();

      // Callback dieksekusi, dialog tertutup, dan notifikasi sukses muncul
      expect(aksiHapusDipanggil, isTrue);
      expect(find.text('Hapus Akun Permanen?'), findsNothing);
      expect(
        find.text('Akun dan seluruh data Anda telah berhasil dihapus.'),
        findsOneWidget,
      );
    });
  });

  group('DialogAnimasiStreak', () {
    testWidgets('menampilkan perayaan streak aktif', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DialogAnimasiStreak(
              tipe: TipeStreakDialog.aktif,
              streak: 5,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('STREAK AKTIF'), findsOneWidget);
      expect(find.text('Streak Belajar Terjaga! 🔥'), findsOneWidget);
      expect(find.text('5 Hari Berturut-turut'), findsOneWidget);
      expect(find.text('Pelajari Kata Hari Ini ✨'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsWidgets);
    });

    testWidgets('menampilkan pesan persuasif saat streak terputus / mengulang',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DialogAnimasiStreak(
              tipe: TipeStreakDialog.terputus,
              streak: 1,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('SEMANGAT BARU'), findsOneWidget);
      expect(find.text('Streak Mengulang dari Hari ke-1 🌱'), findsOneWidget);
      expect(find.text('Hari ke-1'), findsOneWidget);
      expect(find.textContaining('Jangan patah semangat'), findsOneWidget);
      expect(find.textContaining('Nyalakan Kembali Apiku! 🔥'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    testWidgets('menampilkan pesan awal untuk pengguna baru', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DialogAnimasiStreak(
              tipe: TipeStreakDialog.awal,
              streak: 1,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('MULAI STREAK'), findsOneWidget);
      expect(find.text('Langkah Pertama Dimulai! 🚀'), findsOneWidget);
      expect(find.text('Mulai Belajar Sekarang 🚀'), findsOneWidget);
    });
  });

  group('Tata letak landscape', () {
    // HP biasa (lebar portrait 360dp) yang dimiringkan.
    void miringkanLayar(WidgetTester tester) {
      tester.view.physicalSize = const Size(780, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    Widget pembuka(void Function(BuildContext) buka) => MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => buka(context),
                child: const Text('Buka'),
              ),
            ),
          ),
        );

    for (final tipe in TipeStreakDialog.values) {
      testWidgets('dialog streak ${tipe.name} tidak meluber', (tester) async {
        miringkanLayar(tester);
        await tester.pumpWidget(pembuka(
          (context) => tampilkanDialogStreak(context, tipe: tipe, streak: 7),
        ));
        await tester.tap(find.text('Buka'));
        // Animasi apinya berdenyut terus, jadi tidak bisa pumpAndSettle.
        await tester.pump(const Duration(milliseconds: 700));

        expect(find.byType(DialogAnimasiStreak), findsOneWidget);
      });
    }

    testWidgets('dialog hapus akun tidak meluber', (tester) async {
      miringkanLayar(tester);
      await tester.pumpWidget(pembuka(tampilkanDialogHapusAkun));
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();

      expect(find.text('Hapus Akun Permanen?'), findsOneWidget);
    });

    testWidgets('pemilih kategori tidak terpotong', (tester) async {
      miringkanLayar(tester);
      await tester.pumpWidget(pembuka(
        (context) => pilihKategori(context, kategoriTambahan: const []),
      ));
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();

      expect(find.text('Pilih Kategori Kosakata'), findsOneWidget);
    });
  });
}
