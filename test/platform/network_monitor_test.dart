import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/platform/network_monitor.dart';

void main() {
  group('interfaceSignature', () {
    test('is independent of interface and address ordering', () {
      final a = interfaceSignature(
        {
          'en0': ['192.168.1.10', 'fe80::1'],
          'en4': ['10.0.0.5'],
        },
        wifiIp: '192.168.1.10',
      );
      final b = interfaceSignature(
        {
          'en4': ['10.0.0.5'],
          'en0': ['fe80::1', '192.168.1.10'],
        },
        wifiIp: '192.168.1.10',
      );
      expect(a, b);
    });

    test('changes when an interface gains or loses an address', () {
      final before = interfaceSignature({'en0': ['192.168.1.10']});
      final after = interfaceSignature({'en0': ['192.168.1.11']});
      expect(before, isNot(after));
    });

    test('changes when an interface appears (e.g. ethernet plugged in)', () {
      final before = interfaceSignature({'en0': ['192.168.1.10']});
      final after = interfaceSignature({
        'en0': ['192.168.1.10'],
        'en4': ['10.0.0.5'],
      });
      expect(before, isNot(after));
    });

    test('changes when Wi-Fi joins a new network on the same interface', () {
      // Same interface/IP set can stay; the Wi-Fi IP moving still counts.
      final before = interfaceSignature({'en0': ['192.168.1.10']},
          wifiIp: '192.168.1.10');
      final after = interfaceSignature({'en0': ['10.0.0.7']},
          wifiIp: '10.0.0.7');
      expect(before, isNot(after));
    });

    test('is stable for an unchanged network', () {
      final a = interfaceSignature({'en0': ['192.168.1.10']},
          wifiIp: '192.168.1.10');
      final b = interfaceSignature({'en0': ['192.168.1.10']},
          wifiIp: '192.168.1.10');
      expect(a, b);
    });
  });

  group('NetworkMonitor.changes', () {
    test('emits a distinct, increasing value per real change', () async {
      // Each trigger causes a signature re-read; we only emit on a real change.
      // connectivity_plus events can fire without the network truly changing
      // (and can miss same-adapter SSID swaps), so dedup against the signature.
      // Signatures read: initial 'A', then one per trigger.
      // Emissions MUST be distinct: a StreamProvider<void> would collapse
      // identical events (AsyncData(null) == AsyncData(null)), so ref.listen
      // would fire only on the first change and never again. Emitting an
      // increasing counter keeps every change observable downstream.
      final sigs = ['A', 'A', 'B', 'B', 'C'];
      var i = 0;

      final events = await NetworkMonitor()
          .changes(
            triggers: Stream<void>.fromIterable([null, null, null, null]),
            signatureReader: () async => sigs[i++],
          )
          .toList();

      // A->A (no), A->B (emit 1), B->B (no), B->C (emit 2).
      expect(events, [1, 2]);
    });
  });
}
