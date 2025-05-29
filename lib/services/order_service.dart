import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/cart_item.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Créer une nouvelle commande
  Future<OrderModel> createOrder({
    required String userId,
    required List<CartItem> items,
    required double totalAmount,
    String? shippingAddress,
  }) async {
    final orderRef = _firestore.collection('orders').doc();
    
    final order = OrderModel(
      id: orderRef.id,
      userId: userId,
      items: items,
      totalAmount: totalAmount,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
      shippingAddress: shippingAddress,
    );

    await orderRef.set(order.toMap());
    return order;
  }

  // Obtenir les commandes d'un utilisateur
  Stream<List<OrderModel>> getUserOrders(String userId) {
    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return OrderModel.fromMap(data);
      }).toList();
    });
  }

  // Obtenir une commande spécifique
  Future<OrderModel?> getOrder(String orderId) async {
    final doc = await _firestore.collection('orders').doc(orderId).get();
    if (!doc.exists) return null;
    
    final data = doc.data()!;
    data['id'] = doc.id;
    return OrderModel.fromMap(data);
  }

  // Mettre à jour le statut d'une commande
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': status.toString().split('.').last,
    });
  }

  // Ajouter un numéro de suivi
  Future<void> addTrackingNumber(String orderId, String trackingNumber) async {
    await _firestore.collection('orders').doc(orderId).update({
      'trackingNumber': trackingNumber,
    });
  }
} 