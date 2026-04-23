import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_provider.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/firestore_error_view.dart';

class AdminStatsScreen extends ConsumerWidget {
  const AdminStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final ordersAsync = ref.watch(allOrdersProvider);
    final theme = Theme.of(context);

    if (usersAsync.isLoading || ordersAsync.isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (usersAsync.hasError) {
      return Scaffold(body: FirestoreErrorView(error: usersAsync.error!));
    }
    if (ordersAsync.hasError) {
      return Scaffold(body: FirestoreErrorView(error: ordersAsync.error!));
    }

    final users = usersAsync.valueOrNull ?? [];
    final orders = ordersAsync.valueOrNull ?? [];

    final buyers = users.where((u) => u.role == AppStrings.buyer).toList();
    final vendors = users.where((u) => u.role == AppStrings.vendor).toList();
    final totalRevenue =
        orders.where((o) => o.isPaid).fold(0.0, (s, o) => s + o.total);
    final deliveryOrders =
        orders.where((o) => o.deliveryType == 'delivery').length;
    final pickupOrders =
        orders.where((o) => o.deliveryType == 'pickup').length;

    // Top vendors by revenue
    final vendorRevenue = <String, double>{};
    for (final o in orders.where((o) => o.isPaid)) {
      vendorRevenue[o.vendorBrandName] =
          (vendorRevenue[o.vendorBrandName] ?? 0) + o.total;
    }
    final topVendors = vendorRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: const Text('Stats'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Platform Summary',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _StatRow('Total Revenue', totalRevenue.toCurrency(),
              icon: Icons.attach_money_rounded, color: Colors.green),
          _StatRow('Total Orders', '${orders.length}',
              icon: Icons.receipt_long_rounded, color: Colors.blue),
          _StatRow('Total Buyers', '${buyers.length}',
              icon: Icons.people_rounded, color: Colors.purple),
          _StatRow('Total Vendors', '${vendors.length}',
              icon: Icons.storefront_rounded, color: Colors.orange),
          _StatRow('Delivery Orders', '$deliveryOrders',
              icon: Icons.delivery_dining_rounded, color: Colors.teal),
          _StatRow('Pickup Orders', '$pickupOrders',
              icon: Icons.store_rounded, color: Colors.brown),

          const SizedBox(height: 24),
          if (topVendors.isNotEmpty) ...[
            Text('Top Vendors by Revenue',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...topVendors.take(5).map((e) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          theme.colorScheme.primaryContainer,
                      child: Text(e.key[0].toUpperCase(),
                          style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700)),
                    ),
                    title: Text(e.key,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Text(e.value.toCurrency(),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary)),
                  ),
                )),
          ],

          const SizedBox(height: 24),
          Text('Recent Buyers',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...buyers.take(5).map((u) => Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(u.name[0].toUpperCase()),
                  ),
                  title: Text(u.name),
                  subtitle: Text(u.email),
                  trailing: Text(
                    u.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                        color: u.isActive ? Colors.green : Colors.red,
                        fontSize: 12),
                  ),
                ),
              )),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatRow(this.label, this.value,
      {required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(label),
        trailing: Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: color,
                fontSize: 15)),
      ),
    );
  }
}
