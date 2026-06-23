import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/scan/tcp_probe.dart';

void main() {
  group('TcpProbe', () {
    test('returns true when a TCP port is open', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close());

      const probe = TcpProbe();
      final open = await probe.isOpen(
        InternetAddress.loopbackIPv4,
        server.port,
        timeout: const Duration(seconds: 1),
      );

      expect(open, isTrue);
    });

    test('returns false when a TCP port refuses the connection', () async {
      // Bind then immediately release the port so nothing is listening on it.
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final closedPort = server.port;
      await server.close();

      const probe = TcpProbe();
      final open = await probe.isOpen(
        InternetAddress.loopbackIPv4,
        closedPort,
        timeout: const Duration(seconds: 1),
      );

      expect(open, isFalse);
    });

    test('returns false when the connection times out', () async {
      // 192.0.2.1 is TEST-NET-1 (RFC 5737): guaranteed unroutable, so the
      // connect attempt hangs until our timeout fires.
      const probe = TcpProbe();
      final open = await probe.isOpen(
        InternetAddress('192.0.2.1'),
        80,
        timeout: const Duration(milliseconds: 200),
      );

      expect(open, isFalse);
    });
  });
}
