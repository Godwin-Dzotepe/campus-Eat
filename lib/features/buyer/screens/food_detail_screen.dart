import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../providers/cart_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/food_model.dart';
import '../../../models/cart_item_model.dart';
import '../../../models/review_model.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/write_log_service.dart';

class FoodDetailScreen extends ConsumerStatefulWidget {
  final String foodId;
  const FoodDetailScreen({super.key, required this.foodId});

  @override
  ConsumerState<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends ConsumerState<FoodDetailScreen> {
  int _quantity = 1;
  int _reviewRating = 5;
  final _reviewCtrl = TextEditingController();
  FoodModel? _food;
  List<ReviewModel> _reviews = [];
  bool _canReview = false;
  bool _hasReviewed = false;
  bool _loading = true;

  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = ref.read(authProvider).valueOrNull;
    final foodDoc =
        await _db.collection('foods').doc(widget.foodId).get();
    final reviewSnap = await _db
        .collection('reviews')
        .where('foodId', isEqualTo: widget.foodId)
        .orderBy('createdAt', descending: true)
        .get();

    bool canReview = false;
    bool hasReviewed = false;

    if (user != null) {
      final orderSnap = await _db
          .collection('orders')
          .where('buyerId', isEqualTo: user.id)
          .where('status', isEqualTo: 'completed')
          .get();
      canReview = orderSnap.docs.any((d) {
        final items = (d.data()['items'] as List? ?? []);
        return items.any((i) => i['foodId'] == widget.foodId);
      });
      hasReviewed =
          reviewSnap.docs.any((d) => d.data()['buyerId'] == user.id);
    }

    if (!mounted) return;
    setState(() {
      _food = foodDoc.exists
          ? FoodModel.fromMap(foodDoc.id, foodDoc.data()!)
          : null;
      _reviews = reviewSnap.docs
          .map((d) => ReviewModel.fromMap(d.id, d.data()))
          .toList();
      _canReview = canReview;
      _hasReviewed = hasReviewed;
      _loading = false;
    });
  }

  Future<void> _submitReview() async {
    final user = ref.read(authProvider).valueOrNull;
    if (user == null || _reviewCtrl.text.trim().isEmpty) return;

    final id = const Uuid().v4();
    final review = ReviewModel(
      id: id,
      foodId: widget.foodId,
      buyerId: user.id,
      buyerName: user.name,
      rating: _reviewRating,
      comment: _reviewCtrl.text.trim(),
      createdAt: DateTime.now(),
    );

    await WriteLogService.capture(
      action: 'Create review',
      target: 'reviews/$id',
      task: () => _db.collection('reviews').doc(id).set(review.toMap()),
    );

    // Update food average
    final allRatings = [..._reviews.map((r) => r.rating), _reviewRating];
    final avg =
        allRatings.fold(0, (s, r) => s + r) / allRatings.length;
    await WriteLogService.capture(
      action: 'Update food ratings',
      target: 'foods/${widget.foodId}',
      task: () => _db.collection('foods').doc(widget.foodId).update({
        'averageRating': double.parse(avg.toStringAsFixed(1)),
        'reviewCount': allRatings.length,
      }),
    );

    _reviewCtrl.clear();
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted!')));
  }

  Future<void> _addToCart(FoodModel food) async {
    final notifier = ref.read(cartProvider.notifier);
    final cart = ref.read(cartProvider);
    final currentVendor = notifier.currentVendorId;

    if (currentVendor != null && currentVendor != food.vendorId) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Replace Cart?'),
          content: Text(
              'Clear items from ${cart.first.vendorBrandName} and add from ${food.vendorBrandName}?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                await notifier.clear();
                await _doAdd(food, notifier);
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      return;
    }
    await _doAdd(food, notifier);
  }

  Future<void> _doAdd(FoodModel food, CartNotifier notifier) async {
    for (int i = 0; i < _quantity; i++) {
      await notifier.addItem(CartItemModel(
        foodId: food.id,
        foodName: food.name,
        price: food.price,
        quantity: 1,
        vendorId: food.vendorId,
        vendorBrandName: food.vendorBrandName,
        imagePath: food.imageUrl,
      ));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_quantity × ${food.name} added to cart')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final food = _food;
    if (food == null) {
      return Scaffold(
          appBar: AppBar(), body: const Center(child: Text('Food not found')));
    }

    final theme = Theme.of(context);
    final user = ref.watch(authProvider).valueOrNull;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: food.imageUrl != null
                  ? Image.network(food.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.fastfood_rounded,
                              size: 80, color: Colors.grey)))
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.fastfood_rounded,
                          size: 80, color: Colors.grey),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(food.name,
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    Text(food.price.toCurrency(),
                        style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(food.category,
                        style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sold by',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(food.vendorBrandName,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Description',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(food.description,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
                  const SizedBox(height: 20),
                  Row(children: [
                    Text('Quantity',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    _QtyButton(
                        icon: Icons.remove,
                        onTap: () => setState(
                            () => _quantity = (_quantity - 1).clamp(1, 99))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('$_quantity',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    _QtyButton(
                        icon: Icons.add,
                        onTap: () => setState(
                            () => _quantity = (_quantity + 1).clamp(1, 99))),
                  ]),
                  const SizedBox(height: 20),
                  Row(children: [
                    Text('Reviews',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    if (food.reviewCount > 0) ...[
                      const Icon(Icons.star_rounded,
                          size: 16, color: AppColors.starColor),
                      Text(
                          '${food.averageRating.toStringAsFixed(1)} (${food.reviewCount})'),
                    ],
                  ]),
                  const SizedBox(height: 12),
                  if (user != null && _canReview && !_hasReviewed) ...[
                    _ReviewForm(
                      rating: _reviewRating,
                      controller: _reviewCtrl,
                      onRatingChanged: (r) =>
                          setState(() => _reviewRating = r),
                      onSubmit: _submitReview,
                    ),
                    const SizedBox(height: 16),
                  ],
                  ..._reviews.map((r) => _ReviewTile(review: r)),
                  if (_reviews.isEmpty)
                    const Text('No reviews yet.',
                        style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () async => _addToCart(food),
            icon: const Icon(Icons.shopping_cart_outlined),
            label: Text(
                'Add to Cart • ${(food.price * _quantity).toCurrency()}'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 18, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _ReviewForm extends StatelessWidget {
  final int rating;
  final TextEditingController controller;
  final void Function(int) onRatingChanged;
  final VoidCallback onSubmit;

  const _ReviewForm(
      {required this.rating,
      required this.controller,
      required this.onRatingChanged,
      required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Write a Review',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                return GestureDetector(
                  onTap: () => onRatingChanged(i + 1),
                  child: Icon(
                    i < rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: AppColors.starColor,
                    size: 28,
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Share your experience...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                  onPressed: onSubmit, child: const Text('Submit')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final ReviewModel review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
              radius: 18,
              child: Text(review.buyerName[0].toUpperCase())),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(review.buyerName,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  ...List.generate(
                      5,
                      (i) => Icon(
                            i < review.rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 12,
                            color: AppColors.starColor,
                          )),
                ]),
                Text(review.comment, style: theme.textTheme.bodySmall),
                Text(review.createdAt.toDateOnly(),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
