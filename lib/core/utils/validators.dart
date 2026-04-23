class Validators {
  static String? email(String? v) {
    if (v == null || v.isEmpty) return 'Email is required';
    final re = RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$');
    if (!re.hasMatch(v)) return 'Enter a valid email';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Minimum 6 characters';
    return null;
  }

  static String? required(String? v, [String field = 'This field']) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? phone(String? v) {
    if (v == null || v.isEmpty) return 'Phone number is required';
    final re = RegExp(r'^\+?[\d\s\-]{7,15}$');
    if (!re.hasMatch(v)) return 'Enter a valid phone number';
    return null;
  }

  static String? price(String? v) {
    if (v == null || v.isEmpty) return 'Price is required';
    if (double.tryParse(v) == null) return 'Enter a valid number';
    if (double.parse(v) <= 0) return 'Price must be greater than 0';
    return null;
  }
}
