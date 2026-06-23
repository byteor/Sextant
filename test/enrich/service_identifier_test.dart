import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/enrich/service_identifier.dart';

void main() {
  group('identifyService', () {
    test('extracts the Server header from an HTTP response', () {
      const raw = 'HTTP/1.1 200 OK\r\n'
          'Server: nginx/1.25.3\r\n'
          'Content-Type: text/html\r\n\r\n';
      expect(identifyService(80, raw), 'nginx 1.25.3');
    });

    test('parses an SSH identification string', () {
      expect(identifyService(22, 'SSH-2.0-OpenSSH_9.6\r\n'), 'OpenSSH 9.6');
    });

    test('strips the numeric reply code from an FTP banner', () {
      expect(
        identifyService(21, '220 ProFTPD Server ready\r\n'),
        'ProFTPD Server ready',
      );
    });

    test('returns the first line for an unrecognised banner', () {
      expect(
        identifyService(7777, 'WidgetCtrl v2 ready\r\nmore text'),
        'WidgetCtrl v2 ready',
      );
    });

    test('ignores an HTTP status line when there is no Server header', () {
      const raw = 'HTTP/1.0 404 Not Found\r\nContent-Length: 0\r\n\r\n';
      expect(identifyService(80, raw), isNull);
    });

    test('returns null for an empty banner', () {
      expect(identifyService(80, '   \r\n'), isNull);
      expect(identifyService(80, ''), isNull);
    });
  });
}
