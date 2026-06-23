import 'package:flutter/material.dart';

/// Maps [values] onto evenly-spaced points across a [width]x[height] box,
/// with the minimum value at the bottom (`dy = height`) and the maximum at
/// the top (`dy = 0`), matching screen Y-axis convention for [CustomPainter].
/// Returns an empty list when there's nothing meaningful to draw a line
/// through (fewer than 2 values).
List<Offset> sparklinePoints(
  List<double> values, {
  required double width,
  required double height,
}) {
  if (values.length < 2) return [];
  final min = values.reduce((a, b) => a < b ? a : b);
  final max = values.reduce((a, b) => a > b ? a : b);
  final range = max - min;
  final step = width / (values.length - 1);
  return [
    for (var i = 0; i < values.length; i++)
      Offset(
        i * step,
        range == 0 ? height / 2 : height - (values[i] - min) / range * height,
      ),
  ];
}

/// A minimal line-chart sparkline of recent latency readings. Renders nothing
/// when there's fewer than 2 samples (nothing to draw a trend through).
class LatencySparkline extends StatelessWidget {
  const LatencySparkline({super.key, required this.values, this.color});

  final List<double> values;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox.shrink();
    return SizedBox(
      width: 48,
      height: 16,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          color: color ?? Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final points = sparklinePoints(values, width: size.width, height: size.height);
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
