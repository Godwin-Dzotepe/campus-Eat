import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/vendor_provider.dart';
import '../providers/vendor_orders_provider.dart';
import '../../../core/utils/extensions.dart';
import '../../../models/food_model.dart';
import '../../../core/widgets/firestore_error_view.dart';
import '../../../core/services/write_log_service.dart';

class VendorDashboardScreen extends ConsumerWidget {
  const VendorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendor = ref.watch(effectiveVendorProvider);
    final foodsAsync = ref.watch(vendorFoodsProvider);
    final ordersAsync = ref.watch(vendorOrdersProvider);
    final theme = Theme.of(context);

    if (vendor == null) return const SizedBox.shrink();
    if (foodsAsync.isLoading || ordersAsync.isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (foodsAsync.hasError) {
      return Scaffold(
          body: FirestoreErrorView(error: foodsAsync.error!));
    }
    if (ordersAsync.hasError) {
      return Scaffold(
          body: FirestoreErrorView(error: ordersAsync.error!));
    }

    final foods = foodsAsync.valueOrNull ?? [];
    final orders = ordersAsync.valueOrNull ?? [];

    final pendingOrders = orders.where((o) => o.status == 'placed').length;
    final revenue =
        orders.where((o) => o.isPaid).fold(0.0, (s, o) => s + o.total);

    return Scaffold(
      appBar: AppBar(
        title: Text(vendor.brandName ?? 'Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push('/vendor/add-food'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vendor.brandName ?? '—',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.qr_code, size: 14),
                    const SizedBox(width: 6),
                    Text(vendor.referralCode ?? '—',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.phone, size: 14),
                    const SizedBox(width: 6),
                    Text(vendor.contactNumber ?? '—',
                        style: theme.textTheme.bodySmall),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _StatCard(
                    label: 'Total Orders',
                    value: '${orders.length}',
                    icon: Icons.receipt_long_rounded,
                    color: Colors.blue)),
            const SizedBox(width: 12),
            Expanded(
                child: _StatCard(
                    label: 'Pending',
                    value: '$pendingOrders',
                    icon: Icons.pending_rounded,
                    color: Colors.orange)),
            const SizedBox(width: 12),
            Expanded(
                child: _StatCard(
                    label: 'Revenue',
                    value: revenue.toCurrency(),
                    icon: Icons.attach_money_rounded,
                    color: Colors.green)),
          ]),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Your Menu',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              TextButton.icon(
                onPressed: () => context.push('/vendor/add-food'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Item'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (foods.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('No menu items yet. Add your first item!',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...foods.map((f) => _VendorFoodTile(food: f)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/vendor/add-food'),
        icon: const Icon(Icons.add),
        label: const Text('Add Food'),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _VendorFoodTile extends ConsumerWidget {
  final FoodModel food;
  const _VendorFoodTile({required this.food});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 52,
            height: 52,
            child: food.imageUrl != null
                ? Image.network(food.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.fastfood_rounded,
                            color: Colors.grey)))
                : Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.fastfood_rounded,
                        color: Colors.grey)),
          ),
        ),
        title: Text(food.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${food.category} • ${food.price.toCurrency()}',
            style: const TextStyle(fontSize: 12)),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'edit') {
              context.push('/vendor/edit-food/${food.id}');
            } else if (v == 'toggle') {
              await WriteLogService.capture(
                action: 'Toggle food availability',
                target: 'foods/${food.id}',
                task: () => FirebaseFirestore.instance
                    .collection('foods')
                    .doc(food.id)
                    .update({'isAvailable': !food.isAvailable}),
              );
            } else if (v == 'delete') {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete Item?'),
                  content: Text('Remove ${food.name} from your menu?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style:
                          FilledButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await WriteLogService.capture(
                  action: 'Delete food item',
                  target: 'foods/${food.id}',
                  task: () => FirebaseFirestore.instance
                      .collection('foods')
                      .doc(food.id)
                      .delete(),
                );
              }
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(
                value: 'toggle',
                child: Text(food.isAvailable
                    ? 'Mark Unavailable'
                    : 'Mark Available')),
            const PopupMenuItem(
                value: 'delete',
                child:
                    Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }
}
