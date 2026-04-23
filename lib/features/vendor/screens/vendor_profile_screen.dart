import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/vendor_provider.dart';
import '../providers/vendor_orders_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../app/theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/firestore_error_view.dart';
import '../../../core/services/write_log_service.dart';

class VendorProfileScreen extends ConsumerStatefulWidget {
  const VendorProfileScreen({super.key});

  @override
  ConsumerState<VendorProfileScreen> createState() =>
      _VendorProfileScreenState();
}

class _VendorProfileScreenState
    extends ConsumerState<VendorProfileScreen> {
  final _deliveryFeeCtrl = TextEditingController();
  bool _editingFee = false;

  @override
  void dispose() {
    _deliveryFeeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vendor = ref.watch(effectiveVendorProvider);
    final ordersAsync = ref.watch(vendorOrdersProvider);
    final orders = ordersAsync.valueOrNull ?? [];
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);

    if (vendor == null) return const SizedBox.shrink();

    final revenue =
        orders.where((o) => o.isPaid).fold(0.0, (s, o) => s + o.total);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(themeMode == ThemeMode.dark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded),
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Brand card
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      (vendor.brandName ?? vendor.name)[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    vendor.brandName ?? vendor.name,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(vendor.email,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (ordersAsync.hasError)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FirestoreErrorView(
                  error: ordersAsync.error!,
                  title: 'Orders unavailable',
                ),
              ),
            ),
          if (ordersAsync.hasError) const SizedBox(height: 16),

          // Stats
          Row(children: [
            Expanded(
                child: _StatCard(
                    label: 'Orders', value: '${orders.length}')),
            const SizedBox(width: 12),
            Expanded(
                child:
                    _StatCard(label: 'Revenue', value: revenue.toCurrency())),
          ]),
          const SizedBox(height: 20),

          // Store info
          _InfoTile(
            icon: Icons.qr_code,
            label: 'Referral Code',
            value: vendor.referralCode ?? '—',
          ),
          _InfoTile(
            icon: Icons.phone,
            label: 'Contact',
            value: vendor.contactNumber ?? '—',
          ),

          // Delivery fee setting
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.delivery_dining_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('Delivery Fee',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (!_editingFee)
                      Text(
                        (vendor.deliveryFee ?? 0).toCurrency(),
                        style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                          _editingFee ? Icons.check_rounded : Icons.edit_rounded,
                          size: 18),
                      onPressed: () async {
                        if (_editingFee) {
                          final fee = double.tryParse(_deliveryFeeCtrl.text);
                          if (fee != null) {
                            await WriteLogService.capture(
                              action: 'Update delivery fee',
                              target: 'users/${vendor.id}',
                              task: () => FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(vendor.id)
                                  .update({'deliveryFee': fee}),
                            );
                          }
                        } else {
                          _deliveryFeeCtrl.text =
                              (vendor.deliveryFee ?? 0).toString();
                        }
                        setState(() => _editingFee = !_editingFee);
                      },
                    ),
                  ]),
                  if (_editingFee) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _deliveryFeeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Fee (GH₵)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        prefixText: 'GH₵ ',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          ListTile(
            leading: Switch(
              value: themeMode == ThemeMode.dark,
              onChanged: (_) =>
                  ref.read(themeModeProvider.notifier).toggle(),
            ),
            title: const Text('Dark Mode'),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text('Logout',
                style: TextStyle(color: Colors.red)),
            trailing: const Icon(Icons.chevron_right),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            onTap: () => showDialog(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Logout?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancel')),
                  FilledButton(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      await ref.read(authActionsProvider).logout();
                    },
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.red),
                    child: const Text('Logout'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(children: [
          Text(value,
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(label,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
        ]),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label,
            style: const TextStyle(
                fontSize: 12, color: Colors.grey)),
        subtitle: Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
