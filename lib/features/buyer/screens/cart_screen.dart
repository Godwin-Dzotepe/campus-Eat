import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/cart_provider.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/empty_state_widget.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final isLoading = ref.watch(cartLoadingProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Clear Cart?'),
                  content: const Text('Remove all items from cart?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () async {
                        await notifier.clear();
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
              child: const Text('Clear'),
            ),
        ],
      ),
        body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? EmptyStateWidget(
              title: 'Your cart is empty',
              subtitle: 'Browse food and add items to your cart',
              onAction: () => context.go('/buyer/home'),
              actionLabel: 'Browse Food',
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 60,
                                height: 60,
                                child: _CartImage(
                                  imagePath: item.imagePath,
                                  placeholderColor: theme
                                      .colorScheme.surfaceContainerHighest,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.foodName,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600)),
                                  Text(item.vendorBrandName,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              color:
                                                  theme.colorScheme.primary)),
                                  Text(item.price.toCurrency(),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: Colors.grey)),
                                ],
                              ),
                            ),
                            Row(children: [
                              _QtyBtn(
                                  icon: Icons.remove,
                                  onTap: () => notifier.updateQuantity(
                                      item.foodId, item.quantity - 1)),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('${item.quantity}',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700)),
                              ),
                              _QtyBtn(
                                  icon: Icons.add,
                                  onTap: () => notifier.updateQuantity(
                                      item.foodId, item.quantity + 1)),
                            ]),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
                _CartSummary(
                  subtotal: notifier.subtotal,
                  onCheckout: () => context.push('/buyer/checkout'),
                ),
              ],
            ),
    );
  }
}

class _CartImage extends StatelessWidget {
  final String? imagePath;
  final Color placeholderColor;

  const _CartImage({this.imagePath, required this.placeholderColor});

  @override
  Widget build(BuildContext context) {
    if (imagePath != null && imagePath!.startsWith('http')) {
      return Image.network(
        imagePath!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    if (imagePath != null && File(imagePath!).existsSync()) {
      return Image.file(File(imagePath!), fit: BoxFit.cover);
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: placeholderColor,
      child: const Icon(Icons.fastfood_rounded, color: Colors.grey),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  final double subtotal;
  final VoidCallback onCheckout;
  const _CartSummary({required this.subtotal, required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: const [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.grey)),
              Text(subtotal.toCurrency(),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onCheckout,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Proceed to Checkout',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
