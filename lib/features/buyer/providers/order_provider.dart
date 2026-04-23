import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/order_model.dart';

final _db = FirebaseFirestore.instance;

final buyerOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  final userAsync = ref.watch(authProvider);
  final user = userAsync.valueOrNull;
  if (user == null) return Stream.value([]);
  return _db
      .collection('orders')
      .where('buyerId', isEqualTo: user.id)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList());
});
