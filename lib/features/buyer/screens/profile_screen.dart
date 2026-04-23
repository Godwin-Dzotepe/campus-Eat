import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/buyer/providers/order_provider.dart';
import '../../../features/buyer/providers/address_provider.dart';
import '../../../app/theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/firestore_error_view.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final ordersAsync = ref.watch(buyerOrdersProvider);
    final orders = ordersAsync.valueOrNull ?? [];
    final savedAsync = ref.watch(savedAddressesProvider);
    final saved = savedAsync.valueOrNull ?? [];
    final walletBalance = user.walletBalance ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
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
          Center(
            child: Column(children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  user.name[0].toUpperCase(),
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 12),
              Text(user.name,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(user.email,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.grey)),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Buyer',
                    style: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
              ),
            ]),
          ),
          const SizedBox(height: 24),
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
          if (ordersAsync.hasError) const SizedBox(height: 24),
          Row(children: [
            Expanded(
                child: _StatCard(label: 'Orders', value: '${orders.length}')),
            const SizedBox(width: 12),
            Expanded(
                child: _StatCard(
                    label: 'Wallet', value: walletBalance.toCurrency())),
            const SizedBox(width: 12),
            Expanded(
                child: _StatCard(
                    label: 'Completed',
                    value:
                        '${orders.where((o) => o.status == 'completed').length}')),
          ]),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Saved Addresses',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              if (saved.isNotEmpty)
                TextButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Clear saved addresses?'),
                      content: const Text('This will remove all saved addresses.'),
                      actions: [
                        TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(),
                            child: const Text('Cancel')),
                        FilledButton(
                          onPressed: () async {
                            Navigator.of(dialogContext).pop();
                            await AddressActions.clearAll(
                                userId: user.id, addresses: saved);
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('Clear All'),
                ),
            ],
          ),
          if (savedAsync.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (savedAsync.hasError)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FirestoreErrorView(
                  error: savedAsync.error!,
                  title: 'Addresses unavailable',
                ),
              ),
            )
          else if (saved.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No saved addresses',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            ...saved.map((address) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(address.label),
                    subtitle: Text(address.fullAddress,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: address.id == null
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => AddressActions.deleteAddress(
                              userId: user.id,
                              addressId: address.id!,
                            ),
                          ),
                  ),
                )),
          const SizedBox(height: 16),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            label: 'Dark Mode',
            trailing: Switch(
              value: themeMode == ThemeMode.dark,
              onChanged: (_) =>
                  ref.read(themeModeProvider.notifier).toggle(),
            ),
          ),
          _SettingsTile(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              onTap: () {}),
          _SettingsTile(
              icon: Icons.help_outline_rounded,
              label: 'Help & Support',
              onTap: () {}),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.logout_rounded,
            label: 'Logout',
            color: Colors.red,
            onTap: () => showDialog(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Logout?'),
                content: const Text('Are you sure you want to logout?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancel')),
                  FilledButton(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
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
          const SizedBox(height: 32),
          Center(
            child: Text('Campus Eat v1.0',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
          ),
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(children: [
          Text(value,
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? color;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label,
          style: TextStyle(fontWeight: FontWeight.w500, color: color)),
      trailing:
          trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
