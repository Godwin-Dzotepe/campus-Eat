import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class FirestoreErrorView extends StatelessWidget {
  final Object error;
  final String? title;

  const FirestoreErrorView({super.key, required this.error, this.title});

  @override
  Widget build(BuildContext context) {
    final info = _describeError(error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400, size: 40),
            const SizedBox(height: 12),
            Text(
              title ?? info.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              info.message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (info.details.isNotEmpty)
              SelectableText(
                info.details,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

class _FirestoreErrorInfo {
  final String title;
  final String message;
  final String details;

  const _FirestoreErrorInfo({
    required this.title,
    required this.message,
    required this.details,
  });
}

_FirestoreErrorInfo _describeError(Object error) {
  if (error is FirebaseException) {
    final msg = error.message ?? error.code;
    final lower = msg.toLowerCase();
    if (error.code == 'failed-precondition' || lower.contains('index')) {
      return _FirestoreErrorInfo(
        title: 'Firestore index required',
        message:
            'This query needs a composite index. Open Firestore Indexes in the '
            'Firebase console and create the index shown in the error details.',
        details: msg,
      );
    }
    return _FirestoreErrorInfo(
      title: 'Firestore error',
      message: msg,
      details: error.code,
    );
  }

  return _FirestoreErrorInfo(
    title: 'Unexpected error',
    message: error.toString(),
    details: '',
  );
}
