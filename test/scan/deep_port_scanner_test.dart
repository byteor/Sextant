import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/scan/deep_port_scanner.dart';
import 'package:sextant/scan/tcp_host_scanner.dart';

void main() {
  group('kAllTcpPorts', () {
    test('covers every TCP port, 1 through 65535', () {
      expect(kAllTcpPorts, hasLength(65535));
      expect(kAllTcpPorts.first, 1);
      expect(kAllTcpPorts.last, 65535);
    });
  });

  group('DeepPortScanner', () {
    test('finds an actually-open loopback port among the full range', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close());

      final scanner = DeepPortScanner(
        scanner: TcpHostScanner(
          concurrency: 128,
          timeout: const Duration(milliseconds: 200),
        ),
      );
      final found = await scanner.scan(InternetAddress.loopbackIPv4);

      expect(found, contains(server.port));
    });

    test('reports progress via onProgress as probes complete', () async {
      final scanner = DeepPortScanner(
        scanner: TcpHostScanner(
          probe: (host, port) async => false,
          concurrency: 64,
        ),
      );
      var lastDone = 0;
      int? lastTotal;

      await scanner.scan(
        InternetAddress.loopbackIPv4,
        onProgress: (done, total) {
          lastDone = done;
          lastTotal = total;
        },
      );

      expect(lastTotal, 65535);
      expect(lastDone, 65535);
    });

    test('returns an empty list for a cancelled scan', () async {
      final scanner = DeepPortScanner(
        scanner: TcpHostScanner(
          probe: (host, port) async => true, // would otherwise find lots
          concurrency: 4,
        ),
      );

      final found = await scanner.scan(
        InternetAddress.loopbackIPv4,
        isCancelled: () => true,
      );

      expect(found, isEmpty);
    });
  });
}
