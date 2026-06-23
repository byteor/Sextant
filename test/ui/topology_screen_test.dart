import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/model/device.dart';
import 'package:sextant/model/network_info.dart';
import 'package:sextant/state/providers.dart';
import 'package:sextant/state/scan_state.dart';
import 'package:sextant/ui/topology_screen.dart';

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
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        scanControllerProvider
            .overrideWith(() => _FixedScanController(ScanState(devices: devices))),
        networksProvider.overrideWith((ref) async => <ScanNetwork>[]),
      ],
      child: const MaterialApp(home: TopologyScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('shows a placeholder when there are no devices', (tester) async {
    await _pump(tester, []);

    expect(find.text('Run a scan to see the network map.'), findsOneWidget);
  });

  testWidgets('renders one node per discovered device', (tester) async {
    await _pump(tester, [_dev('10.0.0.1'), _dev('10.0.0.2'), _dev('10.0.0.3')]);

    expect(find.byType(CircleAvatar), findsNWidgets(3));
  });

  testWidgets('tapping a node opens a detail dialog', (tester) async {
    await _pump(tester, [_dev('10.0.0.1')]);

    await tester.tap(find.byType(CircleAvatar));
    await tester.pumpAndSettle();

    expect(find.text('IP: 10.0.0.1'), findsOneWidget);
  });
}
