import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/data/device_serialization.dart';
import 'package:sextant/model/device.dart';
import 'package:sextant/model/discovery_source.dart';

void main() {
  group('device serialization', () {
    test('round-trips a fully-populated device through a JSON-safe map', () {
      final device = Device(
        ip: '192.168.1.42',
        mac: 'd8:3b:da:a3:d3:d8',
        vendor: 'LEXMARK INTERNATIONAL, INC.',
        hostname: 'office-printer.local',
        customName: 'Front desk printer',
        deviceType: DeviceType.printer,
        openPorts: [80, 443, 9100],
        services: {80: 'nginx', 9100: 'JetDirect'},
        discoveredBy: {DiscoverySource.arp, DiscoverySource.mdns},
        firstSeen: DateTime.utc(2026, 6, 20, 9, 30),
        lastSeen: DateTime.utc(2026, 6, 22, 17, 5),
        networkId: 'net-abc',
        isOnline: false,
        latencyMs: 12.5,
      );

      final restored = deviceFromMap(deviceToMap(device));

      expect(restored.ip, device.ip);
      expect(restored.mac, device.mac);
      expect(restored.vendor, device.vendor);
      expect(restored.hostname, device.hostname);
      expect(restored.customName, device.customName);
      expect(restored.deviceType, DeviceType.printer);
      expect(restored.openPorts, [80, 443, 9100]);
      expect(restored.services, {80: 'nginx', 9100: 'JetDirect'});
      expect(restored.discoveredBy,
          {DiscoverySource.arp, DiscoverySource.mdns});
      expect(restored.firstSeen, device.firstSeen);
      expect(restored.lastSeen, device.lastSeen);
      expect(restored.networkId, 'net-abc');
      expect(restored.isOnline, false);
      expect(restored.latencyMs, 12.5);
    });

    test('round-trips a minimal device with null/empty fields', () {
      final device = Device(
        ip: '10.0.0.1',
        firstSeen: DateTime.utc(2026, 1, 1),
        lastSeen: DateTime.utc(2026, 1, 1),
      );

      final restored = deviceFromMap(deviceToMap(device));

      expect(restored.ip, '10.0.0.1');
      expect(restored.mac, isNull);
      expect(restored.vendor, isNull);
      expect(restored.hostname, isNull);
      expect(restored.customName, isNull);
      expect(restored.deviceType, DeviceType.unknown);
      expect(restored.openPorts, isEmpty);
      expect(restored.services, isEmpty);
      expect(restored.discoveredBy, isEmpty);
      expect(restored.networkId, isNull);
      expect(restored.isOnline, true);
      expect(restored.latencyMs, isNull);
    });

    test('decodes an unrecognised device type as unknown', () {
      final map = deviceToMap(Device(
        ip: '10.0.0.2',
        firstSeen: DateTime.utc(2026, 1, 1),
        lastSeen: DateTime.utc(2026, 1, 1),
      ));
      map['deviceType'] = 'toaster';

      expect(deviceFromMap(map).deviceType, DeviceType.unknown);
    });

    test('ignores an unrecognised discovery source', () {
      final map = deviceToMap(Device(
        ip: '10.0.0.3',
        discoveredBy: {DiscoverySource.tcp},
        firstSeen: DateTime.utc(2026, 1, 1),
        lastSeen: DateTime.utc(2026, 1, 1),
      ));
      (map['discoveredBy'] as List).add('carrier-pigeon');

      expect(deviceFromMap(map).discoveredBy, {DiscoverySource.tcp});
    });
  });
}
