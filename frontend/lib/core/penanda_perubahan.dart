import 'package:flutter/foundation.dart';

/// Penanda sederhana bahwa daftar kosakata berubah.
///
/// Setiap kali ada simpan / ubah / hapus, nilainya dinaikkan. Halaman
/// yang menampilkan daftar mendengarkan penanda ini lalu memuat ulang
/// datanya — jadi perubahan di satu halaman langsung terlihat di halaman
/// lain tanpa perlu paket state management tambahan.
final ValueNotifier<int> penandaKosakataBerubah = ValueNotifier<int>(0);

void beriTahuKosakataBerubah() => penandaKosakataBerubah.value++;
