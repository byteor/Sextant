import 'dart:async';
import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';

/// Common Bonjour/mDNS service types mapped to friendly labels.
const Map<String, String> _serviceLabels = {
  '_airplay._tcp': 'AirPlay',
  '_raop._tcp': 'AirPlay Audio',
  '_googlecast._tcp': 'Chromecast',
  '_ipp._tcp': 'Printer',
  '_ipps._tcp': 'Printer',
  '_printer._tcp': 'Printer',
  '_pdl-datastream._tcp': 'Printer',
  '_scanner._tcp': 'Scanner',
  '_http._tcp': 'Web',
  '_ssh._tcp': 'SSH',
  '_sftp-ssh._tcp': 'SSH',
  '_smb._tcp': 'File Sharing (SMB)',
  '_afpovertcp._tcp': 'File Sharing (AFP)',
  '_nfs._tcp': 'File Sharing (NFS)',
  '_homekit._tcp': 'HomeKit',
  '_hap._tcp': 'HomeKit',
  '_spotify-connect._tcp': 'Spotify',
  '_sonos._tcp': 'Sonos',
  '_companion-link._tcp': 'Apple Continuity',
  '_device-info._tcp': 'Device Info',
  '_workstation._tcp': 'Workstation',
  '_amzn-wplay._tcp': 'Amazon',
};

/// The service types queried during discovery.
List<String> get mdnsServiceTypes =>
    _serviceLabels.keys.map((s) => '$s.local').toList();

/// Maps an mDNS service type (e.g. `_airplay._tcp`, with or without a trailing
/// `.local`) to a friendly label, or null if unrecognised.
String? mdnsServiceLabel(String serviceType) {
  var s = serviceType;
  if (s.endsWith('.local')) s = s.substring(0, s.length - 6);
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return _serviceLabels[s];
}

final _instance = RegExp(
  r'^(.*)\._[a-z0-9-]+\._(?:tcp|udp)\.local\.?$',
  caseSensitive: false,
);

/// Extracts and unescapes the friendly instance label from a DNS-SD PTR name
/// (e.g. `Living Room._airplay._tcp.local` -> `Living Room`). Returns the input
/// unchanged if it carries no recognisable service suffix.
String mdnsInstanceName(String fullName) {
  final match = _instance.firstMatch(fullName);
  final raw = match != null ? match.group(1)! : fullName;
  return raw.replaceAll(r'\032', ' ').replaceAll(r'\.', '.').trim();
}

/// Derives the MAC address embedded in an EUI-64 IPv6 link-local address
/// (`fe80::xxxx:xxff:fexx:xxxx`), or null for any other address. Devices that
/// use randomised "privacy" interface IDs carry no MAC and yield null.
String? macFromEui64LinkLocal(InternetAddress address) {
  if (address.type != InternetAddressType.IPv6) return null;
  final b = address.rawAddress;
  if (b.length != 16 || b[0] != 0xfe || (b[1] & 0xc0) != 0x80) return null;
  if (b[11] != 0xff || b[12] != 0xfe) return null;
  final mac = [b[8] ^ 0x02, b[9], b[10], b[13], b[14], b[15]];
  return mac.map((x) => x.toRadixString(16).padLeft(2, '0')).join(':');
}

/// A device announced over mDNS/Bonjour: its IP, friendly name, and the service
/// (with its port) that revealed it. [mac] is set on a follow-up observation
/// when the device also announced an EUI-64 IPv6 link-local address.
class MdnsObservation {
  MdnsObservation({
    required this.ip,
    required this.name,
    required this.port,
    required this.serviceLabel,
    this.mac,
  });

  final String ip;
  final String? mac;
  final String name;
  final int port;
  final String serviceLabel;
}

/// Discovers devices that announce themselves via mDNS/Bonjour — the way most
/// Apple, Chromecast, printer, and IoT devices expose a friendly name even when
/// they have no reverse-DNS record. Best-effort: any failure yields no results
/// rather than breaking the scan.
class MdnsDiscovery {
  const MdnsDiscovery();

  Stream<MdnsObservation> discover({
    Duration timeout = const Duration(seconds: 4),
  }) {
    final controller = StreamController<MdnsObservation>();
    unawaited(_run(controller, timeout));
    return controller.stream;
  }

  Future<void> _run(
    StreamController<MdnsObservation> controller,
    Duration timeout,
  ) async {
    final client = MDnsClient();
    final seen = <String>{};
    try {
      await client.start();
      await Future.wait(
        _serviceLabels.entries.map(
          (entry) => _queryService(
            client,
            entry.key,
            entry.value,
            controller,
            seen,
            timeout,
          ).catchError((_) {}),
        ),
      ).timeout(
        timeout + const Duration(seconds: 1),
        onTimeout: () => const [],
      );
    } catch (_) {
      // mDNS unavailable (permissions, no multicast): yield nothing.
    } finally {
      client.stop();
      if (!controller.isClosed) await controller.close();
    }
  }

  Future<void> _queryService(
    MDnsClient client,
    String serviceType,
    String label,
    StreamController<MdnsObservation> controller,
    Set<String> seen,
    Duration timeout,
  ) async {
    await for (final ptr in client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer('$serviceType.local'),
      timeout: timeout,
    )) {
      final name = mdnsInstanceName(ptr.domainName);
      await for (final srv in client.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(ptr.domainName),
        timeout: timeout,
      )) {
        // Look for an IPv6 link-local address in parallel with the IPv4 one:
        // when it's EUI-64 it spells out the device's MAC, which Android's
        // ARP restrictions otherwise hide.
        final macFuture = _lookupMacViaIpv6(client, srv.target, timeout);
        final ips = <String>[];
        await for (final ip in client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(srv.target),
          timeout: timeout,
        )) {
          final key = '${ip.address.address}:${srv.port}:$label';
          ips.add(ip.address.address);
          if (!seen.add(key)) continue;
          if (!controller.isClosed) {
            controller.add(
              MdnsObservation(
                ip: ip.address.address,
                name: name,
                port: srv.port,
                serviceLabel: label,
              ),
            );
          }
        }
        final mac = await macFuture;
        if (mac == null) continue;
        for (final ip in ips) {
          if (!seen.add('$ip:mac:$mac') || controller.isClosed) continue;
          controller.add(
            MdnsObservation(
              ip: ip,
              name: name,
              port: srv.port,
              serviceLabel: label,
              mac: mac,
            ),
          );
        }
      }
    }
  }

  Future<String?> _lookupMacViaIpv6(
    MDnsClient client,
    String target,
    Duration timeout,
  ) async {
    try {
      await for (final rec in client.lookup<IPAddressResourceRecord>(
        ResourceRecordQuery.addressIPv6(target),
        timeout: timeout,
      )) {
        final mac = macFromEui64LinkLocal(rec.address);
        if (mac != null) return mac;
      }
    } catch (_) {
      // Best-effort.
    }
    return null;
  }
}
