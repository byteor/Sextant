import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/model/scan_protocol.dart';

void main() {
  test('every protocol has a non-empty label', () {
    for (final p in ScanProtocol.values) {
      expect(p.label, isNotEmpty);
    }
  });

  test('icmp and arp report availability per the desktop platform gate', () {
    // This test runs on the host platform (desktop in CI/dev), so both
    // should report available there.
    expect(ScanProtocol.icmp.isAvailableOnThisPlatform, isTrue);
    expect(ScanProtocol.arp.isAvailableOnThisPlatform, isTrue);
  });

  test('tcp, mdns, netbios, and ssdp are always available', () {
    expect(ScanProtocol.tcp.isAvailableOnThisPlatform, isTrue);
    expect(ScanProtocol.mdns.isAvailableOnThisPlatform, isTrue);
    expect(ScanProtocol.netbios.isAvailableOnThisPlatform, isTrue);
    expect(ScanProtocol.ssdp.isAvailableOnThisPlatform, isTrue);
  });
}
