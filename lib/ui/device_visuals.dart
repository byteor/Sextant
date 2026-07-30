import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
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

String discoverySourceLabel(AppLocalizations l10n, DiscoverySource source) {
  switch (source) {
    case DiscoverySource.tcp:
      return l10n.sourceTcp;
    case DiscoverySource.icmp:
      return l10n.sourceIcmp;
    case DiscoverySource.arp:
      return l10n.sourceArp;
    case DiscoverySource.mdns:
      return l10n.sourceMdns;
    case DiscoverySource.bonjour:
      return l10n.sourceBonjour;
    case DiscoverySource.netbios:
      return l10n.sourceNetbios;
    case DiscoverySource.ssdp:
      return l10n.sourceSsdp;
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
String deviceTypeLabel(AppLocalizations l10n, DeviceType type) {
  switch (type) {
    case DeviceType.router:
      return l10n.typeRouter;
    case DeviceType.computer:
      return l10n.typeComputer;
    case DeviceType.laptop:
      return l10n.typeLaptop;
    case DeviceType.phone:
      return l10n.typePhone;
    case DeviceType.tablet:
      return l10n.typeTablet;
    case DeviceType.printer:
      return l10n.typePrinter;
    case DeviceType.tv:
      return l10n.typeTv;
    case DeviceType.speaker:
      return l10n.typeSpeaker;
    case DeviceType.camera:
      return l10n.typeCamera;
    case DeviceType.nas:
      return l10n.typeNas;
    case DeviceType.server:
      return l10n.typeServer;
    case DeviceType.iot:
      return l10n.typeIot;
    case DeviceType.unknown:
      return l10n.typeUnknown;
  }
}

/// The icon for a device, from its classified type.
IconData deviceIcon(Device device) => deviceTypeIcon(device.deviceType);
