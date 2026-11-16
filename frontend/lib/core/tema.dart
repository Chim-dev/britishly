import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palet & gaya aplikasi Britishly: Opsi D — Tokyo Minimalist Charcoal & Lavender.
///
/// Karakter visual:
/// - Latar kanvas bersih Off-White / Paper Mist (`#FAFAFA`)
/// - Kartu putih bersih dengan garis tepi ultra-halus Slate (`#E4E4E7`)
/// - Aksen utama Electric Lavender / Vivid Violet (`#7C3AED`)
/// - Aksen sekunder Soft Lilac (`#8B5CF6`) & Lavender Mist (`#F3F0FF`)
/// - Teks Obsidian Charcoal pekat (`#18181B`) dengan kontras tajam & sleek
/// - Aksen status: Amber Gold (`#F59E0B`) untuk streak, Emerald (`#10B981`) untuk tersimpan
/// - Tipografi modern Plus Jakarta Sans yang tegas dan estetik
class TemaBritishly {
  const TemaBritishly._();

  // ---- Dasar tampilan (Tokyo Minimalist Paper) ----
  static const Color krem = Color(0xFFFAFAFA); // Latar kanvas Off-White
  static const Color kremIsi = Color(0xFFF4F4F6); // Wadah kutipan & input
  static const Color kremGaris = Color(0xFFE4E4E7); // Garis halus pemisah (Slate-200)
  static const Color putih = Color(0xFFFFFFFF); // Permukaan kartu

  // ---- Aksen Tokyo Lavender & Lilac ----
  static const Color hijau = Color(0xFF7C3AED); // Electric Lavender / Vivid Violet (Brand Primary)
  static const Color hijauAksen = Color(0xFF8B5CF6); // Soft Lilac Accent
  static const Color hijauSamar = Color(0xFFF3F0FF); // Lavender Mist Highlight

  // ---- Aksen Amber & Gold (Streak & Favorit) ----
  static const Color amber = Color(0xFFF59E0B); // Amber Gold
  static const Color amberSamar = Color(0xFFFEF3C7); // Sorotan amber lembut
  static const Color apiStreak = Color(0xFFF97316); // Api streak hangat

  // ---- Teks & Tint ----
  static const Color tinta = Color(0xFF18181B); // Deep Obsidian Charcoal
  static const Color tintaPudar = Color(0xFF71717A); // Cool Slate (Slate-500)
  static const Color merah = Color(0xFFEF4444); // Peringatan / error

  // ---- Status Hafalan ----
  static const Color statusBelum = Color(0xFF71717A); // Cool Slate
  static const Color statusSedang = Color(0xFF8B5CF6); // Soft Lilac
  static const Color statusSudah = Color(0xFF10B981); // Emerald Green

  static ThemeData terang() {
    final skema = ColorScheme.fromSeed(
      seedColor: hijau,
      brightness: Brightness.light,
    ).copyWith(
      primary: hijau,
      onPrimary: putih,
      primaryContainer: hijauSamar,
      onPrimaryContainer: hijau,
      secondary: amber,
      onSecondary: putih,
      secondaryContainer: amberSamar,
      onSecondaryContainer: tinta,
      surface: putih,
      onSurface: tinta,
      onSurfaceVariant: tintaPudar,
      surfaceContainerHighest: kremIsi,
      outline: tintaPudar,
      outlineVariant: kremGaris,
      error: merah,
      onError: putih,
    );

    final basisTeks = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: skema,
      scaffoldBackgroundColor: krem,
      dividerColor: kremGaris,
      splashColor: hijauSamar,
      highlightColor: hijauSamar,

      textTheme: basisTeks.copyWith(
        displaySmall: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
          color: tinta,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: tinta,
        ),
        headlineSmall: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: tinta,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: tinta,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w600,
          color: tinta,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          height: 1.6,
          color: tinta,
          fontSize: 15,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          height: 1.55,
          color: tinta,
          fontSize: 14,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: krem,
        foregroundColor: tinta,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: tinta,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),

      cardTheme: CardThemeData(
        color: putih,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: kremGaris, width: 1),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: putih,
        hintStyle: GoogleFonts.plusJakartaSans(
          color: tintaPudar,
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kremGaris, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kremGaris, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: hijau, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: merah, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: merah, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: hijau,
          foregroundColor: putih,
          disabledBackgroundColor: kremGaris,
          disabledForegroundColor: tintaPudar,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tinta,
          backgroundColor: putih,
          elevation: 0,
          side: const BorderSide(color: kremGaris, width: 1),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: hijau,
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: tintaPudar),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: putih,
        selectedColor: hijauSamar,
        checkmarkColor: hijau,
        side: const BorderSide(color: kremGaris, width: 1),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: tinta,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: putih,
        surfaceTintColor: Colors.transparent,
        indicatorColor: hijauSamar,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? hijau : tintaPudar,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected) ? hijau : tintaPudar,
          ),
        ),
      ),

      // Pengganti navigationBar saat HP dimiringkan (lihat HalamanUtama).
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: putih,
        indicatorColor: hijauSamar,
        elevation: 0,
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: hijau,
        ),
        unselectedLabelTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: tintaPudar,
        ),
        selectedIconTheme: const IconThemeData(size: 22, color: hijau),
        unselectedIconTheme: const IconThemeData(size: 22, color: tintaPudar),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: putih,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: putih,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tinta,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: putih, fontSize: 13.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: tintaPudar,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: tinta,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: GoogleFonts.plusJakartaSans(color: tintaPudar, fontSize: 13),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? hijau : Colors.transparent,
        ),
        side: const BorderSide(color: kremGaris, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: hijau,
        linearTrackColor: kremGaris,
        circularTrackColor: kremGaris,
      ),

      dividerTheme: const DividerThemeData(
        color: kremGaris,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Label kecil huruf besar untuk judul bagian
  static TextStyle labelBagian = GoogleFonts.plusJakartaSans(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: tintaPudar,
  );
}
