import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/model/device.dart';
import 'package:sextant/ui/topology_layout.dart';

Device _dev(String ip) {
  final t = DateTime.utc(2026, 1, 1);
  return Device(ip: ip, firstSeen: t, lastSeen: t);
}

void main() {
  group('layoutRadial', () {
    test('returns no nodes for an empty device list', () {
      expect(layoutRadial([], size: const Size(200, 200)), isEmpty);
    });

    test('a single device with no gateway match sits on the ring', () {
      final device = _dev('10.0.0.5');

      final nodes = layoutRadial([device], size: const Size(200, 200));

      expect(nodes, hasLength(1));
      expect(nodes.single.isGateway, isFalse);
    });

    test('the device matching gatewayIp is centered and flagged', () {
      final gateway = _dev('10.0.0.1');
      final other = _dev('10.0.0.2');

      final nodes = layoutRadial(
        [other, gateway],
        gatewayIp: '10.0.0.1',
        size: const Size(200, 200),
      );

      final center = nodes.singleWhere((n) => n.isGateway);
      expect(center.device.ip, '10.0.0.1');
      expect(center.position, const Offset(100, 100));
    });

    test("ring devices are sorted by IP and spaced evenly starting at 12 o'clock", () {
      final gateway = _dev('10.0.0.1');
      final devices = [_dev('10.0.0.4'), _dev('10.0.0.3'), _dev('10.0.0.2'), gateway];

      final nodes = layoutRadial(devices, gatewayIp: '10.0.0.1', size: const Size(200, 200));
      final ring = nodes.where((n) => !n.isGateway).toList();

      expect(ring.map((n) => n.device.ip), ['10.0.0.2', '10.0.0.3', '10.0.0.4']);
      const radius = 100 - 24.0;
      expect(ring[0].position.dx, closeTo(100, 0.001));
      expect(ring[0].position.dy, closeTo(100 - radius, 0.001));
    });

    test('with no gateway match, all devices are placed on the ring', () {
      final devices = [_dev('10.0.0.2'), _dev('10.0.0.3')];

      final nodes = layoutRadial(devices, size: const Size(200, 200));

      expect(nodes, hasLength(2));
      expect(nodes.every((n) => !n.isGateway), isTrue);
    });
  });
}
