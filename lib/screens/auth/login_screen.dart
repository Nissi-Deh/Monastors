import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_auth_provider.dart';
import '../../routes.dart'; // Ajouté pour accéder à AppRoutes

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      await context.read<AppAuthProvider>().signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(), // trim ici aussi
      );

      if (context.mounted && context.read<AppAuthProvider>().isAuthenticated) {
        final user = context.read<AppAuthProvider>().user;
        if (user != null) {
          if (user.role == 'admin') {
            Navigator.pushReplacementNamed(context, AppRoutes.admin);
          } else if (user.role == 'moderateur' || user.role == 'vendeur') {
            Navigator.pushReplacementNamed(context, AppRoutes.moderator);
          } else {
            Navigator.pushReplacementNamed(context, AppRoutes.main);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 32),
                          Center(
                            child: Image.asset(
                              'assets/images/logo.png',
                              height: 100,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'MonaStore',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer votre email';
                              }
                              if (!value.contains('@')) {
                                return 'Veuillez entrer un email valide';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: 'Mot de passe',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer votre mot de passe';
                              }
                              if (value.length < 6) {
                                return 'Le mot de passe doit contenir au moins 6 caractères';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          Consumer<AppAuthProvider>(
                            builder: (context, auth, child) {
                              if (auth.isLoading) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              return ElevatedButton(
                                onPressed: _login,
                                child: const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('Se connecter'),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, AppRoutes.register);
                            },
                            child: const Text('Pas encore de compte ? S\'inscrire'),
                          ),
                          Consumer<AppAuthProvider>(
                            builder: (context, auth, child) {
                              if (auth.error != null) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 16.0),
                                  child: Text(
                                    auth.error!,
                                    style: const TextStyle(color: Colors.red),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
