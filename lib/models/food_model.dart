import 'package:cloud_firestore/cloud_firestore.dart';

class FoodModel {
  final String id;
  final String vendorId;
  final String vendorBrandName;
  final String name;
  final double price;
  final String category;
  final String description;
  final String? imageUrl;
  bool isAvailable;
  double averageRating;
  int reviewCount;
  final DateTime createdAt;

  String? get imagePath => imageUrl;

  FoodModel({
    required this.id,
    required this.vendorId,
    required this.vendorBrandName,
    required this.name,
    required this.price,
    required this.category,
    required this.description,
    this.imageUrl,
    this.isAvailable = true,
    this.averageRating = 0.0,
    this.reviewCount = 0,
    required this.createdAt,
  });

  factory FoodModel.fromMap(String id, Map<String, dynamic> map) => FoodModel(
        id: id,
        vendorId: map['vendorId'] ?? '',
        vendorBrandName: map['vendorBrandName'] ?? '',
        name: map['name'] ?? '',
        price: (map['price'] as num).toDouble(),
        category: map['category'] ?? '',
        description: map['description'] ?? '',
        imageUrl: map['imageUrl'],
        isAvailable: map['isAvailable'] ?? true,
        averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'vendorId': vendorId,
        'vendorBrandName': vendorBrandName,
        'name': name,
        'price': price,
        'category': category,
        'description': description,
        'imageUrl': imageUrl,
        'isAvailable': isAvailable,
        'averageRating': averageRating,
        'reviewCount': reviewCount,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
