import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_provider.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../models/user_model.dart';
import '../../../models/order_model.dart';
import '../../../models/food_model.dart';

class AdminUserDetailScreen extends ConsumerStatefulWidget {
  final String userId;
  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  ConsumerState<AdminUserDetailScreen> createState() =>
      _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState
    extends ConsumerState<AdminUserDetailScreen> {
  UserModel? _user;
  List<OrderModel> _orders = [];
  List<FoodModel> _foods = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = FirebaseFirestore.instance;
    final userDoc = await db.collection('users').doc(widget.userId).get();
    if (!userDoc.exists || !mounted) {
      setState(() => _loading = false);
      return;
    }
    final user = UserModel.fromMap(userDoc.id, userDoc.data()!);

    final ordersSnap = await db
        .collection('orders')
        .where(
            user.role == AppStrings.buyer ? 'buyerId' : 'vendorId',
            isEqualTo: widget.userId)
        .orderBy('createdAt', descending: true)
        .get();

    List<FoodModel> foods = [];
    if (user.role == AppStrings.vendor) {
      final foodsSnap = await db
          .collection('foods')
          .where('vendorId', isEqualTo: widget.userId)
          .get();
      foods = foodsSnap.docs
          .map((d) => FoodModel.fromMap(d.id, d.data()))
          .toList();
    }

    if (!mounted) return;
    setState(() {
      _user = user;
      _orders = ordersSnap.docs
          .map((d) => OrderModel.fromMap(d.id, d.data()))
          .toList();
      _foods = foods;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    final user = _user;
    if (user == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('User not found')));
    }

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(user.name),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Delete User?'),
                content:
                    Text('Delete ${user.name}? This cannot be undone.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await AdminActions.deleteUser(widget.userId);
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.red),
                    child: const Text('Delete'),
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
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(user.name[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(user.email,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey)),
                      const SizedBox(height: 4),
                      Row(children: [
                        _Badge(user.role.toUpperCase(),
                            theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        _Badge(
                          user.isActive ? 'ACTIVE' : 'INACTIVE',
                          user.isActive ? Colors.green : Colors.red,
                        ),
                      ]),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          if (user.role == AppStrings.vendor) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  _InfoRow('Brand', user.brandName ?? '—'),
                  _InfoRow('Referral', user.referralCode ?? '—'),
                  _InfoRow('Contact', user.contactNumber ?? '—'),
                  _InfoRow('Delivery Fee',
                      (user.deliveryFee ?? 0).toCurrency()),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Text('Menu (${_foods.length} items)',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._foods.map((f) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    title: Text(f.name),
                    subtitle:
                        Text('${f.category} • ${f.price.toCurrency()}'),
                    trailing: Text(f.isAvailable ? '✅' : '❌'),
                  ),
                )),
          ],
          const SizedBox(height: 12),
          Text('Orders (${_orders.length})',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_orders.isEmpty)
            const Text('No orders', style: TextStyle(color: Colors.grey))
          else
            ..._orders.take(10).map((o) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    title: Text(
                        '#${o.id.substring(0, 8).toUpperCase()} — ${o.vendorBrandName}'),
                    subtitle: Text(o.createdAt.toDisplay()),
                    trailing: Text(o.total.toCurrency(),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary)),
                  ),
                )),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text('$label: ',
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
