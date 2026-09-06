/// Hasil pencarian satu kata dari Free Dictionary API.
class HasilKamus {
  const HasilKamus({
    required this.kata,
    required this.fonetik,
    required this.makna,
  });

  final String kata;

  /// Pelafalan IPA, misal `/ˈhæpi/`. Kosong bila API tidak menyediakan.
  final String fonetik;

  final List<MaknaKata> makna;

  /// Definisi pertama yang tersedia — dipakai sebagai ringkasan
  /// saat kata disimpan ke daftar kosakata.
  String get definisiUtama {
    for (final m in makna) {
      for (final d in m.definisi) {
        if (d.teks.isNotEmpty) return d.teks;
      }
    }
    return '';
  }

  /// Contoh kalimat pertama yang tersedia.
  String get contohUtama {
    for (final m in makna) {
      for (final d in m.definisi) {
        if ((d.contoh ?? '').isNotEmpty) return d.contoh!;
      }
    }
    return '';
  }

  factory HasilKamus.dariJson(Map<String, dynamic> json) {
    // Ambil fonetik dari field "phonetic", atau cari di daftar "phonetics".
    var fonetik = (json['phonetic'] as String?)?.trim() ?? '';
    if (fonetik.isEmpty) {
      final daftar = json['phonetics'];
      if (daftar is List) {
        for (final p in daftar) {
          final teks = (p is Map ? p['text'] as String? : null)?.trim() ?? '';
          if (teks.isNotEmpty) {
            fonetik = teks;
            break;
          }
        }
      }
    }

    final maknaJson = json['meanings'];
    return HasilKamus(
      kata: json['word'] as String? ?? '',
      fonetik: fonetik,
      makna: maknaJson is List
          ? maknaJson
              .whereType<Map<String, dynamic>>()
              .map(MaknaKata.dariJson)
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'word': kata,
        'phonetic': fonetik,
        'meanings': makna.map((m) => m.toJson()).toList(),
      };

  HasilKamus salinDengan({String? fonetik, List<MaknaKata>? makna}) => HasilKamus(
        kata: kata,
        fonetik: fonetik ?? this.fonetik,
        makna: makna ?? this.makna,
      );
}

/// Satu kelompok makna berdasarkan jenis kata (noun, verb, adjective...).
class MaknaKata {
  const MaknaKata({required this.jenisKata, required this.definisi});

  final String jenisKata;
  final List<Definisi> definisi;

  factory MaknaKata.dariJson(Map<String, dynamic> json) {
    final defJson = json['definitions'];
    return MaknaKata(
      jenisKata: json['partOfSpeech'] as String? ?? '',
      definisi: defJson is List
          ? defJson
              .whereType<Map<String, dynamic>>()
              .map(Definisi.dariJson)
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'partOfSpeech': jenisKata,
        'definitions': definisi.map((d) => d.toJson()).toList(),
      };
}

class Definisi {
  const Definisi({required this.teks, this.contoh});

  final String teks;
  final String? contoh;

  factory Definisi.dariJson(Map<String, dynamic> json) => Definisi(
        teks: json['definition'] as String? ?? '',
        contoh: json['example'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'definition': teks,
        if (contoh != null) 'example': contoh,
      };
}
