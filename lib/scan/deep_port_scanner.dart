import 'dart:io';

import 'tcp_host_scanner.dart';

/// Every TCP port, 1–65,535 inclusive.
final List<int> kAllTcpPorts = List.generate(65535, (i) => i + 1);

/// Scans every TCP port on a single host, tuned to be gentler than the
/// regular subnet sweep (lower concurrency, shorter timeout) since this runs
/// against one device rather than spreading load across many.
///
/// Unlike [TcpHostScanner] on its own — built for many-hosts/few-ports,
/// reporting progress once a whole host finishes — this reports progress
/// after every individual port probe via [onProgress], since there's only
/// one host and 65,535 ports: host-level progress would jump straight from
/// 0% to 100%.
class DeepPortScanner {
  DeepPortScanner({TcpHostScanner? scanner})
    : _scanner =
          scanner ??
          TcpHostScanner(
            concurrency: 64,
            timeout: const Duration(milliseconds: 400),
          );

  final TcpHostScanner _scanner;

  /// Scans every port in [kAllTcpPorts] on [host]. Returns the sorted list
  /// of open ports found — empty if none are open, or if [isCancelled]
  /// became true before the scan finished (a cancelled scan reports nothing,
  /// even if some ports were found open before cancellation).
  Future<List<int>> scan(
    InternetAddress host, {
    HostProgress? onProgress,
    bool Function()? isCancelled,
  }) async {
    final results = await _scanner
        .scan(
          [host],
          kAllTcpPorts,
          onProbeComplete: onProgress,
          isCancelled: isCancelled,
        )
        .toList();
    return results.isEmpty ? const [] : results.single.openPorts;
  }
}
