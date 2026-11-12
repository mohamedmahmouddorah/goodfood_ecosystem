import 'package:hive/hive.dart';

part 'order_item_model.g.dart';

@HiveType(typeId: 12)
class OrderItemModel {
  @HiveField(0)
  final String mealId;

  @HiveField(1)
  final String mealName;

  @HiveField(2)
  final String mealImage;

  @HiveField(3)
  int quantity;

  @HiveField(4)
  final double unitPrice;

  OrderItemModel({
    required this.mealId,
    required this.mealName,
    required this.mealImage,
    required this.quantity,
    required this.unitPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'meal_id': mealId,
      'meal_name': mealName,
      'meal_image': mealImage,
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }

  factory OrderItemModel.fromMap(Map<String, dynamic> data) {
    return OrderItemModel(
      mealId: data['meal_id'],
      mealName: data['meal_name'],
      mealImage: data['meal_image'],
      quantity: data['quantity'],
      unitPrice: (data['unit_price'] as num).toDouble(),
    );
  }
}