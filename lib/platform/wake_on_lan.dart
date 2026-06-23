import 'dart:io';
import 'dart:typed_data';

/// Builds an IEEE 802.3 Wake-on-LAN "magic packet": 6 bytes of 0xFF followed
/// by [mac] repeated 16 times (102 bytes total). [mac] may use `:` or `-` as
/// the octet separator. Throws [ArgumentError] if [mac] isn't exactly 6 valid
/// hex octets.
Uint8List buildMagicPacket(String mac) {
  final parts = mac.split(RegExp('[:-]'));
  if (parts.length != 6) {
    throw ArgumentError.value(mac, 'mac', 'must have 6 octets');
  }
  final octets = [
    for (final part in parts)
      int.tryParse(part, radix: 16) ??
          (throw ArgumentError.value(mac, 'mac', 'invalid hex octet "$part"')),
  ];
  for (final o in octets) {
    if (o < 0 || o > 0xFF) {
      throw ArgumentError.value(mac, 'mac', 'octet out of range');
    }
  }

  final packet = BytesBuilder();
  packet.add(List.filled(6, 0xFF));
  for (var i = 0; i < 16; i++) {
    packet.add(octets);
  }
  return packet.toBytes();
}

/// Sends a Wake-on-LAN magic packet as a UDP broadcast so a sleeping/powered-off
/// device with WoL enabled can power on.
class WakeOnLan {
  const WakeOnLan({this.port = 9});

  /// The UDP discard port magic packets are conventionally sent to.
  final int port;

  /// Broadcasts a magic packet for [mac] on [broadcastAddress] (the network's
  /// broadcast address, e.g. 192.168.1.255 — falls back to the limited
  /// broadcast 255.255.255.255 if not given).
  Future<void> send(String mac, {String? broadcastAddress}) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    try {
      socket.broadcastEnabled = true;
      final target = InternetAddress(broadcastAddress ?? '255.255.255.255');
      socket.send(buildMagicPacket(mac), target, port);
    } finally {
      socket.close();
    }
  }
}
