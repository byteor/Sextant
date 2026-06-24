import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/model/discovery_source.dart';
import 'package:sextant/state/column_widths.dart';
import 'package:sextant/state/providers.dart';

void main() {
  group('ColumnWidths', () {
    test('foundVia defaults wide enough to fit every DiscoverySource icon '
        'on one line without wrapping', () {
      const widths = ColumnWidths();
      final expected = DiscoverySource.values.length * 16.0 +
          (DiscoverySource.values.length - 1) * 4.0;

      expect(widths.foundVia, expected);
    });

    test('of() reads back the right field for each column', () {
      const widths = ColumnWidths(
        ip: 1,
        name: 2,
        mac: 3,
        vendor: 4,
        foundVia: 5,
        latency: 6,
      );

      expect(widths.of(ResizableColumn.ip), 1);
      expect(widths.of(ResizableColumn.name), 2);
      expect(widths.of(ResizableColumn.mac), 3);
      expect(widths.of(ResizableColumn.vendor), 4);
      expect(widths.of(ResizableColumn.foundVia), 5);
      expect(widths.of(ResizableColumn.latency), 6);
    });

    test('resized() adjusts only the targeted column, leaving others unchanged', () {
      const widths = ColumnWidths(ip: 100, name: 200);

      final next = widths.resized(ResizableColumn.ip, 25);

      expect(next.of(ResizableColumn.ip), 125);
      expect(next.of(ResizableColumn.name), 200); // untouched
    });

    test('resized() supports negative deltas (shrinking)', () {
      const widths = ColumnWidths(mac: 150);

      final next = widths.resized(ResizableColumn.mac, -30);

      expect(next.of(ResizableColumn.mac), 120);
    });

    test('resized() clamps at kMinColumnWidth, never going below it', () {
      const widths = ColumnWidths(latency: 56);

      final next = widths.resized(ResizableColumn.latency, -1000);

      expect(next.of(ResizableColumn.latency), kMinColumnWidth);
    });
  });

  group('columnWidthsProvider', () {
    test('starts at the ColumnWidths defaults', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final widths = container.read(columnWidthsProvider);

      expect(widths.ip, const ColumnWidths().ip);
    });

    test('resize() updates the provider state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(columnWidthsProvider.notifier)
          .resize(ResizableColumn.ip, 50);

      expect(
        container.read(columnWidthsProvider).ip,
        const ColumnWidths().ip + 50,
      );
    });
  });
}
