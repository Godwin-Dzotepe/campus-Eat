import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static const String prefsBox = 'prefs';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(prefsBox);
  }
}
