import 'package:cloud_firestore/cloud_firestore.dart';

/// Stored in Firestore as [key]. Shown in the UI as [label].
enum MealCategory {
  starters('starters', 'Starters'),
  mainCourse('main_course', 'Main Course'),
  drinks('drinks', 'Drinks'),
  desserts('desserts', 'Desserts');

  const MealCategory(this.key, this.label);
  final String key;
  final String label;

  static MealCategory fromKey(String? key) => values.firstWhere(
        (c) => c.key == key,
        orElse: () => MealCategory.mainCourse,
      );
}

class MealModel {
  const MealModel({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.imageUrl,
    this.description = '',
    this.isAvailable = true,
  });

  final String id;
  final String name;
  final MealCategory category;
  final double price;
  final String imageUrl;
  final String description;
  final bool isAvailable;

  factory MealModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return MealModel(
      id: doc.id,
      name: d['name'] as String? ?? '',
      category: MealCategory.fromKey(d['category'] as String?),
      price: (d['price'] as num?)?.toDouble() ?? 0,
      imageUrl: d['imageUrl'] as String? ?? '',
      description: d['description'] as String? ?? '',
      isAvailable: d['isAvailable'] as bool? ?? true,
    );
  }

  /// `nameLower` is the field used for prefix search (Firestore has no
  /// case-insensitive or full-text search).
  Map<String, dynamic> toMap() => {
        'name': name,
        'nameLower': name.trim().toLowerCase(),
        'category': category.key,
        'price': price,
        'imageUrl': imageUrl,
        'description': description,
        'isAvailable': isAvailable,
      };

  MealModel copyWith({
    String? name,
    MealCategory? category,
    double? price,
    String? imageUrl,
    String? description,
    bool? isAvailable,
  }) =>
      MealModel(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        price: price ?? this.price,
        imageUrl: imageUrl ?? this.imageUrl,
        description: description ?? this.description,
        isAvailable: isAvailable ?? this.isAvailable,
      );
}