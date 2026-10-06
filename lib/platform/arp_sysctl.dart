import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'arp_table.dart' show normalizeMac;

/// Size of the BSD `struct rt_msghdr` on macOS.
const _rtMsghdrSize = 92;
const _rtaDst = 0x1;
const _rtaGateway = 0x2;
const _afInet = 2;
const _afLink = 18;

/// Parses a buffer returned by `sysctl(NET_RT_FLAGS, RTF_LLINFO)` on macOS
/// into a map of IPv4 address -> normalized MAC. Each record is an
/// `rt_msghdr` followed by sockaddrs: the destination (`sockaddr_in`) and the
/// gateway (`sockaddr_dl`, whose link-layer address is the MAC). Incomplete
/// entries (empty link-layer address) are skipped.
Map<String, String> parseRouteDump(Uint8List buf) {
  final table = <String, String>{};
  final data = ByteData.sublistView(buf);
  var offset = 0;
  while (offset + _rtMsghdrSize <= buf.length) {
    final msgLen = data.getUint16(offset, Endian.host);
    if (msgLen < _rtMsghdrSize || offset + msgLen > buf.length) break;
    final addrs = data.getInt32(offset + 12, Endian.host);
    final end = offset + msgLen;
    var p = offset + _rtMsghdrSize;
    String? ip;
    String? mac;
    for (var bit = 0; bit < 8 && p < end; bit++) {
      final flag = 1 << bit;
      if (addrs & flag == 0) continue;
      final saLen = buf[p];
      final family = buf[p + 1];
      if (flag == _rtaDst && family == _afInet && saLen >= 8) {
        ip = buf.sublist(p + 4, p + 8).join('.');
      } else if (flag == _rtaGateway && family == _afLink) {
        final nlen = buf[p + 5];
        final alen = buf[p + 6];
        if (alen == 6) {
          final start = p + 8 + nlen;
          mac = normalizeMac(
            buf
                .sublist(start, start + 6)
                .map((b) => b.toRadixString(16))
                .join(':'),
          );
        }
      }
      // sockaddrs are padded to a 4-byte boundary; length 0 occupies 4.
      p += saLen == 0 ? 4 : (saLen + 3) & ~3;
    }
    if (ip != null && mac != null) table[ip] = mac;
    offset = end;
  }
  return table;
}

typedef _SysctlC = Int32 Function(
  Pointer<Int32>,
  Uint32,
  Pointer<Uint8>,
  Pointer<Uint64>,
  Pointer<Uint8>,
  Uint64,
);
typedef _SysctlDart = int Function(
  Pointer<Int32>,
  int,
  Pointer<Uint8>,
  Pointer<Uint64>,
  Pointer<Uint8>,
  int,
);
typedef _MallocC = Pointer<Uint8> Function(Uint64);
typedef _MallocDart = Pointer<Uint8> Function(int);
typedef _FreeC = Void Function(Pointer<Uint8>);
typedef _FreeDart = void Function(Pointer<Uint8>);

/// Reads the kernel's IPv4 neighbor (ARP) table in-process via `sysctl`, so
/// the access is attributed to this app rather than a spawned `arp` child.
/// Returns null if the call fails; an empty map means the table was empty.
Map<String, String>? readArpViaSysctl() {
  if (!Platform.isMacOS) return null;
  final lib = DynamicLibrary.process();
  final sysctl = lib.lookupFunction<_SysctlC, _SysctlDart>('sysctl');
  final malloc = lib.lookupFunction<_MallocC, _MallocDart>('malloc');
  final free = lib.lookupFunction<_FreeC, _FreeDart>('free');

  // CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_LLINFO
  const mibValues = [4, 17, 0, 2, 2, 0x400];
  final mib = malloc(mibValues.length * 4).cast<Int32>();
  final size = malloc(8).cast<Uint64>();
  try {
    for (var i = 0; i < mibValues.length; i++) {
      mib[i] = mibValues[i];
    }
    if (sysctl(mib, mibValues.length, nullptr, size, nullptr, 0) != 0) {
      return null;
    }
    final cap = size.value + size.value ~/ 4 + 4096;
    final out = malloc(cap);
    try {
      size.value = cap;
      if (sysctl(mib, mibValues.length, out, size, nullptr, 0) != 0) {
        return null;
      }
      return parseRouteDump(Uint8List.fromList(out.asTypedList(size.value)));
    } finally {
      free(out);
    }
  } finally {
    free(mib.cast());
    free(size.cast());
  }
}
