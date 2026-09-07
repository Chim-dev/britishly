/// Contoh kalimat dwibahasa (Inggris & terjemahan Bahasa Indonesia).
class ContohBilingual {
  const ContohBilingual({
    required this.kalimatInggris,
    required this.terjemahanIndonesia,
  });

  final String kalimatInggris;
  final String terjemahanIndonesia;

  factory ContohBilingual.fromJson(Map<String, dynamic> json) {
    return ContohBilingual(
      kalimatInggris: (json['en'] ?? json['kalimat_inggris'] ?? '').toString().trim(),
      terjemahanIndonesia:
          (json['id'] ?? json['terjemahan_indonesia'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'en': kalimatInggris,
        'id': terjemahanIndonesia,
      };
}

/// Model terstruktur untuk menyimpan penjelasan kosakata dari Gemini AI.
class PenjelasanAi {
  const PenjelasanAi({
    required this.kata,
    required this.artiIndonesia,
    required this.definisiSimpel,
    required this.nuansa,
    required this.contoh,
  });

  final String kata;
  final String artiIndonesia;
  final String definisiSimpel;
  final String nuansa;
  final List<ContohBilingual> contoh;

  factory PenjelasanAi.fromJson(Map<String, dynamic> json) {
    final daftarContohRaw = json['contoh'] ?? json['contoh_bilingual'];
    final List<ContohBilingual> listContoh = [];

    if (daftarContohRaw is List) {
      for (final item in daftarContohRaw) {
        if (item is Map<String, dynamic>) {
          listContoh.add(ContohBilingual.fromJson(item));
        } else if (item is Map) {
          listContoh.add(
            ContohBilingual.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return PenjelasanAi(
      kata: (json['kata'] ?? json['word'] ?? '').toString().trim(),
      artiIndonesia: (json['arti_indonesia'] ?? json['arti'] ?? '').toString().trim(),
      definisiSimpel: (json['definisi_simpel'] ?? json['definisi'] ?? '')
          .toString()
          .trim(),
      nuansa: (json['nuansa'] ?? json['penjelasan_nuansa'] ?? '').toString().trim(),
      contoh: listContoh,
    );
  }

  Map<String, dynamic> toJson() => {
        'kata': kata,
        'arti_indonesia': artiIndonesia,
        'definisi_simpel': definisiSimpel,
        'nuansa': nuansa,
        'contoh': contoh.map((c) => c.toJson()).toList(),
      };
}
