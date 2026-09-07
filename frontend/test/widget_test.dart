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

    test('LayananGemini - menangani ketiadaan API key secara aman', () async {
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
}
