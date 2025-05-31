import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtenir l'utilisateur actuel
  User? get currentUser => _auth.currentUser;

  // Stream pour écouter les changements d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Récupérer les données utilisateur depuis Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Erreur lors de la récupération des données utilisateur: $e');
    }
  }

  // Inscription
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user == null) throw Exception('Erreur lors de la création du compte');

      // Créer le profil utilisateur dans Firestore
      final UserModel newUser = UserModel(
        uid: user.uid,
        email: email,
        name: name,
        role: 'user',
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(user.uid).set(newUser.toMap());

      return newUser;
    } catch (e) {
      throw Exception('Erreur lors de l\'inscription: $e');
    }
  }

  // Connexion
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user == null) throw Exception('Erreur lors de la connexion');

      // Récupérer les données utilisateur depuis Firestore
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) throw Exception('Profil utilisateur non trouvé');

      return UserModel.fromMap(doc.data()!);
    } catch (e) {
      throw Exception('Erreur lors de la connexion: $e');
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Erreur lors de la déconnexion: $e');
    }
  }

  // Réinitialisation du mot de passe
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('Erreur lors de la réinitialisation du mot de passe: $e');
    }
  }

  // Mise à jour du profil utilisateur
  Future<UserModel> updateUserProfile({
    required String userId,
    String? name,
    String? photoUrl,
  }) async {
    try {
      final Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;

      if (updates.isEmpty) {
        throw Exception('Aucune mise à jour à effectuer');
      }

      await _firestore.collection('users').doc(userId).update(updates);
      
      // Récupérer les données mises à jour
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) throw Exception('Profil utilisateur non trouvé');

      return UserModel.fromMap(doc.data()!);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du profil: $e');
    }
  }
} 