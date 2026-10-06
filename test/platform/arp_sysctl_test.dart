import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/platform/arp_sysctl.dart';

Uint8List _record(List<int> ip, List<int> mac) {
  final b = BytesBuilder();
  final hdr = ByteData(92);
  final total = 92 + 16 + 20;
  hdr.setUint16(0, total, Endian.host);
  hdr.setInt32(12, 0x3, Endian.host); // RTA_DST | RTA_GATEWAY
  b.add(hdr.buffer.asUint8List());
  // sockaddr_in: len 16, AF_INET, port, addr, zero pad
  b.add([16, 2, 0, 0, ...ip, 0, 0, 0, 0, 0, 0, 0, 0]);
  // sockaddr_dl: len 18+, AF_LINK, index(2), type, nlen=0, alen=6, slen, mac
  final sdl = [20, 18, 0, 5, 6, 0, mac.isEmpty ? 0 : 6, 0, ...mac];
  b.add([...sdl, ...List.filled(20 - sdl.length, 0)]);
  return b.toBytes();
}

void main() {
  test('parses ip -> mac from a route dump', () {
    final buf = Uint8List.fromList([
      ..._record([192, 168, 4, 22], [0xb0, 0x4a, 0x39, 0x2f, 0xd2, 0xff]),
      ..._record([192, 168, 4, 25], [0x00, 0x9d, 0x6b, 0xbe, 0xba, 0x12]),
    ]);
    expect(parseRouteDump(buf), {
      '192.168.4.22': 'b0:4a:39:2f:d2:ff',
      '192.168.4.25': '00:9d:6b:be:ba:12',
    });
  });

  test('skips incomplete entries', () {
    final buf = _record([192, 168, 4, 2], []);
    expect(parseRouteDump(buf), isEmpty);
  });

  test('empty buffer yields empty table', () {
    expect(parseRouteDump(Uint8List(0)), isEmpty);
  });

  test('live sysctl read does not throw on macOS', () {
    // null on non-macOS or failure; otherwise a (possibly empty) map.
    expect(readArpViaSysctl, returnsNormally);
  });
}
