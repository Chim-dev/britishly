// Tes ini memakai jalur "konfigurasi bermasalah" supaya tidak perlu
// menghubungi Supabase sungguhan — bisa jalan tanpa internet dan tanpa
// file .env yang valid.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:frontend/core/panduan_nuansa.dart';
import 'package:frontend/main.dart';
import 'package:frontend/models/hasil_kamus.dart';
import 'package:frontend/screens/auth/halaman_masuk.dart';
import 'package:frontend/services/layanan_auth.dart';
import 'package:frontend/services/layanan_kamus.dart';
import 'package:frontend/services/layanan_kosakata.dart';
import 'package:frontend/widgets/logo_google.dart';

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
  });
}
