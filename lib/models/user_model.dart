import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? brandName;
  final String? referralCode;
  final String? contactNumber;
  double? deliveryFee;
  bool isActive;
  final DateTime createdAt;
  String? impersonatingVendorId;
  double? walletBalance;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.brandName,
    this.referralCode,
    this.contactNumber,
    this.deliveryFee,
    this.isActive = true,
    required this.createdAt,
    this.impersonatingVendorId,
    this.walletBalance,
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'buyer',
      brandName: map['brandName'],
      referralCode: map['referralCode'],
      contactNumber: map['contactNumber'],
      deliveryFee: (map['deliveryFee'] as num?)?.toDouble(),
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      impersonatingVendorId: map['impersonatingVendorId'],
      walletBalance: (map['walletBalance'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        if (brandName != null) 'brandName': brandName,
        if (referralCode != null) 'referralCode': referralCode,
        if (contactNumber != null) 'contactNumber': contactNumber,
        if (deliveryFee != null) 'deliveryFee': deliveryFee,
        'isActive': isActive,
        'createdAt': FieldValue.serverTimestamp(),
        if (impersonatingVendorId != null)
          'impersonatingVendorId': impersonatingVendorId,
        if (walletBalance != null) 'walletBalance': walletBalance,
      };
}
