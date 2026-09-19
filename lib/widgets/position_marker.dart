import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class PositionArrowPainter extends CustomPainter {
  const PositionArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final fill = Paint()
      ..color = const Color(0xFF4A90E2)
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final path = ui.Path()
      ..moveTo(cx, 2)
      ..lineTo(cx + 9, cy + 12)
      ..lineTo(cx, cy + 6)
      ..lineTo(cx - 9, cy + 12)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(PositionArrowPainter oldDelegate) => false;
}

class HeadingHaloPainter extends CustomPainter {
  const HeadingHaloPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.48;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF4A90E2).withValues(alpha: 0.45),
          const Color(0xFF4A90E2).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    final path = ui.Path()
      ..moveTo(cx, cy)
      ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: r), -2 * pi / 3, pi / 3, false)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(HeadingHaloPainter oldDelegate) => false;
}
