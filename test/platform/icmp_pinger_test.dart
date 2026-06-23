import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/platform/icmp_pinger.dart';

void main() {
  group('buildPingArgs', () {
    test('Windows uses -n count and -w milliseconds', () {
      expect(
        buildPingArgs('10.0.0.1',
            isWindows: true, isMacOS: false, timeoutMs: 1000),
        ['-n', '1', '-w', '1000', '10.0.0.1'],
      );
    });

    test('macOS uses -c count and -t timeout seconds', () {
      expect(
        buildPingArgs('10.0.0.1',
            isWindows: false, isMacOS: true, timeoutMs: 1000),
        ['-c', '1', '-t', '1', '10.0.0.1'],
      );
    });

    test('Linux uses -c count and -W timeout seconds', () {
      expect(
        buildPingArgs('10.0.0.1',
            isWindows: false, isMacOS: false, timeoutMs: 1500),
        ['-c', '1', '-W', '2', '10.0.0.1'],
      );
    });
  });

  group('parsePingRttMs', () {
    test('parses macOS/Linux "time=1.234 ms"', () {
      const output = '64 bytes from 192.168.1.1: icmp_seq=0 ttl=64 '
          'time=1.234 ms\n';
      expect(parsePingRttMs(output), 1.234);
    });

    test('parses Windows "time=1ms"', () {
      const output = 'Reply from 192.168.1.1: bytes=32 time=1ms TTL=64\n';
      expect(parsePingRttMs(output), 1.0);
    });

    test('parses Windows "time<1ms"', () {
      const output = 'Reply from 192.168.1.1: bytes=32 time<1ms TTL=64\n';
      expect(parsePingRttMs(output), 1.0);
    });

    test('returns null when there is no reply time (e.g. unreachable)', () {
      const output = 'Request timeout for icmp_seq 0\n';
      expect(parsePingRttMs(output), isNull);
    });
  });

  group('IcmpPinger (real)', () {
    test('reports loopback as alive', () async {
      final alive = await const IcmpPinger()
          .isAlive(InternetAddress.loopbackIPv4);
      expect(alive, isTrue);
    });

    test('reports an unroutable TEST-NET address as not alive', () async {
      final alive = await const IcmpPinger(
        timeout: Duration(milliseconds: 800),
      ).isAlive(InternetAddress('192.0.2.1'));
      expect(alive, isFalse);
    });
  });

  group('IcmpSweeper', () {
    test('defaults to a concurrency of 128', () {
      expect(IcmpSweeper().concurrency, 128);
    });
  });
}
