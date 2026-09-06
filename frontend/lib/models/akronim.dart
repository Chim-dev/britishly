/// Model data untuk akronim dan singkatan bahasa Inggris.
class Akronim {
  const Akronim({
    required this.singkatan,
    required this.kepanjangan,
    required this.arti,
    required this.kategori,
    required this.contoh,
  });

  /// Bentuk singkatan (misal: "FOMO", "ASAP", "ROI")
  final String singkatan;

  /// Kepanjangan dalam bahasa Inggris (misal: "Fear Of Missing Out")
  final String kepanjangan;

  /// Penjelasan makna / konteks dalam bahasa Indonesia
  final String arti;

  /// Kategori akronim (Slang & Internet, Bisnis & Kerja, Teknologi, Umum)
  final String kategori;

  /// Contoh penggunaan dalam percakapan atau kalimat
  final String contoh;

  /// Menghasilkan format ringkas untuk disimpan ke daftar kosakata.
  String get teksLengkap => '$singkatan ($kepanjangan)';
}
