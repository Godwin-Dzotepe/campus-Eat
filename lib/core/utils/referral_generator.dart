import 'dart:math';

class ReferralGenerator {
  static String fromBrandName(String brandName) {
    if (brandName.trim().isEmpty) return 'BRAND-0000';

    final clean =
        brandName.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9 ]'), '');
    final words = clean.split(' ').where((w) => w.isNotEmpty).toList();
    final prefix = words
        .map((w) => w.substring(0, min(3, w.length)))
        .join('');
    final short = prefix.substring(0, min(5, prefix.length));
    final hash =
        brandName.codeUnits.fold(0, (s, c) => s + c) % 9999;
    return '$short-${hash.toString().padLeft(4, '0')}';
  }
}
