import 'supabase_service.dart';

class SupabaseFoodService {
  static Future<void> saveFoodImageUrl({
    required String foodId,
    required String imageUrl,
    String? vendorId,
  }) async {
    if (!SupabaseService.isConfigured) return;

    final payload = <String, dynamic>{
      'id': foodId,
      'image_url': imageUrl,
      'updated_at': DateTime.now().toIso8601String(),
      if (vendorId != null) 'vendor_id': vendorId,
    };

    try {
      await SupabaseService.client.from('foods').upsert(payload);
    } catch (_) {
      // Non-blocking: app may still rely on Firebase reads while Supabase schema evolves.
    }
  }
}
