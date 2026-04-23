import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_provider.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/order_model.dart';
import '../../../core/widgets/firestore_error_view.dart';

class AdminOrdersScreen extends ConsumerWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(allOrdersProvider);
    if (ordersAsync.isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (ordersAsync.hasError) {
      return Scaffold(body: FirestoreErrorView(error: ordersAsync.error!));
    }
    final orders = ordersAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('All Orders'), centerTitle: true),
      body: orders.isEmpty
          ? const Center(child: Text('No orders yet'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _AdminOrderTile(order: orders[i]),
            ),
    );
  }
}

class _AdminOrderTile extends StatelessWidget {
  final OrderModel order;
  const _AdminOrderTile({required this.order});

  Color _statusColor(String s) => switch (s) {
        'placed' => AppColors.placed,
        'confirmed' => AppColors.confirmed,
        'ready' => AppColors.ready,
        _ => AppColors.completed,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('#${order.id.substring(0, 8).toUpperCase()}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                Text('${order.buyerName} → ${order.vendorBrandName}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(order.status).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(order.status.toUpperCase(),
                  style: TextStyle(
                      color: _statusColor(order.status),
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Icon(
              order.deliveryType == 'pickup'
                  ? Icons.store_rounded
                  : Icons.delivery_dining_rounded,
              size: 13,
              color: Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(order.deliveryType.capitalize(),
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
            const Spacer(),
            Text(order.total.toCurrency(),
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary)),
          ]),
          Text(order.createdAt.toDisplay(),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey, fontSize: 11)),
        ]),
      ),
    );
  }
}
