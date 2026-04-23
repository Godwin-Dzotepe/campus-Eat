import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user_model.dart';
import '../../../core/utils/referral_generator.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/write_log_service.dart';

class AuthRepository {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      final uid = _auth.currentUser!.uid;
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) {
        await _auth.signOut();
        return 'Account not found';
      }
      final isActive = doc.data()?['isActive'] ?? true;
      if (!isActive) {
        await _auth.signOut();
        return 'Account has been deactivated';
      }
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        return 'Invalid email or password';
      }
      return e.message ?? 'Login failed';
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? brandName,
    String? contactNumber,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      final uid = cred.user!.uid;
      
      try {
        await WriteLogService.capture(
          action: 'Create user profile',
          target: 'users/$uid',
          task: () => _db.collection('users').doc(uid).set({
            'id': uid,
            'name': name,
            'email': email,
            'role': role,
            if (role == AppStrings.vendor && brandName != null)
              'brandName': brandName,
            if (role == AppStrings.vendor && brandName != null)
              'referralCode': ReferralGenerator.fromBrandName(brandName),
            if (role == AppStrings.vendor) 'contactNumber': contactNumber,
            if (role == AppStrings.vendor) 'deliveryFee': 5.0,
            if (role == AppStrings.buyer) 'walletBalance': 50.0,

            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
          }),
        );
        return null;
      } catch (e) {
        // If Firestore fails, delete the auth user to allow re-registration
        await cred.user?.delete();
        return 'Failed to create user profile. Please try again.';
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') return 'Email already registered';
      return e.message ?? 'Registration failed';
    }
  }

  Future<void> logout() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        final doc = await _db.collection('users').doc(uid).get();
        if (doc.exists && doc.data()?['role'] == 'admin') {
          await WriteLogService.capture(
            action: 'Stop impersonating',
            target: 'users/$uid',
            task: () => _db
                .collection('users')
                .doc(uid)
                .update({'impersonatingVendorId': FieldValue.delete()}),
          );
        }
      }
    } catch (e) {
      // Ignore errors during cleanup, we must sign out regardless
    } finally {
      await _auth.signOut();
    }
  }

  Future<UserModel?> currentUserModel() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) return null;
    final doc = await _db.collection('users').doc(fbUser.uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.id, doc.data()!);
  }
}
