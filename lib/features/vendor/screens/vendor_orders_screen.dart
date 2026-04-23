import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/vendor_orders_provider.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../models/order_model.dart';
import '../../../core/widgets/firestore_error_view.dart';

class VendorOrdersScreen extends ConsumerWidget {
  const VendorOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(vendorOrdersProvider);
    if (ordersAsync.isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (ordersAsync.hasError) {
      return Scaffold(body: FirestoreErrorView(error: ordersAsync.error!));
    }
    final orders = ordersAsync.valueOrNull ?? [];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Orders'),
          centerTitle: true,
          bottom: const TabBar(tabs: [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ]),
        ),
        body: TabBarView(children: [
          _OrdersList(
            orders: orders.where((o) => o.status != 'completed').toList(),
            emptyMsg: 'No active orders',
          ),
          _OrdersList(
            orders: orders.where((o) => o.status == 'completed').toList(),
            emptyMsg: 'No completed orders',
          ),
        ]),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final List<OrderModel> orders;
  final String emptyMsg;
  const _OrdersList({required this.orders, required this.emptyMsg});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return EmptyStateWidget(title: emptyMsg);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _OrderTile(order: orders[i]),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final OrderModel order;
  const _OrderTile({required this.order});

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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/vendor/order/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${order.id.substring(0, 8).toUpperCase()}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey),
                      ),
                      Text(order.buyerName,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(order.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    order.status.toUpperCase(),
                    style: TextStyle(
                        color: _statusColor(order.status),
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                order.items
                    .map((i) => '${i.foodName} ×${i.quantity}')
                    .join(', '),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(children: [
                Icon(
                  order.deliveryType == 'pickup'
                      ? Icons.store_rounded
                      : Icons.delivery_dining_rounded,
                  size: 14,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  order.deliveryType == 'pickup' ? 'Pickup' : 'Delivery',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
                if (order.deliveryType == 'delivery' &&
                    order.deliveryAddress != null) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.location_on, size: 12, color: Colors.grey),
                  Expanded(
                    child: Text(
                      order.deliveryAddress!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const Spacer(),
                Text(order.total.toCurrency(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary)),
              ]),
              Text(
                order.createdAt.toDisplay(),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
