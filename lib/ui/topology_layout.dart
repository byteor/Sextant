import 'dart:math';
import 'dart:ui';

import '../model/device.dart';

/// One positioned node in a radial topology layout.
class TopologyNode {
  const TopologyNode({
    required this.device,
    required this.position,
    required this.isGateway,
  });

  final Device device;
  final Offset position;
  final bool isGateway;
}

/// Lays [devices] out radially within [size]: the device whose IP matches
/// [gatewayIp] (if any) sits at the center; every other device is placed on
/// a ring around it, sorted by IP and spaced evenly starting at 12 o'clock.
/// With no gateway match, every device goes on the ring (no center node).
List<TopologyNode> layoutRadial(
  List<Device> devices, {
  String? gatewayIp,
  required Size size,
}) {
  if (devices.isEmpty) return [];

  final center = Offset(size.width / 2, size.height / 2);
  const nodeRadius = 24.0;
  final ringRadius = min(size.width, size.height) / 2 - nodeRadius;

  Device? gateway;
  final ring = <Device>[];
  for (final d in devices) {
    if (gatewayIp != null && d.ip == gatewayIp && gateway == null) {
      gateway = d;
    } else {
      ring.add(d);
    }
  }
  ring.sort((a, b) => a.ipSortKey.compareTo(b.ipSortKey));

  final nodes = <TopologyNode>[];
  if (gateway != null) {
    nodes.add(TopologyNode(device: gateway, position: center, isGateway: true));
  }
  for (var i = 0; i < ring.length; i++) {
    final angle = -pi / 2 + (2 * pi * i / ring.length);
    nodes.add(TopologyNode(
      device: ring[i],
      position: Offset(
        center.dx + ringRadius * cos(angle),
        center.dy + ringRadius * sin(angle),
      ),
      isGateway: false,
    ));
  }
  return nodes;
}
