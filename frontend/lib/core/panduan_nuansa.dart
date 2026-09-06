/// Panduan Rasa Bahasa & Nuansa Pemakaian Kosakata (Bahasa Indonesia).
///
/// Membantu pembelajar memahami "kapan harus menggunakan kata ini" dan
/// apa beda rasa/nuansa antara satu kata dengan sinonim-sinonimnya.
class PanduanNuansa {
  const PanduanNuansa._();

  /// Mengembalikan panduan kapan harus menggunakan kata ini dalam Bahasa Indonesia.
  static String tipsPenggunaan(String kata, {String? definisiInggris}) {
    final k = kata.trim().toLowerCase();

    final tips = _kamusNuansaKata[k];
    if (tips != null) return tips;

    // Fallback cerdas berdasarkan definisi atau konteks
    if (definisiInggris != null && definisiInggris.isNotEmpty) {
      final defLower = definisiInggris.toLowerCase();
      if (defLower.contains('very happy') || defLower.contains('pleased')) {
        return 'Gunakan kata ini untuk mengungkapkan perasaan senang atau gembira yang lebih kuat dan spesifik dibanding sekadar "happy".';
      }
      if (defLower.contains('very good') || defLower.contains('excellent')) {
        return 'Gunakan kata ini untuk memuji kualitas yang istimewa, jauh di atas standar biasa.';
      }
      if (defLower.contains('formal') || defLower.contains('official')) {
        return 'Kata ini berbobot formal, sangat cocok dipakai dalam konteks akademis, bisnis, atau wawancara profesional.';
      }
      if (defLower.contains('informal') || defLower.contains('slang')) {
        return 'Kata ini bernuansa santai atau kasual, sangat pas digunakan dalam percakapan sehari-hari bersama teman.';
      }
    }

    return 'Gunakan kata ini untuk memperkaya variasi kosakatamu agar tulisan atau percakapanmu terdengar lebih kaya, presisi, dan natural.';
  }

  /// Menjelaskan nuansa spesifik sebuah sinonim dalam Bahasa Indonesia.
  static String nuansaSinonim(String sinonim, {String? definisiAsli}) {
    final s = sinonim.trim().toLowerCase();
    final artiLokal = _kamusNuansaSinonim[s];
    if (artiLokal != null) return artiLokal;

    if (definisiAsli != null && definisiAsli.isNotEmpty) {
      return definisiAsli;
    }

    return 'Memiliki makna serupa, dapat digunakan sebagai variasi ekspresi.';
  }

  // -------------------------------------------------------------------------
  // DATABASE NUANSA KATA POPULER & KATA HARIAN (Bahasa Indonesia)
  // -------------------------------------------------------------------------
  static const Map<String, String> _kamusNuansaKata = {
    // Seri Emosi & Bahagia
    'happy':
        'Kata paling umum untuk "senang". Cocok untuk segala situasi santai maupun formal, namun terdengar biasa jika sering diulang.',
    'delighted':
        'Gunakan saat kamu merasa sangat senang dan puas, terutama ketika menerima kabar baik atau hadiah tak terduga.',
    'thrilled':
        'Gunakan saat senang yang bercampur rasa antusias tinggi atau berdebar penuh semangat (misal: lolos seleksi impian).',
    'content':
        'Gunakan untuk rasa senang yang tenang, damai, dan merasa sudah cukup dengan apa yang dimiliki tanpa menuntut lebih.',
    'ecstatic':
        'Gunakan untuk tingkat kegembiraan yang luar biasa dahsyat hingga sulit membendung rasa bahagianya.',
    'serendipity':
        'Gunakan saat kamu menemukan hal menyenangkan secara tak terduga dan tanpa dicari sama sekali—bukan sekadar keberuntungan biasa (luck).',
    'eloquent':
        'Gunakan saat memuji seseorang yang berbicara atau menulis dengan gaya bahasa yang sangat indah, mengalir lancar, dan meyakinkan.',
    'resilient':
        'Gunakan untuk orang atau mental yang cepat bangkit dan pulih kembali setelah mengalami masa-masa sulit atau kegagalan.',
    'meticulous':
        'Gunakan untuk seseorang yang sangat teliti, presisi, dan memperhatikan setiap detail terkecil dalam bekerja.',
    'candid':
        'Gunakan untuk kejujuran apa adanya tanpa dibuat-buat, atau foto dan video yang diambil secara spontan.',
    'pragmatic':
        'Gunakan untuk pendekatan praktis yang fokus pada solusi nyata di lapangan daripada teori idealis.',
    'diligent':
        'Gunakan untuk sifat tekun, gigih, dan konsisten berusaha dalam waktu lama.',
    'gracious':
        'Gunakan untuk sikap yang ramah, sopan, penuh kehangatan, dan berjiwa besar saat memperlakukan orang lain.',
    'vivid':
        'Gunakan untuk gambaran ingatan, mimpi, atau imajinasi yang terasa begitu hidup, jelas, dan tajam seolah nyata.',
    'humble':
        'Gunakan untuk orang hebat atau berprestasi yang tetap rendah hati dan tidak meninggikan dirinya.',
    'ambitious':
        'Gunakan untuk orang yang memiliki impian dan tekad kuat untuk mencapai kesuksesan besar.',
    'profound':
        'Gunakan untuk pemikiran, perasaan, atau makna filosofis yang sangat dalam dan menggetarkan hati.',
    'genuine':
        'Gunakan untuk barang asli (bukan tiruan) atau ketulusan perasaan seseorang yang murni tanpa pamrih.',
    'versatile':
        'Gunakan untuk orang yang serba bisa di banyak bidang, atau alat yang memiliki banyak fungsi praktis.',
    'thorough':
        'Gunakan untuk pekerjaan atau pemeriksaan yang dikerjakan secara menyeluruh sampai ke akar-akarnya tanpa terlewat.',
    'prudent':
        'Gunakan untuk kehati-hatian bijak dalam mengambil keputusan, terutama urusan keuangan dan masa depan.',
    'earnest':
        'Gunakan untuk kesungguhan dan ketulusan niat yang serius tanpa main-main.',
    'lucid':
        'Gunakan untuk penjelasan yang begitu gamblang dan mudah dipahami, atau kondisi kesadaran yang sangat jernih.',
    'astute':
        'Gunakan untuk kecerdikan dan kelihaian seseorang dalam membaca situasi bisnis atau peluang menguntungkan.',

    // Seri Rekomendasi Tema
    'grateful':
        'Gunakan saat kamu merasakan rasa syukur yang tulus dan berterima kasih atas kebaikan yang diterima.',
    'curious':
        'Gunakan untuk rasa ingin tahu yang positif dan antusias untuk mempelajari hal baru.',
    'exhausted':
        'Gunakan saat energi tubuh atau pikiran sudah benar-benar habis terkuras (jauh lebih lelah daripada "tired").',
    'awkward':
        'Gunakan untuk situasi canggung, kikuk, atau kurang nyaman dalam interaksi sosial.',
    'cozy':
        'Gunakan untuk suasana ruangan atau tempat yang hangat, nyaman, dan membuat betah bersantai.',
    'stubborn':
        'Gunakan untuk orang yang keras kepala, teguh pada pendiriannya, dan sulit diajak berkompromi.',
    'itinerary':
        'Gunakan untuk daftar rencana detail rute dan jadwal perjalanan wisata atau dinas.',
    'revenue':
        'Gunakan untuk total pendapatan kotor yang diperoleh perusahaan sebelum dikurangi beban operasional.',
    'deadline':
        'Gunakan untuk batas waktu akhir pengumpulan tugas atau penyelesaian proyek.',
    'negotiate':
        'Gunakan untuk proses tawar-menawar demi mencapai kesepakatan yang saling menguntungkan kedua belah pihak.',
    'proposal':
        'Gunakan untuk rancangan usulan resmi yang diajukan untuk meminta persetujuan atau pendanaan.',
    'hypothesis':
        'Gunakan untuk dugaan ilmiah sementara yang harus diuji kebenarannya melalui penelitian atau eksperimen.',
    'concise':
        'Gunakan untuk gaya tulisan atau ucapan yang ringkas, padat, dan langsung ke inti tanpa bertele-tele.',
    'framework':
        'Gunakan untuk kerangka konseptual atau panduan struktural dalam membangun sistem atau menganalisis masalah.',

    // Seri Kata Hari Ini Tambahan
    'sincere':
        'Gunakan untuk ketulusan niat, ucapan, atau permohonan maaf yang murni dari lubuk hati tanpa kepura-puraan.',
    'benevolent':
        'Gunakan untuk orang yang memiliki kekuasaan atau kelapangan rezeki yang selalu bermurah hati dan peduli pada sesama.',
    'coherent':
        'Gunakan untuk tulisan, ide, atau argumen yang tersusun sangat logis, runtut, dan mudah dipahami alur pikirnya.',
    'daunting':
        'Gunakan untuk rintangan, tugas, atau prospek masa depan yang tampak begitu besar hingga menciutkan nyali.',
    'empathy':
        'Gunakan untuk kapasitas emosional mendalam dalam ikut merasakan dan mengerti kesedihan atau beban orang lain.',
    'fluent':
        'Gunakan untuk kemampuan berbicara atau menulis bahasa asing yang sangat lancar tanpa terbata-bata.',
    'gratitude':
        'Gunakan untuk rasa syukur dan terima kasih mendalam yang dirasakan atas pertolongan atau berkah kehidupan.',
    'harmony':
        'Gunakan untuk keselarasan, kedamaian, dan keharmonisan antara berbagai pihak atau unsur yang berbeda.',
    'insight':
        'Gunakan untuk pemahaman mendalam atau sudut pandang baru yang mencerahkan terhadap suatu permasalahan kompleks.',
    'jubilant':
        'Gunakan untuk luapan rasa bahagia dan perayaan kemenangan besar yang dirayakan dengan penuh sorak-sorai.',
    'keen':
        'Gunakan untuk minat yang sangat antusias dan bersemangat, atau indra pengamatan yang tajam dan peka.',
    'luminous':
        'Gunakan untuk sesuatu yang memancarkan cahaya lembut yang indah, atau kejernihan pemikiran yang memukau.',
    'mindful':
        'Gunakan untuk kondisi sadar penuh dan fokus memperhatikan apa yang sedang dialami saat ini tanpa terburu-buru.',
    'nuance':
        'Gunakan untuk perbedaan makna, ekspresi, atau warna yang sangat tipis dan halus namun memberikan dampak besar.',
    'optimistic':
        'Gunakan untuk sikap mental yang selalu yakin bahwa hal-hal baik akan terjadi di masa depan.',
    'perseverance':
        'Gunakan untuk kegigihan tanpa gentar dalam terus berjuang mencapai tujuan meski diterpa banyak kegagalan.',
    'quaint':
        'Gunakan untuk tempat atau bangunan yang memiliki pesona klasik zaman dulu yang unik dan menyenangkan.',
    'radiant':
        'Gunakan untuk wajah atau senyuman yang terpancar cerah, sehat, dan menularkan energi kebahagiaan.',
    'serene':
        'Gunakan untuk suasana alam atau ketenangan batin yang tenang, damai, dan bebas dari kebisingan.',
    'tenacious':
        'Gunakan untuk watak yang gigih, pantang menyerah, dan memegang teguh impian dengan komitmen tinggi.',
    'uplifting':
        'Gunakan untuk kabar, lagu, atau kisah yang membangkitkan rasa optimisme dan mengangkat moral seseorang.',
    'valiant':
        'Gunakan untuk keberanian gagah berani seperti ksatria dalam membela kebenaran atau menghadapi bahaya.',
    'wholesome':
        'Gunakan untuk sesuatu yang menyehatkan tubuh atau membawa dampak moral positif yang menghangatkan hati.',
    'zealous':
        'Gunakan untuk semangat yang berkobar-kobar dan dedikasi penuh gairah terhadap suatu keyakinan atau kegiatan.',
  };

  // -------------------------------------------------------------------------
  // DATABASE NUANSA SINONIM POPULER (Bahasa Indonesia)
  // -------------------------------------------------------------------------
  static const Map<String, String> _kamusNuansaSinonim = {
    // Sinonim Rasa Senang
    'happy': 'Senang secara umum dalam segala situasi.',
    'delighted': 'Sangat senang & puas atas kabar atau hadiah baik.',
    'thrilled': 'Senang bercampur rasa antusias tinggi dan berdebar gembira.',
    'content': 'Merasa cukup, damai, dan bersyukur apa adanya.',
    'ecstatic': 'Kegembiraan dahsyat meluap-luap yang tak terbendung.',
    'glad': 'Lega dan senang atas terkabulnya suatu harapan.',
    'cheerful': 'Riang gembira dan memancarkan aura positif ke sekeliling.',
    'joyful': 'Penuh sukacita mendalam dan rasa bahagia yang tulus.',
    'gleeful': 'Gembira ceria, terkadang sedikit usil seperti anak kecil.',
    'overjoyed': 'Teramat bahagia sampai hampir tidak percaya.',

    // Sinonim Lelah
    'tired': 'Lelah standar sehari-hari setelah beraktivitas.',
    'exhausted': 'Tenaga terkuras habis secara fisik maupun mental.',
    'fatigued': 'Lelah mendalam akibat beban kerja berat berkelanjutan.',
    'weary': 'Lelah batin atau jenuh setelah menempuh proses panjang.',
    'drained': 'Merasa seluruh energi dan semangat seperti tersedot habis.',

    // Sinonim Pintar / Cerdas
    'smart': 'Pintar umum, cepat menangkap hal baru.',
    'intelligent': 'Memiliki kapasitas logika dan analisa intelektual tinggi.',
    'clever': 'Cerdik dan lihai menemukan jalan keluar tak terduga.',
    'brilliant': 'Luar biasa jenius dengan ide-ide cemerlang.',
    'wise': 'Bijaksana, mampu membedakan baik dan buruk dari pengalaman.',

    // Sinonim Sulit
    'difficult': 'Sulit umum, butuh usaha lebih untuk diselesaikan.',
    'hard': 'Keras atau berat tantangannya.',
    'challenging': 'Menantang kemampuan dan mendorong untuk berkembang.',
    'arduous': 'Sangat berat, melelahkan, dan menguras tenaga luar biasa.',
    'tough': 'Keras, alot, dan membutuhkan ketahanan mental kuat.',

    // Sinonim Penting
    'important': 'Penting secara umum dan tidak boleh diabaikan.',
    'crucial': 'Sangat menentukan keberhasilan atau kegagalan suatu hal.',
    'vital': 'Mutlak diperlukan bagi kelangsungan sesuatu.',
    'essential': 'Mendasar dan harus ada sebagai unsur pokok.',
    'significant': 'Memiliki dampak atau arti yang cukup besar.',

    // Sinonim Indah / Cantik
    'beautiful': 'Indah atau cantik dipandang secara umum.',
    'gorgeous': 'Sangat memukau, elok, dan memesona penampilannya.',
    'stunning': 'Sangat memukau hingga membuat orang tertegun kagum.',
    'exquisite': 'Sangat elok, halus buatannya, dan berselera seni tinggi.',
    'attractive': 'Menarik perhatian dan memiliki daya pikat positif.',

    // Sinonim Cepat
    'fast': 'Cepat perpindahan fisik atau lajunya.',
    'quick': 'Cepat tanggap atau membutuhkan waktu sangat singkat.',
    'swift': 'Cepat, tangkas, dan gesit melesat.',
    'rapid': 'Cepat mengalami perkembangan atau perubahan tempo.',

    // Sinonim Besar
    'big': 'Besar secara ukuran umum.',
    'huge': 'Sangat besar melebihi rata-rata biasa.',
    'enormous': 'Masif dan luar biasa besar kapasitas atau skalanya.',
    'gigantic': 'Raksasa dan berukuran luar biasa megah.',

    // Sinonim Tenang / Damai
    'calm': 'Tenang dan tidak panik saat menghadapi tekanan.',
    'peaceful': 'Damai dan bebas dari ketegangan atau konflik.',
    'serene': 'Hening, teduh, dan tenteram tanpa gangguan.',
    'tranquil': 'Suasana sunyi yang menenangkan jiwa.',

    // Sinonim Berani
    'brave': 'Berani menghadapi rasa takut atau bahaya nyata.',
    'courageous': 'Pemberani dengan integritas moral dan tekad teguh.',
    'bold': 'Berani mengambil risiko dan tampil percaya diri di depan.',
    'fearless': 'Tanpa rasa takut sedikit pun dalam melangkah.',
  };
}
