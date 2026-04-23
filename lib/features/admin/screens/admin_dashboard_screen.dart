import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/admin_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../app/theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../models/order_model.dart';
import '../../../core/widgets/firestore_error_view.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final ordersAsync = ref.watch(allOrdersProvider);
    final themeMode = ref.watch(themeModeProvider);
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

    final buyers = users.where((u) => u.role == 'buyer').length;
    final vendors = users.where((u) => u.role == 'vendor').length;
    final revenue =
        orders.where((o) => o.isPaid).fold(0.0, (s, o) => s + o.total);
    final pending = orders.where((o) => o.status == 'placed').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: () => context.push('/admin/debug-logs'),
            tooltip: 'Write logs',
          ),
          IconButton(
            icon: Icon(themeMode == ThemeMode.dark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded),
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Logout?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await ref.read(authActionsProvider).logout();
                    },
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Logout'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Overview',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _StatTile(
                  label: 'Total Users',
                  value: '${users.length}',
                  icon: Icons.people_rounded,
                  color: Colors.blue),
              _StatTile(
                  label: 'Vendors',
                  value: '$vendors',
                  icon: Icons.storefront_rounded,
                  color: Colors.orange),
              _StatTile(
                  label: 'Buyers',
                  value: '$buyers',
                  icon: Icons.shopping_bag_rounded,
                  color: Colors.green),
              _StatTile(
                  label: 'Total Orders',
                  value: '${orders.length}',
                  icon: Icons.receipt_long_rounded,
                  color: Colors.purple),
              _StatTile(
                  label: 'Revenue',
                  value: revenue.toCurrency(),
                  icon: Icons.attach_money_rounded,
                  color: Colors.teal),
              _StatTile(
                  label: 'Pending',
                  value: '$pending',
                  icon: Icons.pending_rounded,
                  color: Colors.red),
            ],
          ),
          const SizedBox(height: 24),
          Text('Recent Orders',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...orders.take(5).map((o) => _RecentOrderTile(order: o)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value,
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700, color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(label,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  final OrderModel order;
  const _RecentOrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
            '#${order.id.substring(0, 8).toUpperCase()} — ${order.vendorBrandName}'),
        subtitle:
            Text('${order.buyerName} • ${order.createdAt.toDateOnly()}'),
        trailing: Text(order.total.toCurrency(),
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary)),
      ),
    );
  }
}
