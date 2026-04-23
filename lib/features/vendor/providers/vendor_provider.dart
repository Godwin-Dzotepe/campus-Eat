import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/user_model.dart';
import '../../../models/food_model.dart';

final _db = FirebaseFirestore.instance;

/// Returns the effective vendor — the logged-in vendor or the one being impersonated.
final effectiveVendorProvider = Provider<UserModel?>((ref) {
  final userAsync = ref.watch(authProvider);
  final user = userAsync.valueOrNull;
  if (user == null) return null;
  if (user.role == AppStrings.admin && user.impersonatingVendorId != null) {
    // The impersonated vendor is fetched separately via impersonatedVendorProvider.
    return ref.watch(impersonatedVendorProvider).valueOrNull;
  }
  return user;
});

final impersonatedVendorProvider = StreamProvider<UserModel?>((ref) {
  final userAsync = ref.watch(authProvider);
  final user = userAsync.valueOrNull;
  final vendorId = user?.impersonatingVendorId;
  if (vendorId == null) return Stream.value(null);
  return _db
      .collection('users')
      .doc(vendorId)
      .snapshots()
      .map((d) => d.exists ? UserModel.fromMap(d.id, d.data()!) : null);
});

final vendorFoodsProvider = StreamProvider<List<FoodModel>>((ref) {
  final vendor = ref.watch(effectiveVendorProvider);
  if (vendor == null) return Stream.value([]);
  return _db
      .collection('foods')
      .where('vendorId', isEqualTo: vendor.id)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => FoodModel.fromMap(d.id, d.data())).toList());
});
