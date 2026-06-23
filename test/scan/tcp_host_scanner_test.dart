import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/scan/tcp_host_scanner.dart';

void main() {
  group('TcpHostScanner', () {
    test('aggregates the open ports discovered for a host', () async {
      final s1 = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final s2 = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => s1.close());
      addTearDown(() => s2.close());

      // A definitely-closed port.
      final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final closedPort = closed.port;
      await closed.close();

      final scanner = TcpHostScanner(
        timeout: const Duration(seconds: 1),
      );
      final results = await scanner
          .scan(
            [InternetAddress.loopbackIPv4],
            [s1.port, closedPort, s2.port],
          )
          .toList();

      expect(results, hasLength(1));
      expect(results.single.host, InternetAddress.loopbackIPv4);
      expect(results.single.openPorts, [
        ...[s1.port, s2.port]..sort(),
      ]);
    });

    test('does not emit hosts that have no open ports', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close());

      final scanner = TcpHostScanner(
        timeout: const Duration(milliseconds: 200),
      );
      final results = await scanner.scan(
        // 192.0.2.2 is TEST-NET-1 (RFC 5737): unroutable, never responds.
        [InternetAddress('192.0.2.2'), InternetAddress.loopbackIPv4],
        [server.port],
      ).toList();

      final hosts = results.map((r) => r.host.address).toList();
      expect(hosts, contains('127.0.0.1'));
      expect(hosts, isNot(contains('192.0.2.2')));
    });

    test('reports progress as each host finishes probing', () async {
      final scanner = TcpHostScanner(
        probe: (host, port) async => false,
        concurrency: 4,
      );
      final progress = <int>[];
      int? totalSeen;

      await scanner
          .scan(
            [
              InternetAddress('192.0.2.1'),
              InternetAddress('192.0.2.2'),
              InternetAddress('192.0.2.3'),
            ],
            [80, 443],
            onHostComplete: (done, total) {
              progress.add(done);
              totalSeen = total;
            },
          )
          .drain<void>();

      expect(totalSeen, 3);
      // One callback per host, monotonically increasing to the host count.
      expect(progress, [1, 2, 3]);
    });

    test('limits the number of concurrent probes', () async {
      var active = 0;
      var maxActive = 0;
      Future<bool> trackingProbe(InternetAddress host, int port) async {
        active++;
        if (active > maxActive) maxActive = active;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        active--;
        return false;
      }

      final scanner = TcpHostScanner(probe: trackingProbe, concurrency: 4);
      await scanner
          .scan(
            [InternetAddress.loopbackIPv4],
            List.generate(20, (i) => 1000 + i),
          )
          .drain<void>();

      expect(maxActive, greaterThan(0));
      expect(maxActive, lessThanOrEqualTo(4));
    });
  });
}
