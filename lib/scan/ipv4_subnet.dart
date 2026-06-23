import 'dart:io';
import 'dart:typed_data';

/// An IPv4 subnet, used to enumerate the host addresses to scan.
class Ipv4Subnet {
  /// Creates a subnet from any [address] in it (32-bit) and a [prefixLength];
  /// the address is masked down to the network address.
  Ipv4Subnet(int address, this.prefixLength)
      : assert(prefixLength >= 0 && prefixLength <= 32),
        network = address & _prefixMask(prefixLength);

  /// The network address as a 32-bit unsigned integer.
  final int network;
  final int prefixLength;

  factory Ipv4Subnet.fromCidr(String cidr) {
    final parts = cidr.split('/');
    if (parts.length != 2) {
      throw FormatException('Invalid CIDR: $cidr');
    }
    return Ipv4Subnet(
      _toInt(InternetAddress(parts[0])),
      int.parse(parts[1]),
    );
  }

  factory Ipv4Subnet.fromHostAndPrefix(InternetAddress host, int prefix) =>
      Ipv4Subnet(_toInt(host), prefix);

  factory Ipv4Subnet.fromHostAndMask(
    InternetAddress host,
    InternetAddress mask,
  ) =>
      Ipv4Subnet(_toInt(host), _maskToPrefix(_toInt(mask)));

  int get _broadcast => network | (~_prefixMask(prefixLength) & 0xFFFFFFFF);

  InternetAddress get networkAddress => _toAddress(network);
  InternetAddress get broadcastAddress => _toAddress(_broadcast);

  /// Whether [address] (an IPv4 address) falls within this subnet's range,
  /// inclusive of the network and broadcast addresses.
  bool contains(InternetAddress address) {
    if (address.rawAddress.length != 4) return false;
    final value = _toInt(address);
    return value >= network && value <= _broadcast;
  }

  /// The usable host addresses, ascending.
  ///
  /// For prefixes up to /30 the network and broadcast addresses are excluded.
  /// /31 (RFC 3021 point-to-point) yields both addresses; /32 yields the
  /// single address.
  Iterable<InternetAddress> hostAddresses() sync* {
    final int first;
    final int last;
    if (prefixLength >= 31) {
      first = network;
      last = _broadcast;
    } else {
      first = network + 1;
      last = _broadcast - 1;
    }
    for (var addr = first; addr <= last; addr++) {
      yield _toAddress(addr);
    }
  }

  static int _prefixMask(int prefix) {
    if (prefix == 0) return 0;
    return (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
  }

  static int _maskToPrefix(int mask) {
    var bits = 0;
    var m = mask;
    while (m & 0x80000000 != 0) {
      bits++;
      m = (m << 1) & 0xFFFFFFFF;
    }
    return bits;
  }

  static int _toInt(InternetAddress address) {
    final raw = address.rawAddress;
    if (raw.length != 4) {
      throw ArgumentError('Not an IPv4 address: ${address.address}');
    }
    return (raw[0] << 24) | (raw[1] << 16) | (raw[2] << 8) | raw[3];
  }

  static InternetAddress _toAddress(int value) {
    return InternetAddress.fromRawAddress(
      Uint8List.fromList(<int>[
        (value >> 24) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 8) & 0xFF,
        value & 0xFF,
      ]),
    );
  }
}
