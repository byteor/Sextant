import 'dart:async';
import 'dart:io';

/// Parses an SSDP (HTTP-over-UDP) response into a header map with lower-cased
/// keys. Returns an empty map if it isn't an SSDP/HTTP response.
Map<String, String> parseSsdpHeaders(String response) {
  final lines = response.split(RegExp(r'\r?\n'));
  if (lines.isEmpty || !lines.first.toUpperCase().contains('HTTP/')) {
    return const {};
  }
  final headers = <String, String>{};
  for (final line in lines.skip(1)) {
    final i = line.indexOf(':');
    if (i <= 0) continue;
    headers[line.substring(0, i).trim().toLowerCase()] =
        line.substring(i + 1).trim();
  }
  return headers;
}

/// The interesting fields from a UPnP device-description document.
class UpnpDevice {
  UpnpDevice({this.friendlyName, this.manufacturer, this.modelName,
      this.deviceType});

  final String? friendlyName;
  final String? manufacturer;
  final String? modelName;
  final String? deviceType;
}

String? _tag(String xml, String tag) =>
    RegExp('<$tag>(.*?)</$tag>', dotAll: true).firstMatch(xml)?.group(1)?.trim();

/// Extracts the top-level device fields from a UPnP description XML.
UpnpDevice parseUpnpDescription(String xml) => UpnpDevice(
      friendlyName: _tag(xml, 'friendlyName'),
      manufacturer: _tag(xml, 'manufacturer'),
      modelName: _tag(xml, 'modelName'),
      deviceType: _tag(xml, 'deviceType'),
    );

/// Maps a UPnP `deviceType` URN to a friendly label, or null if unrecognised.
String? upnpDeviceTypeLabel(String? deviceType) {
  if (deviceType == null) return null;
  final t = deviceType.toLowerCase();
  if (t.contains('mediarenderer')) return 'Media Renderer';
  if (t.contains('mediaserver')) return 'Media Server';
  if (t.contains('internetgatewaydevice')) return 'Internet Gateway';
  if (t.contains('printer')) return 'Printer';
  if (t.contains('wlanaccesspoint')) return 'Access Point';
  return null;
}

/// A device discovered via SSDP/UPnP, enriched from its description document.
class SsdpObservation {
  SsdpObservation({
    required this.ip,
    this.name,
    this.manufacturer,
    this.typeLabel,
  });

  final String ip;
  final String? name;
  final String? manufacturer;
  final String? typeLabel;
}

/// Discovers UPnP devices: multicasts an SSDP M-SEARCH, then fetches each
/// responder's description document for its friendly name / manufacturer / type
/// (smart TVs, media renderers, routers, some printers). Best-effort.
class SsdpDiscovery {
  const SsdpDiscovery();

  static final InternetAddress _group = InternetAddress('239.255.255.250');

  Stream<SsdpObservation> discover({
    Duration timeout = const Duration(seconds: 3),
  }) {
    final controller = StreamController<SsdpObservation>();
    unawaited(_run(controller, timeout));
    return controller.stream;
  }

  Future<void> _run(
    StreamController<SsdpObservation> controller,
    Duration timeout,
  ) async {
    RawDatagramSocket? socket;
    final locations = <String, String>{}; // ip -> description URL
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.listen(
        (event) {
          if (event != RawSocketEvent.read) return;
          final dg = socket!.receive();
          if (dg == null) return;
          final headers = parseSsdpHeaders(String.fromCharCodes(dg.data));
          final location = headers['location'];
          if (location != null) {
            locations.putIfAbsent(dg.address.address, () => location);
          }
        },
        // Swallow async socket errors (e.g. ICMP "host down") rather than
        // letting them propagate as unhandled exceptions.
        onError: (_) {},
      );

      final msearch = 'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 2\r\n'
          'ST: ssdp:all\r\n\r\n';
      socket.send(msearch.codeUnits, _group, 1900);

      await Future<void>.delayed(timeout);
    } catch (_) {
      // SSDP unavailable: yield nothing.
    } finally {
      socket?.close();
    }

    // Fetch description documents for the responders (bounded, best-effort).
    await Future.wait(locations.entries.map((e) async {
      final device = await _fetchDescription(e.value);
      if (device == null || controller.isClosed) return;
      controller.add(SsdpObservation(
        ip: e.key,
        name: device.friendlyName,
        manufacturer: device.manufacturer,
        typeLabel: upnpDeviceTypeLabel(device.deviceType),
      ));
    }));
    if (!controller.isClosed) await controller.close();
  }

  Future<UpnpDevice?> _fetchDescription(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close().timeout(const Duration(seconds: 2));
      final body = await response
          .transform(const SystemEncoding().decoder)
          .join()
          .timeout(const Duration(seconds: 2));
      return parseUpnpDescription(body);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
