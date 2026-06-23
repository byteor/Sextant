import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/scan/ssdp_discovery.dart';

void main() {
  group('parseSsdpHeaders', () {
    test('parses an M-SEARCH response into a lower-cased header map', () {
      const resp = 'HTTP/1.1 200 OK\r\n'
          'CACHE-CONTROL: max-age=1800\r\n'
          'LOCATION: http://192.168.4.1:5000/rootDesc.xml\r\n'
          'SERVER: Linux/3.4 UPnP/1.0\r\n'
          'ST: upnp:rootdevice\r\n\r\n';
      final h = parseSsdpHeaders(resp);

      expect(h['location'], 'http://192.168.4.1:5000/rootDesc.xml');
      expect(h['server'], 'Linux/3.4 UPnP/1.0');
      expect(h['st'], 'upnp:rootdevice');
    });

    test('returns an empty map for a non-SSDP payload', () {
      expect(parseSsdpHeaders('garbage'), isEmpty);
    });
  });

  group('parseUpnpDescription', () {
    test('extracts friendly name, manufacturer, model and type', () {
      const xml = '<?xml version="1.0"?><root><device>'
          '<friendlyName>Living Room TV</friendlyName>'
          '<manufacturer>Samsung Electronics</manufacturer>'
          '<modelName>UE55</modelName>'
          '<deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>'
          '</device></root>';
      final d = parseUpnpDescription(xml);

      expect(d.friendlyName, 'Living Room TV');
      expect(d.manufacturer, 'Samsung Electronics');
      expect(d.modelName, 'UE55');
      expect(upnpDeviceTypeLabel(d.deviceType), 'Media Renderer');
    });

    test('returns nulls when fields are absent', () {
      final d = parseUpnpDescription('<root></root>');
      expect(d.friendlyName, isNull);
      expect(d.manufacturer, isNull);
    });
  });
}
