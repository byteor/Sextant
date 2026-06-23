/// The default set of TCP ports probed during a host sweep, mapped to a short
/// service label. Chosen to maximise the chance of eliciting a response from
/// common consumer, IoT, and infrastructure devices.
const Map<int, String> kWellKnownPorts = {
  21: 'FTP',
  22: 'SSH',
  23: 'Telnet',
  25: 'SMTP',
  53: 'DNS',
  80: 'HTTP',
  110: 'POP3',
  139: 'NetBIOS',
  143: 'IMAP',
  443: 'HTTPS',
  445: 'SMB',
  515: 'Printer',
  548: 'AFP',
  554: 'RTSP',
  631: 'IPP',
  993: 'IMAPS',
  995: 'POP3S',
  1883: 'MQTT',
  3000: 'HTTP-alt',
  3389: 'RDP',
  5000: 'UPnP',
  5009: 'AirPort',
  5060: 'SIP',
  5353: 'mDNS',
  5900: 'VNC',
  6379: 'Redis',
  7000: 'AirPlay',
  8000: 'HTTP-alt',
  8009: 'AirPlay',
  8080: 'HTTP-proxy',
  8443: 'HTTPS-alt',
  9000: 'HTTP-alt',
  9100: 'JetDirect',
  32400: 'Plex',
  62078: 'iOS-sync',
};

/// The ports probed by default, ascending.
List<int> get kDefaultScanPorts => kWellKnownPorts.keys.toList()..sort();
