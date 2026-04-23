import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/address_model.dart';
import '../../../core/services/write_log_service.dart';

final _db = FirebaseFirestore.instance;

final savedAddressesProvider = StreamProvider<List<AddressModel>>((ref) {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return _db
      .collection('users')
      .doc(user.id)
      .collection('addresses')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => AddressModel.fromMap(d.id, d.data()))
          .toList());
});

class AddressActions {
  static String _stableId(AddressModel address) {
    final lat = address.lat.toStringAsFixed(5);
    final lng = address.lng.toStringAsFixed(5);
    return '${lat}_$lng';
  }

  static Future<void> saveAddress({
    required String userId,
    required AddressModel address,
  }) async {
    final id = address.id ?? _stableId(address);
    await WriteLogService.capture(
      action: 'Save address',
      target: 'users/$userId/addresses/$id',
      task: () => _db
          .collection('users')
          .doc(userId)
          .collection('addresses')
          .doc(id)
          .set(address.toMap()),
    );
  }

  static Future<void> deleteAddress({
    required String userId,
    required String addressId,
  }) async {
    await WriteLogService.capture(
      action: 'Delete address',
      target: 'users/$userId/addresses/$addressId',
      task: () => _db
          .collection('users')
          .doc(userId)
          .collection('addresses')
          .doc(addressId)
          .delete(),
    );
  }

  static Future<void> clearAll({
    required String userId,
    required List<AddressModel> addresses,
  }) async {
    if (addresses.isEmpty) return;
    final batch = _db.batch();
    final col = _db.collection('users').doc(userId).collection('addresses');
    for (final address in addresses) {
      if (address.id != null) {
        batch.delete(col.doc(address.id));
      }
    }
    await WriteLogService.capture(
      action: 'Clear saved addresses',
      target: 'users/$userId/addresses',
      task: () => batch.commit(),
    );
  }
}
