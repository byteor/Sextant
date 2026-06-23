/// Turns a raw banner / protocol greeting read from an open [port] into a short
/// human-readable service identifier (e.g. "OpenSSH 9.6", "nginx 1.25.3"), or
/// null when nothing useful can be extracted.
///
/// Pure and table-driven so it is cheap to test and reuse.
String? identifyService(int port, String raw) {
  if (raw.trim().isEmpty) return null;

  // HTTP: prefer the Server response header.
  final server = _serverHeader(raw);
  if (server != null) return _normalizeVersion(server);

  final firstLine = raw
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty, orElse: () => '');
  if (firstLine.isEmpty) return null;

  // An HTTP response with no Server header tells us nothing useful — the status
  // line ("HTTP/1.0 404 Not Found") is not a service identity.
  if (firstLine.startsWith('HTTP/')) return null;

  // SSH identification string: "SSH-2.0-OpenSSH_9.6".
  if (firstLine.startsWith('SSH-')) {
    final parts = firstLine.split('-');
    if (parts.length >= 3) return _normalizeVersion(parts.sublist(2).join('-'));
  }

  // Line-oriented greetings (FTP/SMTP/POP/IMAP) begin with a numeric code.
  final coded = RegExp(r'^\d{3}[ -]+(.*)').firstMatch(firstLine);
  if (coded != null) return coded.group(1)!.trim();

  return firstLine;
}

String? _serverHeader(String raw) {
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    final match = RegExp(r'^server:\s*(.+)$', caseSensitive: false)
        .firstMatch(line.trim());
    if (match != null) return match.group(1)!.trim();
  }
  return null;
}

/// "nginx/1.25.3" -> "nginx 1.25.3"; "OpenSSH_9.6" -> "OpenSSH 9.6".
String _normalizeVersion(String s) =>
    s.replaceAll('/', ' ').replaceAll('_', ' ').trim();
