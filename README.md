# MonaStore

Application e-commerce de vêtements d'occasion développée avec Flutter.

## Fonctionnalités

- Authentification des utilisateurs
- Gestion des produits
- Panier d'achat
- Profils utilisateurs
- Notifications
- Upload d'images avec Cloudinary
- Thème clair/sombre

## Prérequis

- Flutter SDK (version >=3.0.0)
- Dart SDK (version >=3.0.0)
- Android Studio / VS Code
- Un compte Firebase
- Un compte Cloudinary

## Configuration

1. Clonez le repository
```bash
git clone https://github.com/votre-username/monastors.git
cd monastors
```

2. Installez les dépendances
```bash
flutter pub get
```

3. Configurez Firebase
- Créez un projet Firebase
- Ajoutez votre application Android
- Téléchargez et placez le fichier `google-services.json` dans `android/app/`

4. Configurez Cloudinary
- Créez un compte Cloudinary
- Créez un fichier `lib/config/cloudinary_config.dart` avec vos identifiants

## Démarrage

```bash
flutter run
```

## Structure du projet

```
lib/
  ├── config/         # Configuration (Cloudinary, etc.)
  ├── models/         # Modèles de données
  ├── providers/      # Gestion d'état (Provider)
  ├── screens/        # Écrans de l'application
  ├── services/       # Services (Auth, Cloudinary, etc.)
  └── main.dart       # Point d'entrée
```

## Contribution

1. Fork le projet
2. Créez une branche pour votre fonctionnalité (`git checkout -b feature/AmazingFeature`)
3. Committez vos changements (`git commit -m 'Add some AmazingFeature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrez une Pull Request

## Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.
