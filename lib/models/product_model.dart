import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final List<String> images;
  final String categoryId;
  final int stock;
  final bool isActive;
  final DateTime createdAt;
  final String sellerId;
  final String imageUrl;

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.images,
    required this.categoryId,
    required this.stock,
    required this.isActive,
    required this.createdAt,
    required this.sellerId,
    required this.imageUrl,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      images: List<String>.from(map['images'] ?? []),
      categoryId: map['categoryId'] ?? '',
      stock: map['stock'] ?? 0,
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      sellerId: map['sellerId'] ?? '',
      imageUrl: map['imageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'images': images,
      'categoryId': categoryId,
      'stock': stock,
      'isActive': isActive,
      'createdAt': createdAt,
      'sellerId': sellerId,
      'imageUrl': imageUrl,
    };
  }
}
