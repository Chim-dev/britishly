import 'sinonim.dart';

/// Status hafalan sebuah kata — cerminan enum `status_hafalan` di database.
enum StatusHafalan {
  belum('belum', 'Belum hafal'),
  sedang('sedang', 'Sedang dipelajari'),
  sudah('sudah', 'Sudah hafal');

  const StatusHafalan(this.nilaiDb, this.label);

  /// Nilai persis seperti yang disimpan Postgres.
  final String nilaiDb;
  final String label;

  static StatusHafalan dariDb(String? nilai) => StatusHafalan.values.firstWhere(
        (s) => s.nilaiDb == nilai,
        orElse: () => StatusHafalan.belum,
      );
}

/// Satu baris tabel `saved_words` beserta sinonimnya.
class KataTersimpan {
  const KataTersimpan({
    required this.id,
    required this.kata,
    required this.definisi,
    required this.contoh,
    required this.kategori,
    required this.favorit,
    required this.status,
    required this.dibuatPada,
    required this.sinonim,
  });

  final String id;
  final String kata;
  final String definisi;
  final String contoh;
  final String kategori;
  final bool favorit;
  final StatusHafalan status;
  final DateTime dibuatPada;
  final List<Sinonim> sinonim;

  factory KataTersimpan.dariBaris(Map<String, dynamic> baris) {
    final sinonimJson = baris['word_synonyms'];

    return KataTersimpan(
      id: baris['id'] as String,
      kata: baris['word'] as String? ?? '',
      definisi: baris['definition'] as String? ?? '',
      contoh: baris['example'] as String? ?? '',
      kategori: baris['category'] as String? ?? 'Sehari-hari',
      favorit: baris['is_favorite'] as bool? ?? false,
      status: StatusHafalan.dariDb(baris['status_hafalan'] as String?),
      dibuatPada:
          DateTime.tryParse(baris['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      sinonim: sinonimJson is List
          ? sinonimJson
              .whereType<Map<String, dynamic>>()
              .map(Sinonim.dariBaris)
              .toList()
          : const [],
    );
  }
}
