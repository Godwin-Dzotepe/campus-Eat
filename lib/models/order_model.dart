import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_item_model.dart';

class OrderModel {
  final String id;
  final String buyerId;
  final String buyerName;
  final String vendorId;
  final String vendorBrandName;
  final List<CartItemModel> items;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final String deliveryType;
  String status;
  final String? deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final String paymentMethod;
  bool isPaid;
  final DateTime createdAt;
  final String? referralCodeUsed;

  OrderModel({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.vendorId,
    required this.vendorBrandName,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.deliveryType,
    this.status = 'placed',
    this.deliveryAddress,
    this.deliveryLat,
    this.deliveryLng,
    required this.paymentMethod,
    this.isPaid = false,
    required this.createdAt,
    this.referralCodeUsed,
  });

  factory OrderModel.fromMap(String id, Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    return OrderModel(
      id: id,
      buyerId: map['buyerId'] ?? '',
      buyerName: map['buyerName'] ?? '',
      vendorId: map['vendorId'] ?? '',
      vendorBrandName: map['vendorBrandName'] ?? '',
      items: rawItems
          .map((i) => CartItemModel.fromMap(Map<String, dynamic>.from(i)))
          .toList(),
      subtotal: (map['subtotal'] as num).toDouble(),
      deliveryFee: (map['deliveryFee'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
      deliveryType: map['deliveryType'] ?? 'pickup',
      status: map['status'] ?? 'placed',
      deliveryAddress: map['deliveryAddress'],
      deliveryLat: (map['deliveryLat'] as num?)?.toDouble(),
      deliveryLng: (map['deliveryLng'] as num?)?.toDouble(),
      paymentMethod: map['paymentMethod'] ?? 'card',
      isPaid: map['isPaid'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      referralCodeUsed: map['referralCodeUsed'],
    );
  }

  Map<String, dynamic> toMap() => {
        'buyerId': buyerId,
        'buyerName': buyerName,
        'vendorId': vendorId,
        'vendorBrandName': vendorBrandName,
        'items': items.map((i) => i.toMap()).toList(),
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'total': total,
        'deliveryType': deliveryType,
        'status': status,
        'deliveryAddress': deliveryAddress,
        'deliveryLat': deliveryLat,
        'deliveryLng': deliveryLng,
        'paymentMethod': paymentMethod,
        'isPaid': isPaid,
        'createdAt': FieldValue.serverTimestamp(),
        'referralCodeUsed': referralCodeUsed,
      };
}
