/// Satu kata bermakna serupa.
///
/// Dipakai di dua tempat: hasil pencarian dari Datamuse API (belum
/// tersimpan), dan isi tabel `word_synonyms` (sudah tersimpan).
class Sinonim {
  Sinonim({
    this.id,
    required this.teks,
    this.definisi,
    this.dipilih = false,
  });

  /// Terisi hanya bila sinonim ini sudah tersimpan di database.
  final String? id;

  final String teks;
  final String? definisi;

  /// Status centang saat user memilih sinonim mana yang ikut disimpan.
  bool dipilih;

  factory Sinonim.dariBaris(Map<String, dynamic> baris) => Sinonim(
        id: baris['id'] as String?,
        teks: baris['synonym_text'] as String? ?? '',
        definisi: baris['synonym_definition'] as String?,
        dipilih: true,
      );

  /// Bentuk yang dikirim ke function `save_word_with_synonyms`.
  Map<String, dynamic> keJson() => {
        'text': teks,
        if (definisi != null && definisi!.isNotEmpty) 'definition': definisi,
      };
}
