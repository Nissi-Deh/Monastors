import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AppAuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  ThemeMode _themeMode = ThemeMode.system;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  ThemeMode get themeMode => _themeMode;

  String _getUserFriendlyError(String error) {
    if (error.contains('wrong-password')) {
      return 'Le mot de passe est incorrect. Veuillez réessayer.';
    } else if (error.contains('user-not-found')) {
      return 'Aucun compte ne correspond à cet email.';
    } else if (error.contains('invalid-email')) {
      return 'L\'adresse email n\'est pas valide.';
    } else if (error.contains('user-disabled')) {
      return 'Ce compte a été désactivé.';
    } else if (error.contains('too-many-requests')) {
      return 'Trop de tentatives de connexion. Veuillez réessayer plus tard.';
    } else if (error.contains('network-request-failed')) {
      return 'Erreur de connexion réseau. Vérifiez votre connexion internet.';
    } else if (error.contains('email-already-in-use')) {
      return 'Cette adresse email est déjà utilisée.';
    } else if (error.contains('weak-password')) {
      return 'Le mot de passe est trop faible. Il doit contenir au moins 6 caractères.';
    } else if (error.contains('operation-not-allowed')) {
      return 'Cette opération n\'est pas autorisée.';
    } else if (error.contains('expired-action-code')) {
      return 'Le code de réinitialisation a expiré.';
    } else if (error.contains('invalid-action-code')) {
      return 'Le code de réinitialisation est invalide.';
    } else {
      return 'Une erreur est survenue. Veuillez réessayer.';
    }
  }

  AppAuthProvider() {
    // Écouter les changements d'état d'authentification
    _authService.authStateChanges.listen((user) async {
      if (user != null) {
        try {
          // Récupérer les données utilisateur depuis Firestore
          _user = await _authService.getUserData(user.uid);
          if (_user == null) {
            _error = 'Profil utilisateur non trouvé';
          }
        } catch (e) {
          _error = _getUserFriendlyError(e.toString());
          _user = null;
        }
      } else {
        _user = null;
      }
      notifyListeners();
    });
  } 

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.signUp(
        email: email,
        password: password,
        name: name,
      );
    } catch (e) {
      _error = _getUserFriendlyError(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.signIn(
        email: email,
        password: password,
      );
    } catch (e) {
      _error = _getUserFriendlyError(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.signOut();
      _user = null;
    } catch (e) {
      _error = _getUserFriendlyError(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.resetPassword(email);
    } catch (e) {
      _error = _getUserFriendlyError(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    String? name,
    String? photoUrl,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_user != null) {
        _user = await _authService.updateUserProfile(
          userId: _user!.uid,
          name: name,
          photoUrl: photoUrl,
        );
      }
    } catch (e) {
      _error = _getUserFriendlyError(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_user != null) {
      try {
        _user = await _authService.getUserData(_user!.uid);
        notifyListeners();
      } catch (e) {
        _error = _getUserFriendlyError(e.toString());
        notifyListeners();
      }
    }
  }
}
