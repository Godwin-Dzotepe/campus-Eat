import 'package:cloud_firestore/cloud_firestore.dart';

class AddressModel {
  final String? id;
  final String label;
  final String fullAddress;
  final double lat;
  final double lng;
  final DateTime? createdAt;

  const AddressModel({
    this.id,
    required this.label,
    required this.fullAddress,
    required this.lat,
    required this.lng,
    this.createdAt,
  });

  factory AddressModel.fromMap(String id, Map<String, dynamic> map) {
    return AddressModel(
      id: id,
      label: map['label'] ?? 'Address',
      fullAddress: map['fullAddress'] ?? '',
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'label': label,
        'fullAddress': fullAddress,
        'lat': lat,
        'lng': lng,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
