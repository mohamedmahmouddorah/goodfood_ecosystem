import 'package:flutter/material.dart';

class ChefHatIcon extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const ChefHatIcon({
    super.key,
    this.size = 26.0,
    required this.color,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ChefHatPainter(
          color: color,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _ChefHatPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _ChefHatPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Base band coordinates
    final bandLeft = w * 0.24;
    final bandRight = w * 0.76;
    final bandTop = h * 0.72;
    final bandBottom = h * 0.94;
    final radius = Radius.circular(h * 0.05);

    // Draw the bottom headband
    final bandRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(bandLeft, bandTop, bandRight, bandBottom),
      radius,
    );
    canvas.drawRRect(bandRect, paint);

    // Inner horizontal detail line in the headband
    final bandMidY = (bandTop + bandBottom) / 2;
    canvas.drawLine(
      Offset(bandLeft + w * 0.08, bandMidY),
      Offset(bandRight - w * 0.08, bandMidY),
      paint..strokeWidth = strokeWidth * 0.8,
    );

    // Reset stroke width
    paint.strokeWidth = strokeWidth;

    // Draw the billowing toque puffs
    final puffPath = Path();
    puffPath.moveTo(bandLeft + w * 0.02, bandTop);

    // Left puff out and up
    puffPath.cubicTo(
      w * 0.04,
      bandTop - h * 0.18,
      w * 0.06,
      h * 0.28,
      w * 0.27,
      h * 0.22,
    );

    // Center tall puff
    puffPath.cubicTo(
      w * 0.35,
      h * 0.06,
      w * 0.65,
      h * 0.06,
      w * 0.73,
      h * 0.22,
    );

    // Right puff out and down
    puffPath.cubicTo(
      w * 0.94,
      h * 0.28,
      w * 0.96,
      bandTop - h * 0.18,
      bandRight - w * 0.02,
      bandTop,
    );

    canvas.drawPath(puffPath, paint);

    // Vertical subtle pleat lines
    final pleatPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.75
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(w * 0.40, h * 0.68),
      Offset(w * 0.38, h * 0.40),
      pleatPaint,
    );

    canvas.drawLine(
      Offset(w * 0.50, h * 0.68),
      Offset(w * 0.50, h * 0.32),
      pleatPaint,
    );

    canvas.drawLine(
      Offset(w * 0.60, h * 0.68),
      Offset(w * 0.62, h * 0.40),
      pleatPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ChefHatPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
