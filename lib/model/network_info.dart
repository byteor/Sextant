import 'dart:io';

import '../scan/ipv4_subnet.dart';

/// How a network interface is physically connected.
enum LinkType { wifi, wired, other }

/// An active local network the user can scan, derived from a network interface.
class ScanNetwork {
  ScanNetwork({
    required this.interfaceName,
    required this.displayName,
    required this.address,
    required this.subnet,
    this.gateway,
    this.linkType = LinkType.other,
  });

  final String interfaceName;

  /// A human label: the Wi-Fi SSID when known, else the interface name.
  final String displayName;
  final InternetAddress address;
  final Ipv4Subnet subnet;
  final InternetAddress? gateway;
  final LinkType linkType;

  /// A stable identifier for this network, used to key persisted devices and
  /// scan history. Based on the subnet + interface so it survives DHCP lease
  /// changes within the same network.
  String get id =>
      '${interfaceName}_${subnet.networkAddress.address}/${subnet.prefixLength}';

  bool get isWireless => linkType == LinkType.wifi;
}
