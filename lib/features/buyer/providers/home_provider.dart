import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/food_model.dart';
import '../../../models/category_model.dart';

final _db = FirebaseFirestore.instance;

final foodListProvider = StreamProvider<List<FoodModel>>((ref) {
  return _db
      .collection('foods')
      .where('isAvailable', isEqualTo: true)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => FoodModel.fromMap(d.id, d.data())).toList());
});

final categoryListProvider = StreamProvider<List<CategoryModel>>((ref) {
  return _db.collection('categories').snapshots().map((snap) =>
      snap.docs.map((d) => CategoryModel.fromMap(d.id, d.data())).toList());
});

final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

final filteredFoodsProvider = Provider<List<FoodModel>>((ref) {
  final foods = ref.watch(foodListProvider).valueOrNull ?? [];
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final cat = ref.watch(selectedCategoryProvider);
  return foods.where((f) {
    final matchesQuery = query.isEmpty ||
        f.name.toLowerCase().contains(query) ||
        f.vendorBrandName.toLowerCase().contains(query) ||
        f.category.toLowerCase().contains(query);
    final matchesCat = cat == null || f.category == cat;
    return matchesQuery && matchesCat;
  }).toList();
});
