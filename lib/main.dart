import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/services/firebase_service.dart';
import 'core/services/hive_service.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: _AppBootstrap()));
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  late final Future<_BootstrapResult> _initFuture = _init();

  Future<_BootstrapResult> _init() async {
    await HiveService.init();
    await NotificationService.init();
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (error, stackTrace) {
      return _BootstrapResult(error: error, stackTrace: stackTrace);
    }

    unawaited(FirebaseService.seedInitialData().catchError((_) {
      // If seeding fails, keep the app running; it can be re-attempted later.
    }));

    return const _BootstrapResult();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootstrapResult>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootstrapLoading();
        }

        final result = snapshot.data;
        if (result == null || result.error != null) {
          return _BootstrapError(error: result?.error);
        }

        return const CampusEatApp();
      },
    );
  }
}

class _BootstrapResult {
  final Object? error;
  final StackTrace? stackTrace;

  const _BootstrapResult({this.error, this.stackTrace});
}

class _BootstrapLoading extends StatelessWidget {
  const _BootstrapLoading();

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.white),
        child: Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}

class _BootstrapError extends StatelessWidget {
  final Object? error;

  const _BootstrapError({this.error});

  @override
  Widget build(BuildContext context) {
    final message = error?.toString() ?? 'Unknown error';
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Colors.white),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'App initialization failed',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      decoration: TextDecoration.none),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Firebase could not initialize. Add your Firebase config files '
                  'and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.normal),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
