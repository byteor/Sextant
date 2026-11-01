import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/scan/well_known_ports.dart';

void main() {
  group('mergedScanPorts', () {
    test('with no extra ports, returns exactly the default list', () {
      expect(mergedScanPorts(const []), kDefaultScanPorts);
    });

    test('adds extra ports not already in the default list', () {
      final merged = mergedScanPorts([9999]);

      expect(merged, contains(9999));
      expect(merged.length, kDefaultScanPorts.length + 1);
    });

    test('does not duplicate an extra port already in the default list', () {
      final merged = mergedScanPorts([22]); // 22 (SSH) is already default

      expect(merged.length, kDefaultScanPorts.length);
    });

    test('result is sorted ascending', () {
      final merged = mergedScanPorts([3, 65535]);

      expect(merged, orderedEquals(merged.toList()..sort()));
    });
  });
}
