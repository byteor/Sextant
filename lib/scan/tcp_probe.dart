import 'dart:io';

/// Probes whether a single TCP port is reachable by attempting a connection.
///
/// This is the privilege-free liveness primitive: opening a TCP connection
/// requires no elevation on any platform, unlike raw ICMP.
class TcpProbe {
  const TcpProbe();

  /// Returns true if a TCP connection to [host]:[port] succeeds within
  /// [timeout], false if the connection is refused, times out, or errors.
  Future<bool> isOpen(
    InternetAddress host,
    int port, {
    Duration timeout = const Duration(seconds: 1),
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      return true;
    } on SocketException {
      return false;
    } finally {
      socket?.destroy();
    }
  }
}
