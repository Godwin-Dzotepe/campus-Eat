import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../models/order_model.dart';
import '../../../core/widgets/firestore_error_view.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    final ordersAsync = ref.watch(buyerOrdersProvider);

    return ordersAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: FirestoreErrorView(error: e)),
      data: (allOrders) {
        final active =
            allOrders.where((o) => o.status != 'completed').toList();
        final past =
            allOrders.where((o) => o.status == 'completed').toList();

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('My Orders'),
              centerTitle: true,
              bottom: const TabBar(tabs: [
                Tab(text: 'Active'),
                Tab(text: 'Past'),
              ]),
            ),
            body: TabBarView(children: [
              _OrderList(orders: active, emptyMsg: 'No active orders'),
              _OrderList(orders: past, emptyMsg: 'No past orders'),
            ]),
          ),
        );
      },
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<OrderModel> orders;
  final String emptyMsg;
  const _OrderList({required this.orders, required this.emptyMsg});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return EmptyStateWidget(title: emptyMsg);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _OrderCard(order: orders[i]),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  Color _statusColor(String status) => switch (status) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${order.id.substring(0, 8).toUpperCase()}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey)),
                    Text(order.vendorBrandName,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(order.status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(order.status.toUpperCase(),
                    style: TextStyle(
                        color: _statusColor(order.status),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            const Divider(height: 14),
            Text(
              order.items.map((i) => '${i.foodName} ×${i.quantity}').join(', '),
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
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
              Text(order.deliveryType == 'pickup' ? 'Pickup' : 'Delivery',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey)),
              const Spacer(),
              Text(order.total.toCurrency(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary)),
            ]),
            const SizedBox(height: 4),
            Text(order.createdAt.toDisplay(),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
