import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/food_model.dart';
import '../../../models/cart_item_model.dart';
import '../providers/cart_provider.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/constants/app_colors.dart';

class FoodCard extends ConsumerWidget {
  final FoodModel food;

  const FoodCard({super.key, required this.food});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.push('/buyer/food/${food.id}'),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _FoodImage(imagePath: food.imagePath),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        food.category,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    food.vendorBrandName,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          food.price.toCurrency(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary),
                        ),
                      ),
                      if (food.reviewCount > 0)
                        Row(children: [
                          const Icon(Icons.star_rounded,
                              size: 14, color: AppColors.starColor),
                          Text(
                            food.averageRating.toStringAsFixed(1),
                            style: theme.textTheme.bodySmall,
                          ),
                        ]),
                      const SizedBox(width: 4),
                      _AddButton(food: food),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends ConsumerWidget {
  final FoodModel food;
  const _AddButton({required this.food});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final inCart = cart.any((i) => i.foodId == food.id);
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () async {
        final currentVendor = ref.read(cartProvider.notifier).currentVendorId;
        if (currentVendor != null && currentVendor != food.vendorId) {
          final brandName = cart.first.vendorBrandName;
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Replace Cart?'),
              content: Text(
                  'Your cart has items from $brandName. Clear it and add from ${food.vendorBrandName}?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    await ref.read(cartProvider.notifier).clear();
                    await ref.read(cartProvider.notifier).addItem(CartItemModel(
                          foodId: food.id,
                          foodName: food.name,
                          price: food.price,
                          quantity: 1,
                          vendorId: food.vendorId,
                          vendorBrandName: food.vendorBrandName,
                          imagePath: food.imagePath,
                        ));
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Replace'),
                ),
              ],
            ),
          );
          return;
        }
        await ref.read(cartProvider.notifier).addItem(CartItemModel(
              foodId: food.id,
              foodName: food.name,
              price: food.price,
              quantity: 1,
              vendorId: food.vendorId,
              vendorBrandName: food.vendorBrandName,
              imagePath: food.imagePath,
            ));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color:
              inCart ? theme.colorScheme.primary : theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          inCart ? Icons.check : Icons.add,
          size: 16,
          color: inCart ? Colors.white : theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _FoodImage extends StatelessWidget {
  final String? imagePath;
  const _FoodImage({this.imagePath});

  @override
  Widget build(BuildContext context) {
    if (imagePath != null && imagePath!.startsWith('http')) {
      return Image.network(
        imagePath!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(context),
      );
    }
    if (imagePath != null) {
      return Image.file(
        File(imagePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(context),
      );
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Text('🍽️', style: TextStyle(fontSize: 48)),
      ),
    );
  }
}
