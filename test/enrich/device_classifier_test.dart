import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/enrich/device_classifier.dart';
import 'package:sextant/model/discovery_source.dart';

void main() {
  group('classifyDevice', () {
    test('the gateway is a router', () {
      expect(
        classifyDevice(openPorts: {53, 80}, isGateway: true),
        DeviceType.router,
      );
    });

    test('printer ports identify a printer', () {
      expect(classifyDevice(openPorts: {9100, 515, 631}), DeviceType.printer);
    });

    test('iOS lockdown port identifies a phone', () {
      expect(classifyDevice(openPorts: {62078}), DeviceType.phone);
    });

    test('RTSP identifies a camera', () {
      expect(classifyDevice(openPorts: {554, 80}), DeviceType.camera);
    });

    test('media ports identify a TV/streamer', () {
      expect(classifyDevice(openPorts: {8009}), DeviceType.tv);
      expect(classifyDevice(openPorts: {32400}), DeviceType.tv);
    });

    test('RDP identifies a computer', () {
      expect(classifyDevice(openPorts: {3389, 445}), DeviceType.computer);
    });

    test('hostname hints win over weak signals', () {
      expect(
        classifyDevice(openPorts: {}, hostname: 'Johns-iPhone'),
        DeviceType.phone,
      );
      expect(
        classifyDevice(openPorts: {}, hostname: 'MacBook-Pro.local'),
        DeviceType.laptop,
      );
    });

    test('vendor identifies NAS, speakers, and network gear', () {
      expect(
        classifyDevice(openPorts: {}, vendor: 'Synology Inc.'),
        DeviceType.nas,
      );
      expect(
        classifyDevice(openPorts: {}, vendor: 'Sonos, Inc.'),
        DeviceType.speaker,
      );
      expect(
        classifyDevice(openPorts: {}, vendor: 'Ubiquiti Networks'),
        DeviceType.router,
      );
    });

    test('Espressif and other embedded vendors are IoT', () {
      expect(
        classifyDevice(openPorts: {80}, vendor: 'Espressif Inc.'),
        DeviceType.iot,
      );
    });

    test('mDNS service labels classify the device', () {
      expect(
        classifyDevice(openPorts: {}, services: {'Chromecast'}),
        DeviceType.tv,
      );
      expect(
        classifyDevice(openPorts: {}, services: {'Sonos'}),
        DeviceType.speaker,
      );
      expect(
        classifyDevice(openPorts: {}, services: {'HomeKit'}),
        DeviceType.iot,
      );
    });

    test('UPnP device-type labels classify the device', () {
      expect(
        classifyDevice(openPorts: {}, services: {'Media Renderer'}),
        DeviceType.tv,
      );
      expect(
        classifyDevice(openPorts: {}, services: {'Internet Gateway'}),
        DeviceType.router,
      );
    });

    test('unknown when there are no signals', () {
      expect(classifyDevice(openPorts: {}), DeviceType.unknown);
    });
  });

  group('inferVendorFromServices', () {
    test('infers Apple from Apple-proprietary Bonjour services', () {
      expect(inferVendorFromServices({'AirPlay Audio'}), 'Apple');
      expect(inferVendorFromServices({'Apple Continuity', 'Web'}), 'Apple');
    });

    test('returns null when there is no telltale service', () {
      expect(inferVendorFromServices({'Web', 'SSH'}), isNull);
    });
  });
}
