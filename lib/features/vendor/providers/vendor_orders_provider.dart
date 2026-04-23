import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/order_model.dart';
import 'vendor_provider.dart';

final _db = FirebaseFirestore.instance;

final vendorOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  final vendor = ref.watch(effectiveVendorProvider);
  if (vendor == null) return Stream.value([]);
  return _db
      .collection('orders')
      .where('vendorId', isEqualTo: vendor.id)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList());
});
