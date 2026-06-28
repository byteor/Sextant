import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/model/device.dart';
import 'package:sextant/state/column_widths.dart';
import 'package:sextant/state/providers.dart';
import 'package:sextant/state/scan_state.dart';
import 'package:sextant/ui/scan_screen.dart';

class _FixedScanController extends ScanController {
  _FixedScanController(this._state);
  final ScanState _state;

  @override
  ScanState build() => _state;
}

Device _dev(String ip) {
  final t = DateTime.utc(2026, 1, 1);
  return Device(ip: ip, firstSeen: t, lastSeen: t);
}

Future<void> _pump(WidgetTester tester, List<Device> devices) async {
  // The device table's fixed-width columns (plus the toolbar) need more
  // horizontal space than flutter_test's default 800x600 surface, which
  // would otherwise overflow the Row before this test gets to interact with
  // it. This only widens the *test* surface — production layout is
  // unaffected.
  await tester.binding.setSurfaceSize(const Size(1400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        scanControllerProvider
            .overrideWith(() => _FixedScanController(ScanState(devices: devices))),
        networksProvider.overrideWith((ref) async => []),
      ],
      child: const MaterialApp(home: ScanScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('there is no "Network map" button in the toolbar', (tester) async {
    await _pump(tester, []);

    expect(find.byTooltip('Network map'), findsNothing);
  });

  testWidgets('dragging the IP column resize handle widens it and narrows '
      'the Open ports filler correspondingly', (tester) async {
    await _pump(tester, [_dev('10.0.0.1')]);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ScanScreen)),
    );
    final before = container.read(columnWidthsProvider).ip;

    final handle = find.byWidgetPredicate(
      (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
    );
    expect(handle, findsWidgets);

    await tester.drag(handle.first, const Offset(30, 0));
    await tester.pump();

    expect(container.read(columnWidthsProvider).ip, before + 30);
  });

  testWidgets('shrinking the IP column to its minimum ellipsizes the IP '
      'text instead of overflowing', (tester) async {
    await _pump(tester, [_dev('192.168.6.225')]);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ScanScreen)),
    );
    container
        .read(columnWidthsProvider.notifier)
        .resize(ResizableColumn.ip, -1000);
    await tester.pump();

    expect(container.read(columnWidthsProvider).ip, kMinColumnWidth);
    expect(tester.takeException(), isNull);
  });
}
