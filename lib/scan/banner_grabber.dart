import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Ports we treat as HTTP(S): we send a `HEAD` request to elicit a response,
/// rather than waiting for an unprompted banner.
const _httpPorts = {80, 3000, 5000, 8000, 8080, 9000};
const _tlsPorts = {443, 8443};

/// Grabs a service banner from an open TCP port: reads whatever greeting the
/// server sends, prompting HTTP(S) ports with a `HEAD` request first. Returns
/// the raw text (capped), or null if nothing is read.
///
/// Pair with [identifyService] to turn the raw text into a friendly label.
class BannerGrabber {
  const BannerGrabber({this.timeout = const Duration(milliseconds: 1500)});

  final Duration timeout;

  Future<String?> grab(InternetAddress host, int port) async {
    final isTls = _tlsPorts.contains(port);
    final isHttp = isTls || _httpPorts.contains(port);
    Socket? socket;
    try {
      socket = isTls
          ? await SecureSocket.connect(
              host,
              port,
              timeout: timeout,
              onBadCertificate: (_) => true,
            )
          : await Socket.connect(host, port, timeout: timeout);

      if (isHttp) {
        socket.write('HEAD / HTTP/1.0\r\nHost: ${host.address}\r\n\r\n');
        await socket.flush();
      }

      final buffer = <int>[];
      final complete = Completer<void>();
      late StreamSubscription<List<int>> sub;
      void finish() {
        if (!complete.isCompleted) complete.complete();
      }

      sub = socket.listen(
        (data) {
          buffer.addAll(data);
          if (buffer.length >= 2048) finish();
        },
        onError: (_) => finish(),
        onDone: finish,
        cancelOnError: true,
      );

      await complete.future.timeout(timeout, onTimeout: () {});
      await sub.cancel();

      if (buffer.isEmpty) return null;
      final text = utf8.decode(buffer, allowMalformed: true).trim();
      return text.isEmpty ? null : text;
    } on SocketException {
      return null;
    } on TlsException {
      return null;
    } finally {
      socket?.destroy();
    }
  }
}
