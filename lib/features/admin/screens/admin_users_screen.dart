import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/admin_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../models/user_model.dart';
import '../../../core/widgets/firestore_error_view.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _filter = 'all';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    final users = usersAsync.valueOrNull ?? [];

    final filtered = users.where((u) {
      if (u.role == AppStrings.admin) return false;
      final matchesRole = _filter == 'all' || u.role == _filter;
      final matchesSearch = _search.isEmpty ||
          u.name.toLowerCase().contains(_search.toLowerCase()) ||
          u.email.toLowerCase().contains(_search.toLowerCase());
      return matchesRole && matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Users'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SearchBar(
              hintText: 'Search users...',
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _search = v),
              padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 16)),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _FilterChip(
                  label: 'All',
                  value: 'all',
                  current: _filter,
                  onTap: (v) => setState(() => _filter = v)),
              const SizedBox(width: 8),
              _FilterChip(
                  label: '🛍 Buyers',
                  value: 'buyer',
                  current: _filter,
                  onTap: (v) => setState(() => _filter = v)),
              const SizedBox(width: 8),
              _FilterChip(
                  label: '🏪 Vendors',
                  value: 'vendor',
                  current: _filter,
                  onTap: (v) => setState(() => _filter = v)),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: usersAsync.isLoading
                ? const Center(child: CircularProgressIndicator())
              : usersAsync.hasError
                ? FirestoreErrorView(error: usersAsync.error!)
                : filtered.isEmpty
                    ? const Center(child: Text('No users found'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) =>
                            _UserCard(user: filtered[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final void Function(String) onTap;
  const _FilterChip(
      {required this.label,
      required this.value,
      required this.current,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: current == value,
      onSelected: (_) => onTap(value),
    );
  }
}

class _UserCard extends ConsumerWidget {
  final UserModel user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final adminUser = ref.read(authProvider).valueOrNull;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(user.name[0].toUpperCase(),
                    style: TextStyle(color: theme.colorScheme.primary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    Text(user.email,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: user.role == AppStrings.vendor
                      ? Colors.orange.withValues(alpha: 0.15)
                      : Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user.role.toUpperCase(),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: user.role == AppStrings.vendor
                          ? Colors.orange
                          : Colors.blue),
                ),
              ),
            ]),
            if (user.role == AppStrings.vendor && user.brandName != null) ...[
              const SizedBox(height: 6),
              Text('🏪 ${user.brandName}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.primary)),
            ],
            const SizedBox(height: 10),
            Row(children: [
              OutlinedButton.icon(
                onPressed: () => context.push('/admin/user/${user.id}'),
                icon: const Icon(Icons.info_outline, size: 14),
                label: const Text('Details'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              if (user.role == AppStrings.vendor) ...[
                OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Enter Account?'),
                        content: Text(
                            'View ${user.brandName ?? user.name}\'s dashboard as admin.'),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          FilledButton(
                              onPressed: () =>
                                  Navigator.pop(context, true),
                              child: const Text('Enter')),
                        ],
                      ),
                    );
                    if (confirm == true && adminUser != null) {
                      await AdminActions.impersonateVendor(
                          user.id, adminUser.id);
                      if (context.mounted) context.go('/vendor/dashboard');
                    }
                  },
                  icon: const Icon(Icons.login_rounded, size: 14),
                  label: const Text('Enter Account'),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              IconButton(
                icon: Icon(
                  user.isActive
                      ? Icons.toggle_on_rounded
                      : Icons.toggle_off_rounded,
                  color: user.isActive ? Colors.green : Colors.grey,
                  size: 28,
                ),
                onPressed: () => AdminActions.toggleUserActive(user.id),
                tooltip: user.isActive ? 'Deactivate' : 'Activate',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete User?'),
                    content: Text(
                        'Permanently delete ${user.name}? This cannot be undone.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      FilledButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await AdminActions.deleteUser(user.id);
                        },
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ),
                tooltip: 'Delete',
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
