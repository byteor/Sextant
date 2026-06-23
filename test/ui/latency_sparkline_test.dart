import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/ui/latency_sparkline.dart';

void main() {
  group('sparklinePoints', () {
    test('maps a single repeated value to a flat horizontal line', () {
      final points = sparklinePoints([5, 5, 5], width: 30, height: 10);

      expect(points, hasLength(3));
      expect(points.every((p) => p.dy == 5), isTrue);
      expect(points.first.dx, 0);
      expect(points.last.dx, 30);
    });

    test('maps the minimum value to the bottom and maximum to the top', () {
      final points = sparklinePoints([0, 10], width: 20, height: 10);

      expect(points.first.dy, 10);
      expect(points.last.dy, 0);
    });

    test('spaces points evenly across the width', () {
      final points = sparklinePoints([1, 2, 3, 4], width: 30, height: 10);

      expect(points.map((p) => p.dx), [0, 10, 20, 30]);
    });

    test('returns an empty list for fewer than 2 values', () {
      expect(sparklinePoints([], width: 10, height: 10), isEmpty);
      expect(sparklinePoints([5], width: 10, height: 10), isEmpty);
    });
  });

  group('LatencySparkline', () {
    testWidgets('renders nothing for fewer than 2 values', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: LatencySparkline(values: [5], color: Colors.blue),
        ),
      );

      expect(find.byType(CustomPaint), findsNothing);
    });

    testWidgets('renders a CustomPaint for 2 or more values', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: LatencySparkline(values: [5, 8, 6], color: Colors.blue),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);
    });
  });
}
