import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/scan/banner_grabber.dart';

void main() {
  group('BannerGrabber', () {
    test('reads a banner that the server sends on connect', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close());
      server.listen((socket) {
        socket.write('SSH-2.0-OpenSSH_9.6\r\n');
        socket.flush().then((_) => socket.destroy());
      });

      final banner = await const BannerGrabber()
          .grab(InternetAddress.loopbackIPv4, server.port);

      expect(banner, isNotNull);
      expect(banner, contains('OpenSSH_9.6'));
    });

    test('returns null when the port is closed', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      await server.close();

      final banner = await const BannerGrabber(
        timeout: Duration(milliseconds: 400),
      ).grab(InternetAddress.loopbackIPv4, port);

      expect(banner, isNull);
    });
  });
}
