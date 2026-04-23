import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'write_log_service.dart';

class FirebaseService {
  static FirebaseFirestore get db => FirebaseFirestore.instance;
  static FirebaseAuth get auth => FirebaseAuth.instance;

  static Future<void> seedInitialData() async {
    await _seedCategories();
    // Intentionally avoid auth-user seeding from client startup.
    // Creating/signing users here can disrupt the active session.
  }

  static Future<void> _seedCategories() async {
    final snap = await db.collection('categories').limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final batch = db.batch();
    final cats = [
      {'id': '1', 'name': 'Rice', 'emoji': '🍚'},
      {'id': '2', 'name': 'Soups', 'emoji': '🍲'},
      {'id': '3', 'name': 'Snacks', 'emoji': '🍿'},
      {'id': '4', 'name': 'Drinks', 'emoji': '🥤'},
      {'id': '5', 'name': 'Proteins', 'emoji': '🍗'},
      {'id': '6', 'name': 'Pastries', 'emoji': '🥐'},
      {'id': '7', 'name': 'Specials', 'emoji': '⭐'},
    ];

    for (final c in cats) {
      batch.set(db.collection('categories').doc(c['id']!), c);
    }

    await WriteLogService.capture(
      action: 'Seed categories',
      target: 'categories',
      task: () => batch.commit(),
    );
  }
}
