import 'product_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_item.dart';

enum OrderStatus {
  pending,
  processing,
  shipped,
  delivered,
  cancelled,
}

class OrderModel {
  final String id;
  final String userId;
  final List<CartItem> items;
  final double totalAmount;
  final OrderStatus status;
  final DateTime createdAt;
  final String? shippingAddress;
  final String? trackingNumber;

  OrderModel({
    required this.id,
    required this.userId,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.shippingAddress,
    this.trackingNumber,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      items: (map['items'] as List<dynamic>).map((item) {
        final data = item as Map<String, dynamic>;
        return CartItem(
          product: ProductModel.fromMap(data['product']),
          quantity: data['quantity'] ?? 1,
        );
      }).toList(),
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      status: OrderStatus.values.firstWhere(
            (e) => e.toString() == 'OrderStatus.${map['status']}',
        orElse: () => OrderStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      shippingAddress: map['shippingAddress'],
      trackingNumber: map['trackingNumber'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'items': items.map((item) => {
        'product': item.product.toMap(),
        'quantity': item.quantity,
      }).toList(),
      'totalAmount': totalAmount,
      'status': status.toString().split('.').last,
      'createdAt': createdAt,
      'shippingAddress': shippingAddress,
      'trackingNumber': trackingNumber,
    };
  }
}
