import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'tcp_probe.dart';

/// A function that probes whether [host]:[port] is open.
typedef PortProbe = Future<bool> Function(InternetAddress host, int port);

/// Reports scan progress: [done] hosts (out of [total]) have finished probing.
typedef HostProgress = void Function(int done, int total);

/// The result of TCP-scanning a single host: the host and its open ports.
class HostScanResult {
  HostScanResult(this.host, this.openPorts);

  final InternetAddress host;

  /// Open TCP ports, ascending.
  final List<int> openPorts;
}

/// Sweeps a set of hosts across a set of ports using TCP-connect probes,
/// bounded by [concurrency], emitting a [HostScanResult] for each host that
/// has at least one open port as soon as that host's probes all complete.
///
/// TCP-connect is used because it needs no elevated privileges on any
/// platform, unlike raw ICMP.
class TcpHostScanner {
  TcpHostScanner({
    PortProbe? probe,
    this.concurrency = 256,
    this.timeout = const Duration(seconds: 1),
    // ignore: prefer_initializing_formals
  }) : _probe = probe;

  final PortProbe? _probe;
  final int concurrency;
  final Duration timeout;

  Future<bool> _runProbe(InternetAddress host, int port) {
    final probe = _probe;
    if (probe != null) return probe(host, port);
    return const TcpProbe().isOpen(host, port, timeout: timeout);
  }

  Stream<HostScanResult> scan(
    List<InternetAddress> hosts,
    List<int> ports, {
    HostProgress? onHostComplete,
    bool Function()? isCancelled,
  }) {
    final controller = StreamController<HostScanResult>();
    unawaited(_drive(hosts, ports, controller, onHostComplete, isCancelled));
    return controller.stream;
  }

  Future<void> _drive(
    List<InternetAddress> hosts,
    List<int> ports,
    StreamController<HostScanResult> controller,
    HostProgress? onHostComplete,
    bool Function()? isCancelled,
  ) async {
    if (hosts.isEmpty || ports.isEmpty) {
      await controller.close();
      return;
    }

    final openByHost = List.generate(hosts.length, (_) => <int>[]);
    final remaining = List<int>.filled(hosts.length, ports.length);

    // Flatten into a single task list so concurrency is bounded across the
    // whole sweep, not per host.
    final tasks = <_ProbeTask>[
      for (var h = 0; h < hosts.length; h++)
        for (final port in ports) _ProbeTask(h, port),
    ];

    var next = 0;
    var completedHosts = 0;
    Future<void> worker() async {
      while (true) {
        if (isCancelled?.call() ?? false) break;
        final i = next++;
        if (i >= tasks.length) break;
        final task = tasks[i];
        final open = await _runProbe(hosts[task.hostIndex], task.port);
        if (open) openByHost[task.hostIndex].add(task.port);
        if (--remaining[task.hostIndex] == 0) {
          final found = openByHost[task.hostIndex]..sort();
          if (found.isNotEmpty && !(isCancelled?.call() ?? false)) {
            controller.add(HostScanResult(hosts[task.hostIndex], found));
          }
          onHostComplete?.call(++completedHosts, hosts.length);
        }
      }
    }

    final workerCount = math.min(concurrency, tasks.length);
    await Future.wait([for (var i = 0; i < workerCount; i++) worker()]);
    await controller.close();
  }
}

class _ProbeTask {
  _ProbeTask(this.hostIndex, this.port);
  final int hostIndex;
  final int port;
}
