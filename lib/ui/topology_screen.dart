import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/network_info.dart';
import '../state/network_selection.dart';
import '../state/providers.dart';
import 'device_visuals.dart';
import 'topology_layout.dart';

/// A radial network map: the gateway (if known) at the center, every
/// discovered device on a ring around it. Tapping a node shows its details.
class TopologyScreen extends ConsumerWidget {
  const TopologyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(scanControllerProvider).devices;
    final networks = ref.watch(networksProvider).maybeWhen(
          data: (networks) => networks,
          orElse: () => const <ScanNetwork>[],
        );
    final selected = ref.watch(selectedNetworkProvider);
    final gatewayIp = effectiveNetwork(networks, selected)?.gateway?.address;

    return Scaffold(
      appBar: AppBar(title: const Text('Network Map')),
      body: devices.isEmpty
          ? const Center(child: Text('Run a scan to see the network map.'))
          : LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                final nodes = layoutRadial(devices, gatewayIp: gatewayIp, size: size);
                return Stack(
                  children: [
                    CustomPaint(size: size, painter: _EdgePainter(nodes)),
                    for (final node in nodes)
                      Positioned(
                        left: node.position.dx - 24,
                        top: node.position.dy - 24,
                        child: _TopologyNodeWidget(node: node),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _TopologyNodeWidget extends StatelessWidget {
  const _TopologyNodeWidget({required this.node});

  final TopologyNode node;

  @override
  Widget build(BuildContext context) {
    final device = node.device;
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(device.displayName),
          content: Text('IP: ${device.ip}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
      child: Tooltip(
        message: device.displayName,
        child: CircleAvatar(
          radius: 24,
          backgroundColor: node.isGateway
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(deviceIcon(device)),
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter(this.nodes);

  final List<TopologyNode> nodes;

  @override
  void paint(Canvas canvas, Size size) {
    TopologyNode? center;
    for (final n in nodes) {
      if (n.isGateway) {
        center = n;
        break;
      }
    }
    if (center == null) return;
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (final n in nodes) {
      if (n.isGateway) continue;
      canvas.drawLine(center.position, n.position, paint);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter oldDelegate) => oldDelegate.nodes != nodes;
}
