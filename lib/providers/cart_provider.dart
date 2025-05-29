import 'package:flutter/material.dart';
import '../models/product_model.dart';
import 'package:mona_store/models/cart_item.dart'; // ✅
import 'package:mona_store/models/cart_item.dart';

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => {..._items};

  int get itemCount => _items.length;

  double get totalAmount {
    return _items.values.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  void addToCart(ProductModel product) {
    if (_items.containsKey(product.id)) {
      _items.update(
        product.id,
            (existingItem) => CartItem(
          product: existingItem.product,
          quantity: existingItem.quantity + 1,
        ),
      );
    } else {
      _items.putIfAbsent(
        product.id,
            () => CartItem(product: product),
      );
    }
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    if (!_items.containsKey(productId)) return;

    if (quantity <= 0) {
      removeFromCart(productId);
    } else {
      _items.update(
        productId,
            (existingItem) => CartItem(
          product: existingItem.product,
          quantity: quantity,
        ),
      );
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
  void clearCart() {
    _items.clear();
    notifyListeners();
  }

}
