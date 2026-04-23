import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String foodId;
  final String buyerId;
  final String buyerName;
  final int rating;
  final String comment;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.foodId,
    required this.buyerId,
    required this.buyerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromMap(String id, Map<String, dynamic> map) =>
      ReviewModel(
        id: id,
        foodId: map['foodId'] ?? '',
        buyerId: map['buyerId'] ?? '',
        buyerName: map['buyerName'] ?? '',
        rating: (map['rating'] as num).toInt(),
        comment: map['comment'] ?? '',
        createdAt:
            (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'foodId': foodId,
        'buyerId': buyerId,
        'buyerName': buyerName,
        'rating': rating,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
