import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cart_provider.dart';

class CartBadge extends ConsumerWidget {
  final VoidCallback? onTap;

  const CartBadge({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartProvider.select((s) => s.fold(0, (a, i) => a + i.quantity)));
    return IconButton(
      onPressed: onTap,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count', style: const TextStyle(fontSize: 10)),
        child: const Icon(Icons.shopping_cart_outlined),
      ),
    );
  }
}
