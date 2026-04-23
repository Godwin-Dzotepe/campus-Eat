class CartItemModel {
  final String foodId;
  final String foodName;
  final double price;
  int quantity;
  final String vendorId;
  final String vendorBrandName;
  final String? imagePath;

  CartItemModel({
    required this.foodId,
    required this.foodName,
    required this.price,
    required this.quantity,
    required this.vendorId,
    required this.vendorBrandName,
    this.imagePath,
  });

  factory CartItemModel.fromMap(Map<String, dynamic> map) => CartItemModel(
        foodId: map['foodId'] ?? '',
        foodName: map['foodName'] ?? '',
        price: (map['price'] as num).toDouble(),
        quantity: (map['quantity'] as num).toInt(),
        vendorId: map['vendorId'] ?? '',
        vendorBrandName: map['vendorBrandName'] ?? '',
        imagePath: map['imagePath'],
      );

  Map<String, dynamic> toMap() => {
        'foodId': foodId,
        'foodName': foodName,
        'price': price,
        'quantity': quantity,
        'vendorId': vendorId,
        'vendorBrandName': vendorBrandName,
        'imagePath': imagePath,
      };
}
