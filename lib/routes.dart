import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/products/product_detail_screen.dart';
import 'screens/cart/cart_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/order_detail_screen.dart';
import 'models/order_model.dart';
import 'screens/main_screen.dart';
import 'screens/admin/admin_screen.dart';
import 'screens/moderator/moderator_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String productDetail = '/product-detail';
  static const String cart = '/cart';
  static const String profile = '/profile';
  static const String orderDetail = '/order-detail';
  static const String main = '/main';
  static const String admin = '/admin';
  static const String moderator = '/moderator';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case productDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
            product: args['product'],
          ),
        );
      case cart:
        return MaterialPageRoute(builder: (_) => const CartScreen());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case orderDetail:
        final order = settings.arguments as OrderModel;
        return MaterialPageRoute(
          builder: (_) => OrderDetailScreen(order: order),
        );
      case main:
        return MaterialPageRoute(builder: (_) => const MainScreen());
      case admin:
        return MaterialPageRoute(builder: (_) => const AdminScreen());
      case moderator:
        return MaterialPageRoute(builder: (_) => const ModeratorScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('Route non trouvée: ${settings.name}'),
            ),
          ),
        );
    }
  }
}
