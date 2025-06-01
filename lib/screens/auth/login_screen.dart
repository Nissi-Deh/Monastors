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
  bool _obscurePassword = true;
  OverlayEntry? _overlayEntry;
  bool _isLoading = false;
  bool _isAuthenticating = false;
  DateTime? _lastLoginAttempt;
  int _loginAttempts = 0;
  static const int _maxLoginAttempts = 3;
  static const Duration _loginCooldown = Duration(minutes: 1);
  static const Duration _minAttemptInterval = Duration(seconds: 2);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showErrorOverlay(String message) {
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 300),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -50 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red.shade200,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: Colors.red.shade700,
                    onPressed: () {
                      _removeOverlay();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _removeOverlay();
      }
    });
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate() || _isAuthenticating) {
      return;
    }

    final now = DateTime.now();
    if (_lastLoginAttempt != null) {
      final timeSinceLastAttempt = now.difference(_lastLoginAttempt!);
      
      if (timeSinceLastAttempt < _minAttemptInterval) {
        _showErrorOverlay('Veuillez patienter avant de réessayer.');
        return;
      }
      
      if (_loginAttempts >= _maxLoginAttempts && timeSinceLastAttempt < _loginCooldown) {
        final remainingTime = _loginCooldown - timeSinceLastAttempt;
        final minutes = remainingTime.inMinutes;
        final seconds = (remainingTime.inSeconds % 60).toString().padLeft(2, '0');
        _showErrorOverlay('Trop de tentatives. Veuillez patienter $minutes:$seconds.');
        return;
      }
    }
    
    _lastLoginAttempt = now;
    _loginAttempts++;
    
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _isAuthenticating = true;
    });
    
    try {
      final authProvider = context.read<AppAuthProvider>();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Vérifier si l'utilisateur est déjà connecté
      if (authProvider.isAuthenticated) {
        _loginAttempts = 0;
        final user = authProvider.user;
        if (user != null) {
          String route;
          switch (user.role) {
            case 'admin':
              route = AppRoutes.admin;
              break;
            case 'moderateur':
            case 'vendeur':
              route = AppRoutes.moderator;
              break;
            default:
              route = AppRoutes.main;
          }
          if (mounted) {
            Navigator.pushReplacementNamed(context, route);
          }
          return;
        }
      }

      // Tenter la connexion
      await authProvider.signIn(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (authProvider.isAuthenticated) {
        _loginAttempts = 0;
        final user = authProvider.user;
        if (user != null) {
          String route;
          switch (user.role) {
            case 'admin':
              route = AppRoutes.admin;
              break;
            case 'moderateur':
            case 'vendeur':
              route = AppRoutes.moderator;
              break;
            default:
              route = AppRoutes.main;
          }
          if (mounted) {
            Navigator.pushReplacementNamed(context, route);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorOverlay('Une erreur est survenue lors de la connexion. Veuillez réessayer.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loginAttempts = 0;
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
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            obscureText: _obscurePassword,
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
                              if (auth.error != null) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) {
                                    _showErrorOverlay(auth.error!);
                                    auth.clearError();
                                  }
                                });
                              }
                              return ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  disabledBackgroundColor: Theme.of(context).primaryColor.withOpacity(0.5),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Se connecter',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
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
