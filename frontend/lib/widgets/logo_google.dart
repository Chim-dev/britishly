import 'package:flutter/material.dart';

/// Widget mandiri yang menggambar logo Google 4 warna resmi (Merah, Kuning, Hijau, Biru)
/// menggunakan vektor Canvas Flutter tanpa butuh file aset eksternal.
class LogoGoogle extends StatelessWidget {
  const LogoGoogle({super.key, this.ukuran = 20});

  final double ukuran;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(ukuran, ukuran),
      painter: const _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final paintBlue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final paintGreen = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;
    final paintYellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;
    final paintRed = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;

    // 1. Jalur Biru (Blue)
    final blue = Path()
      ..moveTo(23.75, 12.27)
      ..cubicTo(23.75, 11.57, 23.69, 10.87, 23.56, 10.20)
      ..lineTo(12.0, 10.20)
      ..lineTo(12.0, 14.71)
      ..lineTo(18.60, 14.71)
      ..cubicTo(18.31, 16.23, 17.46, 17.53, 16.20, 18.39)
      ..lineTo(16.20, 21.44)
      ..lineTo(20.08, 21.44)
      ..cubicTo(22.35, 19.35, 23.75, 16.27, 23.75, 12.27)
      ..close();
    canvas.drawPath(blue, paintBlue);

    // 2. Jalur Hijau (Green)
    final green = Path()
      ..moveTo(12.0, 24.0)
      ..cubicTo(15.24, 24.0, 17.95, 22.92, 19.93, 21.09)
      ..lineTo(16.05, 18.04)
      ..cubicTo(14.97, 18.76, 13.60, 19.20, 12.0, 19.20)
      ..cubicTo(8.88, 19.20, 6.23, 17.10, 5.28, 14.27)
      ..lineTo(1.25, 14.27)
      ..lineTo(1.25, 17.42)
      ..cubicTo(3.26, 21.36, 7.33, 24.0, 12.0, 24.0)
      ..close();
    canvas.drawPath(green, paintGreen);

    // 3. Jalur Kuning (Yellow)
    final yellow = Path()
      ..moveTo(5.28, 14.27)
      ..cubicTo(5.03, 13.55, 4.90, 12.78, 4.90, 12.0)
      ..cubicTo(4.90, 11.22, 5.03, 10.45, 5.28, 9.73)
      ..lineTo(5.28, 6.58)
      ..lineTo(1.25, 6.58)
      ..cubicTo(0.45, 8.16, 0.0, 9.98, 0.0, 12.0)
      ..cubicTo(0.0, 14.02, 0.45, 15.84, 1.25, 17.42)
      ..lineTo(5.28, 14.27)
      ..close();
    canvas.drawPath(yellow, paintYellow);

    // 4. Jalur Merah (Red)
    final red = Path()
      ..moveTo(12.0, 4.75)
      ..cubicTo(13.77, 4.75, 15.35, 5.36, 16.60, 6.55)
      ..lineTo(20.02, 3.13)
      ..cubicTo(17.95, 1.19, 15.24, 0.0, 12.0, 0.0)
      ..cubicTo(7.33, 0.0, 3.26, 2.64, 1.25, 6.58)
      ..lineTo(5.28, 9.73)
      ..cubicTo(6.23, 6.90, 8.88, 4.75, 12.0, 4.75)
      ..close();
    canvas.drawPath(red, paintRed);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
