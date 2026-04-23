class CategoryModel {
  final String id;
  final String name;
  final String emoji;

  CategoryModel({required this.id, required this.name, required this.emoji});

  factory CategoryModel.fromMap(String id, Map<String, dynamic> map) =>
      CategoryModel(
        id: id,
        name: map['name'] ?? '',
        emoji: map['emoji'] ?? '',
      );
}
