import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/home_provider.dart';
import '../widgets/food_card.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/firestore_error_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final categoriesAsync = ref.watch(categoryListProvider);
    final foodsAsync = ref.watch(foodListProvider);
    final foods = ref.watch(filteredFoodsProvider);
    final selectedCat = ref.watch(selectedCategoryProvider);
    final theme = Theme.of(context);

    if (foodsAsync.isLoading || categoriesAsync.isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (foodsAsync.hasError) {
      return Scaffold(
          body: FirestoreErrorView(error: foodsAsync.error!));
    }
    if (categoriesAsync.hasError) {
      return Scaffold(
          body: FirestoreErrorView(error: categoriesAsync.error!));
    }

    final categories = categoriesAsync.valueOrNull ?? [];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(foodListProvider),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hey, ${user?.name.split(' ').first ?? 'there'} 👋',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'What are you eating today?',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  onPressed: () => context.go('/buyer/cart'),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SearchBar(
                  controller: _searchCtrl,
                  hintText: 'Search food, restaurant...',
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref
                              .read(searchQueryProvider.notifier)
                              .state = '';
                        },
                      ),
                  ],
                  onChanged: (v) =>
                      ref.read(searchQueryProvider.notifier).state = v,
                  padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 16)),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: categories.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('All'),
                          selected: selectedCat == null,
                          onSelected: (_) => ref
                              .read(selectedCategoryProvider.notifier)
                              .state = null,
                        ),
                      );
                    }
                    final cat = categories[i - 1];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text('${cat.emoji} ${cat.name}'),
                        selected: selectedCat == cat.name,
                        onSelected: (_) => ref
                            .read(selectedCategoryProvider.notifier)
                            .state = selectedCat == cat.name
                            ? null
                            : cat.name,
                      ),
                    );
                  },
                ),
              ),
            ),
            if (foods.isEmpty)
              const SliverFillRemaining(
                child: EmptyStateWidget(
                  title: 'No food available',
                  subtitle: 'Check back later or clear your filters',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => FoodCard(food: foods[i]),
                    childCount: foods.length,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
