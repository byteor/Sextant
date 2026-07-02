import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

/// Builds the platform-appropriate arguments for the system `ping` binary to
/// send a single echo request to [host] with the given [timeoutMs].
///
/// Using the system `ping` keeps liveness checks privilege-free (raw ICMP would
/// require root). Flag spellings differ per platform: Windows counts with `-n`
/// and waits in milliseconds (`-w`); macOS/Linux count with `-c` and take a
/// whole-second timeout (`-t` on macOS, `-W` on Linux).
List<String> buildPingArgs(
  String host, {
  required bool isWindows,
  required bool isMacOS,
  int timeoutMs = 1000,
}) {
  if (isWindows) {
    return ['-n', '1', '-w', '$timeoutMs', host];
  }
  final seconds = (timeoutMs / 1000).ceil();
  if (isMacOS) {
    return ['-c', '1', '-t', '$seconds', host];
  }
  return ['-c', '1', '-W', '$seconds', host];
}

/// The outcome of a single ping: whether the host replied, and its round-trip
/// time in milliseconds if it did.
class PingResult {
  const PingResult(this.address, {required this.alive, this.rttMs});

  final InternetAddress address;
  final bool alive;
  final double? rttMs;
}

/// Extracts the round-trip time (in ms) from a single `ping` reply line.
/// Handles macOS/Linux (`time=1.234 ms`) and Windows (`time=1ms`/`time<1ms`)
/// phrasing. Returns null when no reply line is present (e.g. a timeout).
double? parsePingRttMs(String output) {
  final match = RegExp(r'time[=<]([\d.]+)\s*ms', caseSensitive: false)
      .firstMatch(output);
  if (match == null) return null;
  return double.tryParse(match.group(1)!);
}

/// Privilege-free ICMP liveness check via the system `ping` command.
class IcmpPinger {
  const IcmpPinger({this.timeout = const Duration(seconds: 1)});

  final Duration timeout;

  /// Pings [host] once, returning whether it replied and the reply TTL.
  Future<PingResult> ping(InternetAddress host) async {
    final args = buildPingArgs(
      host.address,
      isWindows: Platform.isWindows,
      isMacOS: Platform.isMacOS,
      timeoutMs: timeout.inMilliseconds,
    );
    try {
      final result = await Process.run('ping', args)
          .timeout(timeout + const Duration(seconds: 1));
      final alive = result.exitCode == 0;
      return PingResult(
        host,
        alive: alive,
        rttMs: alive ? parsePingRttMs(result.stdout as String) : null,
      );
    } on TimeoutException {
      return PingResult(host, alive: false);
    } on ProcessException {
      return PingResult(host, alive: false);
    }
  }

  /// Returns true if [host] replies to a single ICMP echo within [timeout].
  Future<bool> isAlive(InternetAddress host) async =>
      (await ping(host)).alive;
}

/// Reports sweep progress: [done] of [total] hosts have been pinged.
typedef PingProgress = void Function(int done, int total);

/// Pings a list of hosts with bounded concurrency, emitting each host that
/// replies. Doubles as an ARP primer: sending an echo to an on-link host
/// triggers ARP resolution, so the OS ARP cache is populated for every host
/// that answers at layer 2 — even those that drop the ICMP echo. The ping
/// sweep is the dominant phase of a scan: a host that doesn't reply costs the
/// full [IcmpPinger.timeout] (1s default). At concurrency 64, a /22 (1022
/// hosts) needs >=16 sequential rounds whenever any round contains a
/// non-responder — which is most of them — i.e. >=16s just for the sweep,
/// matching the ~18s observed on the real /22 this was tuned against. Concurrency
/// 128 halves that floor to >=8 rounds, while staying well below the TCP
/// scanner's 256 (each ping forks a process, heavier than a TCP connect, so it
/// isn't raised all the way to parity).
class IcmpSweeper {
  IcmpSweeper({IcmpPinger? pinger, this.concurrency = 128})
      : _pinger = pinger ?? const IcmpPinger();

  final IcmpPinger _pinger;
  final int concurrency;

  Stream<PingResult> sweep(
    List<InternetAddress> hosts, {
    PingProgress? onProgress,
    bool Function()? isCancelled,
  }) {
    final controller = StreamController<PingResult>();
    unawaited(_drive(hosts, controller, onProgress, isCancelled));
    return controller.stream;
  }

  Future<void> _drive(
    List<InternetAddress> hosts,
    StreamController<PingResult> controller,
    PingProgress? onProgress,
    bool Function()? isCancelled,
  ) async {
    if (hosts.isEmpty) {
      await controller.close();
      return;
    }
    var next = 0;
    var done = 0;
    Future<void> worker() async {
      while (true) {
        if (isCancelled?.call() ?? false) break;
        final i = next++;
        if (i >= hosts.length) break;
        final result = await _pinger.ping(hosts[i]);
        if (isCancelled?.call() ?? false) break;
        if (result.alive) controller.add(result);
        onProgress?.call(++done, hosts.length);
      }
    }

    final workers = math.min(concurrency, hosts.length);
    await Future.wait([for (var i = 0; i < workers; i++) worker()]);
    await controller.close();
  }
}
