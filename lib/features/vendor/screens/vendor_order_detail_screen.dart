import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/order_model.dart';
import '../../../core/services/write_log_service.dart';

class VendorOrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  const VendorOrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<VendorOrderDetailScreen> createState() =>
      _VendorOrderDetailScreenState();
}

class _VendorOrderDetailScreenState
    extends ConsumerState<VendorOrderDetailScreen> {
  OrderModel? _order;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final doc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .get();
    if (!mounted) return;
    setState(() {
      _order = doc.exists ? OrderModel.fromMap(doc.id, doc.data()!) : null;
      _loading = false;
    });
  }

  Future<void> _updateStatus(String newStatus) async {
    await WriteLogService.capture(
      action: 'Update order status',
      target: 'orders/${widget.orderId}',
      task: () => FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .update({'status': newStatus}),
    );
    await NotificationService.orderStatusChanged(widget.orderId, newStatus);
    if (mounted) {
      setState(() {
        _order?.status = newStatus;
      });
    }
  }

  Color _statusColor(String s) => switch (s) {
        'placed' => AppColors.placed,
        'confirmed' => AppColors.confirmed,
        'ready' => AppColors.ready,
        _ => AppColors.completed,
      };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    final order = _order;
    if (order == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('Order not found')));
    }

    final theme = Theme.of(context);
    final hasLocation =
        order.deliveryLat != null && order.deliveryLng != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('#${order.id.substring(0, 8).toUpperCase()}'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: _statusColor(order.status).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                order.status.toUpperCase(),
                style: TextStyle(
                    color: _statusColor(order.status),
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(order.buyerName,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(
                      order.deliveryType == 'pickup'
                          ? Icons.store_rounded
                          : Icons.delivery_dining_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      order.deliveryType == 'pickup'
                          ? 'Pickup'
                          : 'Delivery: ${order.deliveryAddress ?? '—'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ]),
                ],
              ),
            ),
          ),
          if (hasLocation) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 200,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter:
                        LatLng(order.deliveryLat!, order.deliveryLng!),
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.campuseat.app',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: LatLng(
                            order.deliveryLat!, order.deliveryLng!),
                        width: 40,
                        height: 40,
                        child: Icon(Icons.location_pin,
                            color: theme.colorScheme.primary, size: 40),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Items',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 8),
                  ...order.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          Expanded(
                              child: Text(
                                  '${item.foodName} × ${item.quantity}')),
                          Text((item.price * item.quantity).toCurrency(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ]),
                      )),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      Text(order.total.toCurrency(),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                              fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (order.status == 'placed')
            _ActionButton(
                label: 'Confirm Order',
                color: AppColors.confirmed,
                onTap: () => _updateStatus('confirmed')),
          if (order.status == 'confirmed')
            _ActionButton(
                label: 'Mark as Ready',
                color: AppColors.ready,
                onTap: () => _updateStatus('ready')),
          if (order.status == 'ready')
            _ActionButton(
                label: 'Mark as Completed',
                color: AppColors.completed,
                onTap: () => _updateStatus('completed')),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
