import '../models/akronim.dart';

/// Kategori bawaan untuk mengelompokkan kosakata.
/// User tetap boleh mengetik kategori sendiri.
const List<String> kKategoriBawaan = [
  'Sehari-hari',
  'Akronim & Slang',
  'Travel',
  'Bisnis',
  'Akademik',
  'Teknologi',
];

/// Daftar kata untuk fitur "Kata Hari Ini".
///
/// Kata dipilih berdasarkan tanggal, jadi semua hari sudah pasti dapat
/// kata yang berbeda dan berulang setahun sekali. Definisinya tetap
/// diambil dari Dictionary API, jadi daftar ini hanya berisi katanya.
const List<String> kSumberKataHarian = [
  'serendipity', 'eloquent', 'resilient', 'meticulous', 'candid',
  'pragmatic', 'diligent', 'gracious', 'vivid', 'humble',
  'ambitious', 'sincere', 'profound', 'genuine', 'versatile',
  'thorough', 'prudent', 'earnest', 'lucid', 'astute',
  'benevolent', 'coherent', 'daunting', 'empathy', 'fluent',
  'gratitude', 'harmony', 'insight', 'jubilant', 'keen',
  'luminous', 'mindful', 'nuance', 'optimistic', 'perseverance',
  'quaint', 'radiant', 'serene', 'tenacious', 'uplifting',
  'valiant', 'wholesome', 'zealous', 'adept', 'brisk',
  'compelling', 'deliberate', 'endeavor', 'frugal', 'glimpse',
  'heartfelt', 'immerse', 'jovial', 'kindle', 'legacy',
  'momentum', 'nurture', 'obstacle', 'poised', 'quench',
  'refine', 'steadfast', 'thrive', 'unravel', 'venture',
  'wander', 'yearn', 'zenith', 'abundant', 'clarity',
];

/// Saran kata untuk halaman pencarian, dikelompokkan per tema.
const Map<String, List<String>> kKataRekomendasi = {
  'Sehari-hari': [
    'grateful', 'curious', 'exhausted', 'awkward', 'cozy', 'stubborn',
  ],
  'Travel': [
    'itinerary', 'departure', 'landmark', 'souvenir', 'detour', 'scenic',
  ],
  'Bisnis': [
    'revenue', 'deadline', 'negotiate', 'proposal', 'stakeholder', 'leverage',
  ],
  'Akademik': [
    'hypothesis', 'analysis', 'evidence', 'concise', 'critique', 'framework',
  ],
};

/// Koleksi kurasi akronim & singkatan bahasa Inggris paling populer.
const List<Akronim> kKoleksiAkronim = [
  // Internet & Texting Slang
  Akronim(
    singkatan: 'FOMO',
    kepanjangan: 'Fear Of Missing Out',
    arti: 'Rasa cemas atau takut ketinggalan momen seru, kabar, atau tren yang sedang dirasakan orang lain.',
    kategori: 'Internet & Slang',
    contoh: 'I bought the concert ticket because of severe FOMO.',
  ),
  Akronim(
    singkatan: 'ASAP',
    kepanjangan: 'As Soon As Possible',
    arti: 'Sesegera mungkin, secepat yang bisa dilakukan.',
    kategori: 'Umum',
    contoh: 'Please send me the report ASAP.',
  ),
  Akronim(
    singkatan: 'TBH',
    kepanjangan: 'To Be Honest',
    arti: 'Jujur saja / sejujurnya (digunakan saat menyatakan opini pribadi secara blak-blakan).',
    kategori: 'Internet & Slang',
    contoh: 'TBH, I prefer staying home tonight.',
  ),
  Akronim(
    singkatan: 'IDK',
    kepanjangan: 'I Do Not Know',
    arti: 'Saya tidak tahu.',
    kategori: 'Internet & Slang',
    contoh: 'IDK where we should eat tonight.',
  ),
  Akronim(
    singkatan: 'IMO',
    kepanjangan: 'In My Opinion',
    arti: 'Menurut pendapat saya (bisa juga IMHO: In My Humble Opinion).',
    kategori: 'Internet & Slang',
    contoh: 'IMO, this design looks much cleaner.',
  ),
  Akronim(
    singkatan: 'BRB',
    kepanjangan: 'Be Right Back',
    arti: 'Segera kembali (memberitahu lawan bicara bahwa kita akan pergi sebentar).',
    kategori: 'Internet & Slang',
    contoh: 'Grabbing a cup of coffee, BRB!',
  ),
  Akronim(
    singkatan: 'TTYL',
    kepanjangan: 'Talk To You Later',
    arti: 'Sampai nanti / nanti kita bicara lagi.',
    kategori: 'Internet & Slang',
    contoh: 'I have to run now, TTYL!',
  ),
  Akronim(
    singkatan: 'TL;DR',
    kepanjangan: 'Too Long; Didn\'t Read',
    arti: 'Terlalu panjang jadi tidak dibaca seluruhnya; dipakai juga sebagai label rangkuman singkat di awal/akhir tulisan.',
    kategori: 'Internet & Slang',
    contoh: 'TL;DR: The project was approved and starts tomorrow.',
  ),
  Akronim(
    singkatan: 'GOAT',
    kepanjangan: 'Greatest Of All Time',
    arti: 'Terhebat sepanjang masa (gelar pujian tertinggi untuk atlet, musisi, atau karya).',
    kategori: 'Internet & Slang',
    contoh: 'Lionel Messi is considered the GOAT of football.',
  ),
  Akronim(
    singkatan: 'RN',
    kepanjangan: 'Right Now',
    arti: 'Sekarang juga / saat ini.',
    kategori: 'Internet & Slang',
    contoh: 'I am so busy RN, can I call you later?',
  ),
  Akronim(
    singkatan: 'NGL',
    kepanjangan: 'Not Gonna Lie',
    arti: 'Bukannya mau bohong / jujur saja.',
    kategori: 'Internet & Slang',
    contoh: 'NGL, that exam was harder than expected.',
  ),
  Akronim(
    singkatan: 'IRL',
    kepanjangan: 'In Real Life',
    arti: 'Di dunia nyata (berlawanan dengan di internet atau media sosial).',
    kategori: 'Internet & Slang',
    contoh: 'He is much friendlier IRL than on social media.',
  ),

  // Bisnis & Kerja
  Akronim(
    singkatan: 'ROI',
    kepanjangan: 'Return On Investment',
    arti: 'Tingkat pengembalian investasi (rasio keuntungan dibanding biaya investasi).',
    kategori: 'Bisnis',
    contoh: 'The marketing campaign generated a 300% ROI.',
  ),
  Akronim(
    singkatan: 'KPI',
    kepanjangan: 'Key Performance Indicator',
    arti: 'Indikator kinerja utama untuk mengukur keberhasilan suatu tujuan kerja.',
    kategori: 'Bisnis',
    contoh: 'Reaching 10,000 active users is our main KPI this quarter.',
  ),
  Akronim(
    singkatan: 'ETA',
    kepanjangan: 'Estimated Time of Arrival',
    arti: 'Perkiraan waktu kedatangan atau perkiraan waktu penyelesaian tugas.',
    kategori: 'Bisnis',
    contoh: 'What is the ETA for the final design delivery?',
  ),
  Akronim(
    singkatan: 'WFH',
    kepanjangan: 'Work From Home',
    arti: 'Bekerja dari rumah.',
    kategori: 'Bisnis',
    contoh: 'Our team does WFH on Mondays and Fridays.',
  ),
  Akronim(
    singkatan: 'OOO',
    kepanjangan: 'Out Of Office',
    arti: 'Sedang tidak di kantor / cuti / dinas luar.',
    kategori: 'Bisnis',
    contoh: 'I am OOO until next Monday with no email access.',
  ),
  Akronim(
    singkatan: 'EOD',
    kepanjangan: 'End Of Day',
    arti: 'Akhir jam kerja pada hari ini (biasanya sekitar pukul 17:00 atau 18:00).',
    kategori: 'Bisnis',
    contoh: 'Please review the document by EOD today.',
  ),
  Akronim(
    singkatan: 'B2B',
    kepanjangan: 'Business to Business',
    arti: 'Model bisnis transaksi antara satu perusahaan dengan perusahaan lain.',
    kategori: 'Bisnis',
    contoh: 'Our startup provides B2B software solutions.',
  ),
  Akronim(
    singkatan: 'FAQ',
    kepanjangan: 'Frequently Asked Questions',
    arti: 'Pertanyaan yang sering diajukan beserta jawabannya.',
    kategori: 'Umum',
    contoh: 'Check the website FAQ section before contacting support.',
  ),

  // Teknologi
  Akronim(
    singkatan: 'API',
    kepanjangan: 'Application Programming Interface',
    arti: 'Antarmuka penghubung yang memungkinkan dua aplikasi bertukar data.',
    kategori: 'Teknologi',
    contoh: 'Britishly uses the Free Dictionary API for definitions.',
  ),
  Akronim(
    singkatan: 'SDK',
    kepanjangan: 'Software Development Kit',
    arti: 'Kumpulan pustaka, perkakas, dan dokumentasi untuk membuat software pada platform tertentu.',
    kategori: 'Teknologi',
    contoh: 'Flutter is an open-source UI software development kit.',
  ),
  Akronim(
    singkatan: 'UI/UX',
    kepanjangan: 'User Interface & User Experience',
    arti: 'Tampilan antarmuka visual dan pengalaman interaksi kenyamanan pengguna.',
    kategori: 'Teknologi',
    contoh: 'Good UI/UX makes an app intuitive and enjoyable to use.',
  ),
  Akronim(
    singkatan: 'JSON',
    kepanjangan: 'JavaScript Object Notation',
    arti: 'Format standar pertukaran data teks yang ringan dan mudah dibaca manusia serta mesin.',
    kategori: 'Teknologi',
    contoh: 'The server returns data in JSON format.',
  ),
  Akronim(
    singkatan: 'SaaS',
    kepanjangan: 'Software as a Service',
    arti: 'Model distribusi software berbasis langganan di cloud tanpa perlu instalasi lokal.',
    kategori: 'Teknologi',
    contoh: 'Supabase is a Backend-as-a-Service, similar to SaaS.',
  ),
  Akronim(
    singkatan: 'DIY',
    kepanjangan: 'Do It Yourself',
    arti: 'Lakukan sendiri tanpa bantuan tenaga ahli (proyek kreatif rumahan).',
    kategori: 'Umum',
    contoh: 'She built a DIY bookshelf out of recycled wood.',
  ),
];
