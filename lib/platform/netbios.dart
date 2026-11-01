import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Builds a NetBIOS Name Service (NBNS) "node status" (NBSTAT) request for the
/// wildcard name `*`, used to ask a host for its NetBIOS name table over UDP
/// 137. This is how Windows / SMB devices expose their machine name.
Uint8List buildNbstatRequest({int transactionId = 0x4b41}) {
  final b = BytesBuilder();
  b.add([(transactionId >> 8) & 0xFF, transactionId & 0xFF]); // transaction id
  b.add([0x00, 0x00]); // flags
  b.add([0x00, 0x01]); // QDCOUNT = 1
  b.add([0x00, 0x00, 0x00, 0x00, 0x00, 0x00]); // AN/NS/AR counts

  // Question name: the wildcard "*" padded to 16 bytes, first-level encoded
  // (each byte -> two nibble characters offset from 'A').
  b.addByte(0x20); // encoded length = 32
  final raw = <int>[0x2A, ...List.filled(15, 0)]; // '*' + 15 NULs
  for (final byte in raw) {
    b.addByte(0x41 + ((byte >> 4) & 0xF));
    b.addByte(0x41 + (byte & 0xF));
  }
  b.addByte(0x00); // name terminator

  b.add([0x00, 0x21]); // QTYPE = NBSTAT
  b.add([0x00, 0x01]); // QCLASS = IN
  return b.toBytes();
}

/// What an NBSTAT reply reveals about a host: its unique workstation name and
/// the MAC address carried in the reply's trailing "unit ID" field.
class NbstatInfo {
  const NbstatInfo({this.name, this.mac});

  final String? name;

  /// Lower-case colon-separated MAC, or null when the host reports none.
  final String? mac;
}

/// Parses an NBSTAT response into the host's unique (non-group) workstation
/// name (suffix 0x00) and its MAC address (the 6-byte unit ID that follows the
/// name table — Windows and Samba fill it in; some stacks send all zeros,
/// which is treated as absent). Returns null if the packet is malformed or
/// carries neither. Handles both a full RR name and a compression pointer.
NbstatInfo? parseNbstat(Uint8List data) {
  var off = 12; // skip the 12-byte header
  if (off >= data.length) return null;

  // Skip the resource-record NAME.
  if ((data[off] & 0xC0) == 0xC0) {
    off += 2; // compression pointer
  } else {
    while (off < data.length && data[off] != 0) {
      off += data[off] + 1;
    }
    off += 1; // the terminating 0
  }

  off += 2 + 2 + 4 + 2; // TYPE + CLASS + TTL + RDLENGTH
  if (off >= data.length) return null;

  final numNames = data[off];
  off += 1;
  String? hostName;
  for (var i = 0; i < numNames; i++) {
    if (off + 18 > data.length) break;
    final name = String.fromCharCodes(data.sublist(off, off + 15)).trim();
    final suffix = data[off + 15];
    final flags = (data[off + 16] << 8) | data[off + 17];
    final isGroup = (flags & 0x8000) != 0;
    if (hostName == null && suffix == 0x00 && !isGroup && name.isNotEmpty) {
      hostName = name;
    }
    off += 18;
  }

  String? mac;
  if (off + 6 <= data.length) {
    final bytes = data.sublist(off, off + 6);
    if (bytes.any((b) => b != 0)) {
      mac = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
    }
  }
  if (hostName == null && mac == null) return null;
  return NbstatInfo(name: hostName, mac: mac);
}

/// The unique workstation name from an NBSTAT response, or null.
String? parseNbstatResponse(Uint8List data) => parseNbstat(data)?.name;

/// Queries a host's NetBIOS name and MAC by sending an NBSTAT query to its UDP
/// 137 and parsing the reply. Best-effort: returns null on timeout or any error.
class NetbiosResolver {
  const NetbiosResolver({this.timeout = const Duration(seconds: 1)});

  final Duration timeout;

  Future<NbstatInfo?> queryInfo(InternetAddress host) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final completer = Completer<NbstatInfo?>();
      socket.listen(
        (event) {
          if (event != RawSocketEvent.read) return;
          final dg = socket!.receive();
          if (dg == null || dg.address.address != host.address) return;
          if (!completer.isCompleted) {
            completer.complete(parseNbstat(dg.data));
          }
        },
        // A datagram to a powered-off host can surface an async "host is down"
        // ICMP error on the socket; swallow it rather than let it go unhandled.
        onError: (_) {},
      );
      socket.send(buildNbstatRequest(), host, 137);
      return await completer.future.timeout(timeout, onTimeout: () => null);
    } catch (_) {
      return null;
    } finally {
      socket?.close();
    }
  }
}
