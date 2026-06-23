// A headless harness that runs a real scan of the active network using
// Sextant's pure-Dart engine (no Flutter). Uses the true OS netmask and the
// two-phase (ICMP+ARP discovery, then TCP port scan) orchestrator:
//
//   dart run tool/live_scan.dart
import 'dart:io';

import 'package:sextant/enrich/device_classifier.dart';
import 'package:sextant/enrich/oui_vendor_lookup.dart';
import 'package:sextant/model/network_info.dart';
import 'package:sextant/platform/interface_mask.dart';
import 'package:sextant/scan/ipv4_subnet.dart';
import 'package:sextant/scan/scan_orchestrator.dart';

Future<void> main() async {
  final interfaces = await NetworkInterface.list(
    includeLoopback: false,
    type: InternetAddressType.IPv4,
  );
  final iface = interfaces.firstWhere(
    (i) => i.addresses.any((a) => !a.address.startsWith('169.254')),
    orElse: () => interfaces.first,
  );
  final address = iface.addresses.first;
  final prefix = await const InterfaceMaskResolver().prefixFor(iface.name) ?? 24;
  final subnet = Ipv4Subnet.fromHostAndPrefix(address, prefix);
  final network = ScanNetwork(
    interfaceName: iface.name,
    displayName: iface.name,
    address: address,
    subnet: subnet,
  );

  final hostCount = subnet.hostAddresses().length;
  stdout.writeln('Scanning ${subnet.networkAddress.address}/$prefix '
      '($hostCount hosts) on ${iface.name} (${address.address})…\n');

  final orchestrator = ScanOrchestrator();
  final byIp = <String, Set<int>>{};
  final macByIp = <String, String?>{};
  final nameByIp = <String, String>{};
  final servicesByIp = <String, Map<int, String>>{};
  final sw = Stopwatch()..start();
  await for (final d in orchestrator.scan(network)) {
    byIp.putIfAbsent(d.ip, () => <int>{}).addAll(d.openPorts);
    if (d.mac != null) macByIp[d.ip] = d.mac;
    if (d.hostname != null) nameByIp.putIfAbsent(d.ip, () => d.hostname!);
    if (d.services.isNotEmpty) {
      servicesByIp.putIfAbsent(d.ip, () => {}).addAll(d.services);
    }
  }
  sw.stop();

  // Mirror the controller's enrichment so the harness shows real vendor/type.
  final oui = OuiVendorLookup(parseOuiTsv(File('assets/oui.tsv').readAsStringSync()));

  final sorted = byIp.keys.toList()
    ..sort((a, b) {
      int key(String ip) => ip.split('.').fold(0, (v, o) => (v << 8) | int.parse(o));
      return key(a).compareTo(key(b));
    });
  for (final ip in sorted) {
    final ports = byIp[ip]!.toList()..sort();
    final mac = macByIp[ip];
    final serviceLabels = (servicesByIp[ip]?.values.toSet()) ?? <String>{};
    final vendor = (mac != null ? oui.vendorFor(mac) : null) ??
        inferVendorFromServices(serviceLabels);
    final type = classifyDevice(
      openPorts: ports.toSet(),
      vendor: vendor,
      hostname: nameByIp[ip],
      services: serviceLabels,
    );
    stdout.writeln('  ${ip.padRight(15)} ${type.name.padRight(9)} '
        '${(vendor ?? '—').padRight(22)} ${(nameByIp[ip] ?? '—').padRight(22)} '
        '$ports');
  }
  stdout.writeln('\nDone: ${byIp.length} devices in '
      '${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s');
}
