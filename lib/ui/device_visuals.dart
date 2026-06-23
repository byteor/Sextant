import 'package:flutter/material.dart';

import '../model/device.dart';
import '../model/discovery_source.dart';

/// A small icon representing the discovery protocol, shown as a "discovered-by"
/// chip on each device row.
IconData discoverySourceIcon(DiscoverySource source) {
  switch (source) {
    case DiscoverySource.tcp:
      return Icons.lan_outlined;
    case DiscoverySource.icmp:
      return Icons.network_ping;
    case DiscoverySource.arp:
      return Icons.memory;
    case DiscoverySource.mdns:
    case DiscoverySource.bonjour:
      return Icons.travel_explore;
    case DiscoverySource.netbios:
      return Icons.dns_outlined;
    case DiscoverySource.ssdp:
      return Icons.cast_connected;
  }
}

String discoverySourceLabel(DiscoverySource source) {
  switch (source) {
    case DiscoverySource.tcp:
      return 'TCP';
    case DiscoverySource.icmp:
      return 'ICMP';
    case DiscoverySource.arp:
      return 'ARP';
    case DiscoverySource.mdns:
      return 'mDNS';
    case DiscoverySource.bonjour:
      return 'Bonjour';
    case DiscoverySource.netbios:
      return 'NetBIOS';
    case DiscoverySource.ssdp:
      return 'SSDP';
  }
}

/// The icon for a classified [DeviceType].
IconData deviceTypeIcon(DeviceType type) {
  switch (type) {
    case DeviceType.router:
      return Icons.router;
    case DeviceType.computer:
      return Icons.computer;
    case DeviceType.laptop:
      return Icons.laptop;
    case DeviceType.phone:
      return Icons.smartphone;
    case DeviceType.tablet:
      return Icons.tablet;
    case DeviceType.printer:
      return Icons.print;
    case DeviceType.tv:
      return Icons.tv;
    case DeviceType.speaker:
      return Icons.speaker;
    case DeviceType.camera:
      return Icons.videocam;
    case DeviceType.nas:
      return Icons.storage;
    case DeviceType.server:
      return Icons.dns;
    case DeviceType.iot:
      return Icons.lightbulb_outline;
    case DeviceType.unknown:
      return Icons.device_unknown;
  }
}

/// A human-readable label for a [DeviceType], shown in tooltips and the
/// change-type menu.
String deviceTypeLabel(DeviceType type) {
  switch (type) {
    case DeviceType.router:
      return 'Router';
    case DeviceType.computer:
      return 'Computer';
    case DeviceType.laptop:
      return 'Laptop';
    case DeviceType.phone:
      return 'Phone';
    case DeviceType.tablet:
      return 'Tablet';
    case DeviceType.printer:
      return 'Printer';
    case DeviceType.tv:
      return 'TV';
    case DeviceType.speaker:
      return 'Speaker';
    case DeviceType.camera:
      return 'Camera';
    case DeviceType.nas:
      return 'NAS';
    case DeviceType.server:
      return 'Server';
    case DeviceType.iot:
      return 'IoT';
    case DeviceType.unknown:
      return 'Unknown';
  }
}

/// The icon for a device, from its classified type.
IconData deviceIcon(Device device) => deviceTypeIcon(device.deviceType);
