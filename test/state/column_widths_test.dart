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
      final expected =
          DiscoverySource.values.length * 16.0 +
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

    test(
      'resized() adjusts only the targeted column, leaving others unchanged',
      () {
        const widths = ColumnWidths(ip: 100, name: 200);

        final next = widths.resized(ResizableColumn.ip, 25);

        expect(next.of(ResizableColumn.ip), 125);
        expect(next.of(ResizableColumn.name), 200); // untouched
      },
    );

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

    test('defaults keep the device table within the app\'s minimum window '
        'width', () {
      // main.dart's WindowOptions.minimumSize is Size(820, 520) — the
      // smallest window a user can resize this app down to. The device
      // table (lib/ui/scan_screen.dart) falls back to horizontal scrolling
      // once columns can't shrink any further (see EffectiveColumnWidths),
      // but the defaults should still fit the minimum window without ever
      // triggering that fallback: the icon column, the 6 resizable columns,
      // a resize-handle gap after each of those 6, and the table's 24px
      // horizontal padding must fit within it.
      // Mirrors scan_screen.dart's _kIconWidth/_kHandleWidth; a deliberate,
      // commented duplication rather than importing a private constant.
      const minimumWindowWidth = 820.0;
      const iconWidth = 40.0;
      const handleWidth = 8.0;
      const resizableColumnCount = 6;
      const tablePadding = 24.0;

      const widths = ColumnWidths();
      final tableWidth =
          iconWidth +
          widths.ip +
          widths.name +
          widths.mac +
          widths.vendor +
          widths.foundVia +
          widths.latency +
          resizableColumnCount * handleWidth +
          tablePadding;

      expect(tableWidth, lessThanOrEqualTo(minimumWindowWidth));
    });
  });

  group('EffectiveColumnWidths.compute', () {
    const preferred = ColumnWidths(
      ip: 120,
      name: 140,
      mac: 130,
      vendor: 110,
      foundVia: 136,
      latency: 52,
    );
    const minWidths = (
      ip: 60.0,
      name: 50.0,
      mac: 30.0,
      vendor: 40.0,
      openPorts: 80.0,
      foundVia: 90.0,
      latency: 45.0,
    );

    test('plenty of room: six columns keep their preferred widths, Open '
        'ports absorbs the rest', () {
      final result = EffectiveColumnWidths.compute(
        preferred: preferred,
        minWidths: minWidths,
        availableWidth: 1000,
      );

      expect(result.ip, preferred.ip);
      expect(result.name, preferred.name);
      expect(result.mac, preferred.mac);
      expect(result.vendor, preferred.vendor);
      expect(result.foundVia, preferred.foundVia);
      expect(result.latency, preferred.latency);
      expect(result.openPorts, 1000 - 688); // 1000 - sum of the six
      expect(result.overflows, isFalse);
    });

    test('tight room: six columns shrink proportionally, Open ports gets '
        'exactly its minimum', () {
      // Sum of the six preferred widths is 688; minimum sum is 315. Pick an
      // available width in between so every column has some slack to give.
      final result = EffectiveColumnWidths.compute(
        preferred: preferred,
        minWidths: minWidths,
        availableWidth: 600, // 600 - 80 (openPorts min) = 520 for the six
      );

      expect(result.openPorts, minWidths.openPorts);
      expect(
        result.ip +
            result.name +
            result.mac +
            result.vendor +
            result.foundVia +
            result.latency,
        closeTo(520, 0.01),
      );
      // Every column stays within [min, preferred] — none shrinks past its
      // header-label floor, none grows past what the user set.
      expect(result.ip, inInclusiveRange(minWidths.ip, preferred.ip));
      expect(result.name, inInclusiveRange(minWidths.name, preferred.name));
      expect(result.overflows, isFalse);
    });

    test('too narrow even at every minimum: stops shrinking and reports '
        'overflow', () {
      final result = EffectiveColumnWidths.compute(
        preferred: preferred,
        minWidths: minWidths,
        availableWidth: 200, // well below the 315+80=395 minimum sum
      );

      expect(result.ip, minWidths.ip);
      expect(result.name, minWidths.name);
      expect(result.mac, minWidths.mac);
      expect(result.vendor, minWidths.vendor);
      expect(result.foundVia, minWidths.foundVia);
      expect(result.latency, minWidths.latency);
      expect(result.openPorts, minWidths.openPorts);
      expect(result.overflows, isTrue);
      expect(result.naturalWidth, 395); // sum of all seven minimums
    });

    test('a column manually dragged below its header-label minimum keeps '
        'its preferred width instead of being forced back up', () {
      // ip's preferred width (120) is well above its header minimum (60),
      // but suppose the user dragged mac down to 20 — narrower than its own
      // 30px minimum. That's an explicit choice; shrinking shouldn't treat
      // mac as having slack to give, nor should it inflate mac back to 30.
      const draggedPreferred = ColumnWidths(
        ip: 120,
        name: 140,
        mac: 20,
        vendor: 110,
        foundVia: 136,
        latency: 52,
      );

      final result = EffectiveColumnWidths.compute(
        preferred: draggedPreferred,
        minWidths: minWidths,
        availableWidth: 400,
      );

      expect(result.mac, 20);
      expect(result.overflows, isFalse);
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
