import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String projectUrl =
      String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://vlhnfquldugdsiiljjcr.supabase.co',
      );
  static const String anonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  static bool get isConfigured => anonKey.trim().isNotEmpty;

  static Future<void> init() async {
    if (!isConfigured) return;
    await Supabase.initialize(
      url: projectUrl,
      anonKey: anonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
