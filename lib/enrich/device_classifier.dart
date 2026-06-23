import '../model/discovery_source.dart';

/// Best-effort device-type classification from the signals gathered during a
/// scan. Signals are weighed in priority order: an explicit gateway, then
/// hostname hints (usually the most reliable), then characteristic open ports,
/// then the MAC vendor. Returns [DeviceType.unknown] when nothing matches.
///
/// This is intentionally a pure function so it can be re-run cheaply as new
/// signals (ports, hostname, vendor) stream in for a device.
DeviceType classifyDevice({
  required Set<int> openPorts,
  String? vendor,
  String? hostname,
  Set<String> services = const {},
  bool isGateway = false,
}) {
  if (isGateway) return DeviceType.router;

  final fromHostname = _fromHostname(hostname);
  if (fromHostname != null) return fromHostname;

  final fromServices = _fromServices(services);
  if (fromServices != null) return fromServices;

  final fromPorts = _fromPorts(openPorts);
  if (fromPorts != null) return fromPorts;

  final fromVendor = _fromVendor(vendor);
  if (fromVendor != null) return fromVendor;

  return DeviceType.unknown;
}

/// Apple-proprietary Bonjour services that reliably indicate an Apple device,
/// even when the MAC is randomized (so OUI lookup can't see it's Apple).
const _appleServices = {'AirPlay', 'AirPlay Audio', 'Apple Continuity'};

/// Infers a manufacturer from mDNS/Bonjour service labels when the MAC is a
/// randomized/private address that no OUI database can resolve.
String? inferVendorFromServices(Set<String> services) {
  if (services.any(_appleServices.contains)) return 'Apple';
  if (services.contains('Sonos')) return 'Sonos, Inc.';
  if (services.contains('Chromecast')) return 'Google, Inc.';
  return null;
}

DeviceType? _fromServices(Set<String> services) {
  if (services.contains('Chromecast') ||
      services.contains('AirPlay') ||
      services.contains('Media Renderer')) {
    return DeviceType.tv;
  }
  if (services.contains('Sonos') ||
      services.contains('Spotify') ||
      services.contains('AirPlay Audio')) {
    return DeviceType.speaker;
  }
  if (services.contains('Printer') || services.contains('Scanner')) {
    return DeviceType.printer;
  }
  if (services.contains('Internet Gateway') ||
      services.contains('Access Point')) {
    return DeviceType.router;
  }
  if (services.contains('Media Server')) return DeviceType.nas;
  if (services.contains('HomeKit')) return DeviceType.iot;
  return null;
}

DeviceType? _fromHostname(String? hostname) {
  if (hostname == null) return null;
  final h = hostname.toLowerCase();
  if (h.contains('iphone')) return DeviceType.phone;
  if (h.contains('ipad')) return DeviceType.tablet;
  if (h.contains('macbook')) return DeviceType.laptop;
  if (h.contains('imac') || h.contains('macmini') || h.contains('mac-mini')) {
    return DeviceType.computer;
  }
  if (h.contains('appletv') || h.contains('apple-tv') || h.contains('-tv')) {
    return DeviceType.tv;
  }
  if (h.contains('printer')) return DeviceType.printer;
  if (h.contains('camera') || h.contains('cam-')) return DeviceType.camera;
  if (h.contains('router') || h.contains('gateway') || h.contains('eero')) {
    return DeviceType.router;
  }
  if (h.contains('nas') || h.contains('synology') || h.contains('qnap')) {
    return DeviceType.nas;
  }
  return null;
}

DeviceType? _fromPorts(Set<int> ports) {
  if (ports.intersection({515, 631, 9100}).isNotEmpty) return DeviceType.printer;
  if (ports.contains(62078)) return DeviceType.phone;
  if (ports.intersection({7000, 8009, 32400}).isNotEmpty) return DeviceType.tv;
  if (ports.contains(554)) return DeviceType.camera;
  if (ports.contains(3389)) return DeviceType.computer;
  if (ports.contains(5009)) return DeviceType.router;
  return null;
}

DeviceType? _fromVendor(String? vendor) {
  if (vendor == null) return null;
  final v = vendor.toLowerCase();
  if (v.contains('synology') || v.contains('qnap')) return DeviceType.nas;
  if (v.contains('sonos')) return DeviceType.speaker;
  if (v.contains('philips hue') || v.contains('nest') || v.contains('hue')) {
    return DeviceType.iot;
  }
  if (v.contains('ubiquiti') ||
      v.contains('cisco') ||
      v.contains('netgear') ||
      v.contains('tp-link') ||
      v.contains('d-link') ||
      v.contains('eero')) {
    return DeviceType.router;
  }
  // Common embedded / IoT silicon and smart-home vendors.
  if (v.contains('raspberry') ||
      v.contains('espressif') ||
      v.contains('tuya') ||
      v.contains('shelly') ||
      v.contains('sonoff') ||
      v.contains('itead') ||
      v.contains('rachio') ||
      v.contains('ecobee') ||
      v.contains('tplink') ||
      v.contains('ring') ||
      v.contains('wyze')) {
    return DeviceType.iot;
  }
  return null;
}
