import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/cart_item_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/services/write_log_service.dart';

final cartProvider =
    StateNotifierProvider<CartNotifier, List<CartItemModel>>(
        (ref) => CartNotifier(ref));
final cartLoadingProvider = StateProvider<bool>((ref) => true);

class CartNotifier extends StateNotifier<List<CartItemModel>> {
  final Ref _ref;
  final _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  String? _userId;
  bool _initialLoadComplete = false;

  CartNotifier(this._ref) : super([]) {
    _ref.listen(authProvider.select((a) => a.valueOrNull), (prev, next) {
      if (prev?.id != next?.id) {
        if (mounted) _bindUser(next?.id);
      }
    });
    // Defer initial binding to avoid mutating provider state during build.
    Future.microtask(() {
      if (!mounted) return;
      _bindUser(_ref.read(authProvider).valueOrNull?.id);
    });
  }

  bool get isEmpty => state.isEmpty;
  String? get currentVendorId => state.isEmpty ? null : state.first.vendorId;

  double get subtotal =>
      state.fold(0, (acc, i) => acc + i.price * i.quantity);
  int get totalItems => state.fold(0, (acc, i) => acc + i.quantity);

  void _bindUser(String? userId) {
    _sub?.cancel();
    _userId = userId;
    _initialLoadComplete = false;
    if (userId == null) {
      _ref.read(cartLoadingProvider.notifier).state = false;
      state = [];
      return;
    }
    _ref.read(cartLoadingProvider.notifier).state = true;
    _sub = _db
        .collection('users')
        .doc(userId)
        .collection('cart')
        .snapshots()
        .listen(
      (snap) {
        if (!_initialLoadComplete) {
          _initialLoadComplete = true;
          _ref.read(cartLoadingProvider.notifier).state = false;
        }
        state = snap.docs
            .map((d) => CartItemModel.fromMap(d.data()))
            .toList();
      },
      onError: (_) {},
    );
  }

  Future<void> addItem(CartItemModel item) async {
    if (_userId == null) return;
    final existing = state.where((i) => i.foodId == item.foodId).toList();
    final quantity = existing.isEmpty
        ? item.quantity
        : existing.first.quantity + item.quantity;
    final data = item.toMap()..['quantity'] = quantity;
    await WriteLogService.capture(
      action: 'Cart add item',
      target: 'users/$_userId/cart/${item.foodId}',
      task: () => _db
          .collection('users')
          .doc(_userId)
          .collection('cart')
          .doc(item.foodId)
          .set(data),
    );
  }

  Future<void> removeItem(String foodId) async {
    if (_userId == null) return;
    await WriteLogService.capture(
      action: 'Cart remove item',
      target: 'users/$_userId/cart/$foodId',
      task: () => _db
          .collection('users')
          .doc(_userId)
          .collection('cart')
          .doc(foodId)
          .delete(),
    );
  }

  Future<void> updateQuantity(String foodId, int qty) async {
    if (_userId == null) return;
    if (qty <= 0) {
      await removeItem(foodId);
      return;
    }
    await WriteLogService.capture(
      action: 'Cart update quantity',
      target: 'users/$_userId/cart/$foodId',
      task: () => _db
          .collection('users')
          .doc(_userId)
          .collection('cart')
          .doc(foodId)
          .update({'quantity': qty}),
    );
  }

  Future<void> clear() async {
    if (_userId == null) return;
    final batch = _db.batch();
    final col = _db.collection('users').doc(_userId).collection('cart');
    for (final item in state) {
      batch.delete(col.doc(item.foodId));
    }
    await WriteLogService.capture(
      action: 'Cart clear',
      target: 'users/$_userId/cart',
      task: () => batch.commit(),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
