import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/constants/app_strings.dart';

class VendorShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const VendorShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final isImpersonating = user?.role == AppStrings.admin &&
        user?.impersonatingVendorId != null;

    return Scaffold(
      body: Column(
        children: [
          if (isImpersonating)
            _ImpersonationBanner(
              onExit: () async {
                await ref.read(authActionsProvider).logout();
                if (context.mounted) context.go('/auth/login');
              },
            ),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            selectedIcon: Icon(Icons.manage_accounts_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ImpersonationBanner extends StatelessWidget {
  final VoidCallback onExit;
  const _ImpersonationBanner({required this.onExit});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.red.shade700,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            const Icon(Icons.visibility_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Admin view — viewing as vendor',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: onExit,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('EXIT',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ]),
        ),
      ),
    );
  }
}
