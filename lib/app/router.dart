import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants/app_strings.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/buyer/screens/buyer_shell.dart';
import '../features/buyer/screens/home_screen.dart';
import '../features/buyer/screens/cart_screen.dart';
import '../features/buyer/screens/orders_screen.dart';
import '../features/buyer/screens/profile_screen.dart';
import '../features/buyer/screens/food_detail_screen.dart';
import '../features/buyer/screens/checkout_screen.dart';
import '../features/buyer/screens/location_picker_screen.dart';
import '../features/buyer/screens/payment_screen.dart';
import '../features/buyer/screens/order_success_screen.dart';
import '../features/vendor/screens/vendor_shell.dart';
import '../features/vendor/screens/vendor_dashboard_screen.dart';
import '../features/vendor/screens/vendor_orders_screen.dart';
import '../features/vendor/screens/vendor_profile_screen.dart';
import '../features/vendor/screens/add_food_screen.dart';
import '../features/vendor/screens/edit_food_screen.dart';
import '../features/vendor/screens/vendor_order_detail_screen.dart';
import '../features/admin/screens/admin_shell.dart';
import '../features/admin/screens/admin_dashboard_screen.dart';
import '../features/admin/screens/admin_users_screen.dart';
import '../features/admin/screens/admin_orders_screen.dart';
import '../features/admin/screens/admin_stats_screen.dart';
import '../features/admin/screens/admin_user_detail_screen.dart';
import '../core/debug/debug_logs_screen.dart';
import '../models/order_model.dart';

/// Bridges Firebase Auth stream and user model to GoRouter's refreshListenable.
class _RouterRefreshStream extends ChangeNotifier {
  _RouterRefreshStream(Ref ref) {
    _sub = FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
    // Also notify when the user document is loaded/changed
    ref.listen(authProvider, (_, __) => notifyListeners());
  }

  late final StreamSubscription<User?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshStream = _RouterRefreshStream(ref);
  ref.onDispose(refreshStream.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshStream,
    redirect: (context, state) async {
      final prefs = Hive.box(AppStrings.prefsBox);
      final onboardingDone =
          prefs.get(AppStrings.onboardingDone, defaultValue: false) as bool;

      if (!onboardingDone) {
        if (state.matchedLocation == '/onboarding') return null;
        return '/onboarding';
      }

      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser == null) {
        if (state.matchedLocation.startsWith('/auth')) return null;
        return '/auth/login';
      }

      // Read the current user model from the stream cache.
      final userAsync = ref.read(authProvider);
      final user = userAsync.valueOrNull;
      if (user == null) return null; // still loading

      // Admin impersonation
      if (user.role == AppStrings.admin &&
          user.impersonatingVendorId != null) {
        if (state.matchedLocation.startsWith('/vendor')) return null;
        return '/vendor/dashboard';
      }

      if (state.matchedLocation.startsWith('/auth')) {
        if (user.role == AppStrings.buyer) return '/buyer/home';
        if (user.role == AppStrings.vendor) return '/vendor/dashboard';
        if (user.role == AppStrings.admin) return '/admin/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, __) => '/onboarding'),
      GoRoute(
          path: '/onboarding',
          builder: (_, __) => const OnboardingScreen()),
      GoRoute(
          path: '/auth/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: '/auth/register',
          builder: (_, __) => const RegisterScreen()),

      // Buyer shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            BuyerShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/buyer/home',
                builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/buyer/cart',
                builder: (_, __) => const CartScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/buyer/orders',
                builder: (_, __) => const OrdersScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/buyer/profile',
                builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),

      GoRoute(
        path: '/buyer/food/:foodId',
        builder: (context, state) =>
            FoodDetailScreen(foodId: state.pathParameters['foodId']!),
      ),
      GoRoute(
          path: '/buyer/checkout',
          builder: (_, __) => const CheckoutScreen()),
      GoRoute(
          path: '/buyer/location',
          builder: (_, __) => const LocationPickerScreen()),
      GoRoute(
        path: '/buyer/payment',
        builder: (_, state) => PaymentScreen(
          checkoutArgs: state.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(
        path: '/buyer/success',
        builder: (context, state) =>
            OrderSuccessScreen(order: state.extra as OrderModel?),
      ),

      // Vendor shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            VendorShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/vendor/dashboard',
                builder: (_, __) => const VendorDashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/vendor/orders',
                builder: (_, __) => const VendorOrdersScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/vendor/profile',
                builder: (_, __) => const VendorProfileScreen()),
          ]),
        ],
      ),

      GoRoute(
          path: '/vendor/add-food',
          builder: (_, __) => const AddFoodScreen()),
      GoRoute(
        path: '/vendor/edit-food/:foodId',
        builder: (context, state) =>
            EditFoodScreen(foodId: state.pathParameters['foodId']!),
      ),
      GoRoute(
        path: '/vendor/order/:orderId',
        builder: (context, state) =>
            VendorOrderDetailScreen(
                orderId: state.pathParameters['orderId']!),
      ),

      // Admin shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            AdminShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/admin/dashboard',
                builder: (_, __) => const AdminDashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/admin/users',
                builder: (_, __) => const AdminUsersScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/admin/orders',
                builder: (_, __) => const AdminOrdersScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/admin/stats',
                builder: (_, __) => const AdminStatsScreen()),
          ]),
        ],
      ),

      GoRoute(
        path: '/admin/user/:userId',
        builder: (context, state) =>
            AdminUserDetailScreen(
                userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: '/admin/debug-logs',
        builder: (_, __) => const DebugLogsScreen(),
      ),
    ],
  );
});
