import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String _cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'dkgomk9o4',
  );
  static const String _uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 'De-iJ4QBmdMzwKWuV2Ai-cVkrGA',
  );

  static Future<String> uploadFoodImage({
    required String foodId,
    required Uint8List bytes,
    String fileName = 'food.jpg',
  }) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );

    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = 'campus_eat/foods'
      ..fields['public_id'] = foodId
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ),
      );

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('Cloudinary upload failed (${streamed.statusCode}): $body');
    }

    final map = jsonDecode(body) as Map<String, dynamic>;
    final url = (map['secure_url'] ?? map['url']) as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Cloudinary upload succeeded but returned no URL.');
    }
    return url;
  }
}
