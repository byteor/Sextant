import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/platform/netbios.dart';

void main() {
  group('buildNbstatRequest', () {
    test('builds a 50-byte NBSTAT node-status query', () {
      final pkt = buildNbstatRequest(transactionId: 0x4b41);

      expect(pkt.length, 50);
      expect([pkt[0], pkt[1]], [0x4b, 0x41]); // transaction id
      expect([pkt[4], pkt[5]], [0x00, 0x01]); // QDCOUNT = 1
      expect(pkt[12], 0x20); // encoded-name length
      // The wildcard name "*" first-level encodes to "CKAA…AA".
      expect(String.fromCharCodes(pkt.sublist(13, 45)),
          'CKAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA');
      expect([pkt[46], pkt[47]], [0x00, 0x21]); // QTYPE = NBSTAT
      expect([pkt[48], pkt[49]], [0x00, 0x01]); // QCLASS = IN
    });
  });

  group('parseNbstatResponse', () {
    Uint8List response(String name, {int flags = 0x0400, int suffix = 0x00}) {
      final b = BytesBuilder();
      b.add([0x4b, 0x41, 0x84, 0x00]); // id + response flags
      b.add([0x00, 0x00, 0x00, 0x01]); // QD=0, AN=1
      b.add([0x00, 0x00, 0x00, 0x00]); // NS=0, AR=0
      b.addByte(0x20);
      b.add(List.filled(32, 0x41)); // encoded name (content irrelevant here)
      b.addByte(0x00);
      b.add([0x00, 0x21, 0x00, 0x01]); // type + class
      b.add([0x00, 0x00, 0x00, 0x00]); // ttl
      b.add([0x00, 0x29]); // rdlength (unchecked)
      b.addByte(0x01); // one name
      b.add(name.padRight(15).codeUnits);
      b.addByte(suffix);
      b.add([(flags >> 8) & 0xFF, flags & 0xFF]);
      return b.toBytes();
    }

    test('extracts the unique workstation name', () {
      expect(parseNbstatResponse(response('MYPC')), 'MYPC');
    });

    test('ignores group names (e.g. the workgroup)', () {
      // Group bit (0x8000) set -> not a machine name.
      expect(parseNbstatResponse(response('WORKGROUP', flags: 0x8400)), isNull);
    });

    test('returns null for a truncated packet', () {
      expect(parseNbstatResponse(Uint8List.fromList([0, 1, 2, 3])), isNull);
    });
  });
}
