import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'providers/app_auth_provider.dart';
import 'providers/cart_provider.dart';
import 'routes.dart';
import 'services/cloudinary_service.dart';
import 'config/cloudinary_config.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialiser Firebase avec un nom d'application personnalisé
    await Firebase.initializeApp(
      name: 'monastors',
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialiser App Check en mode debug pour le développement
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );

    // Initialiser Cloudinary
    await CloudinaryService().initialize(
      cloudName: CloudinaryConfig.cloudName,
      apiKey: CloudinaryConfig.apiKey,
      apiSecret: CloudinaryConfig.apiSecret,
    );
    print('Firebase, App Check et Cloudinary initialisés avec succès');

    // La persistance de session est automatique sur mobile, rien à configurer ici
    runApp(const MyApp());
  } catch (e) {
    print('Erreur lors de l\'initialisation: $e');
    rethrow;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: Consumer<AppAuthProvider>(
        builder: (context, auth, _) => MaterialApp(
          title: 'MonaStore',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch: Colors.blue,
            useMaterial3: true,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
            useMaterial3: true,
          ),
          themeMode: auth.themeMode,
          initialRoute: AppRoutes.login,
          onGenerateRoute: AppRoutes.generateRoute,
        ),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
