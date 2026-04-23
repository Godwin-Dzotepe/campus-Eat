import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user_model.dart';
import '../../../models/order_model.dart';
import '../../../core/services/write_log_service.dart';

final _db = FirebaseFirestore.instance;

final allUsersProvider = StreamProvider<List<UserModel>>((ref) {
  return _db.collection('users').snapshots().map((snap) =>
      snap.docs.map((d) => UserModel.fromMap(d.id, d.data())).toList());
});

final allOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  return _db
      .collection('orders')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList());
});

class AdminActions {
  static Future<void> deleteUser(String userId) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    final role = userDoc.data()?['role'];
    if (role == 'vendor') {
      final foods = await _db
          .collection('foods')
          .where('vendorId', isEqualTo: userId)
          .get();
      final batch = _db.batch();
      for (final d in foods.docs) {
        batch.delete(d.reference);
      }
      batch.delete(userDoc.reference);
      await WriteLogService.capture(
        action: 'Delete vendor and foods',
        target: 'users/$userId',
        task: () => batch.commit(),
      );
    } else {
      await WriteLogService.capture(
        action: 'Delete user',
        target: 'users/$userId',
        task: () => userDoc.reference.delete(),
      );
    }
  }

  static Future<void> toggleUserActive(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    final current = doc.data()?['isActive'] ?? true;
    await WriteLogService.capture(
      action: 'Toggle user active',
      target: 'users/$userId',
      task: () => doc.reference.update({'isActive': !current}),
    );
  }

  static Future<void> impersonateVendor(
      String vendorId, String adminUid) async {
    await WriteLogService.capture(
      action: 'Start impersonation',
      target: 'users/$adminUid',
      task: () => _db
        .collection('users')
        .doc(adminUid)
        .update({'impersonatingVendorId': vendorId}),
    );
  }

  static Future<void> stopImpersonating(String adminUid) async {
    await WriteLogService.capture(
      action: 'Stop impersonation',
      target: 'users/$adminUid',
      task: () => _db
          .collection('users')
          .doc(adminUid)
          .update({'impersonatingVendorId': FieldValue.delete()}),
    );
  }
}
