import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final IconData icon;
  final String description;
  final bool isActive;
  final List<CategoryModel>? subCategories;

  CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    this.isActive = true,
    this.subCategories,
  });

  static List<CategoryModel> predefinedCategories = [
    CategoryModel(
      id: 'electronics',
      name: 'Électronique',
      icon: Icons.devices,
      description: 'Smartphones, ordinateurs, accessoires tech',
    ),
    CategoryModel(
      id: 'fashion',
      name: 'Mode',
      icon: Icons.shopping_bag,
      description: 'Vêtements, chaussures, accessoires',
      subCategories: [
        CategoryModel(
          id: 'fashion-men',
          name: 'Homme',
          icon: Icons.man,
          description: 'Vêtements et accessoires pour homme',
        ),
        CategoryModel(
          id: 'fashion-women',
          name: 'Femme',
          icon: Icons.woman,
          description: 'Vêtements et accessoires pour femme',
        ),
        CategoryModel(
          id: 'fashion-kids',
          name: 'Enfant',
          icon: Icons.child_care,
          description: 'Vêtements et accessoires pour enfants',
        ),
      ],
    ),
    CategoryModel(
      id: 'home',
      name: 'Maison & Décoration',
      icon: Icons.home,
      description: 'Meubles, décoration, électroménager',
    ),
    CategoryModel(
      id: 'beauty',
      name: 'Beauté & Cosmétiques',
      icon: Icons.face,
      description: 'Produits de beauté, parfums, soins',
    ),
    CategoryModel(
      id: 'sports',
      name: 'Sport & Loisirs',
      icon: Icons.sports_basketball,
      description: 'Équipement sportif, loisirs, jeux',
    ),
    CategoryModel(
      id: 'food',
      name: 'Alimentation',
      icon: Icons.restaurant,
      description: 'Produits alimentaires, boissons',
    ),
    CategoryModel(
      id: 'books',
      name: 'Livres & Culture',
      icon: Icons.book,
      description: 'Livres, musique, films',
    ),
    CategoryModel(
      id: 'toys',
      name: 'Jouets & Enfants',
      icon: Icons.toys,
      description: 'Jouets, puériculture, jeux éducatifs',
    ),
    CategoryModel(
      id: 'garden',
      name: 'Jardin & Bricolage',
      icon: Icons.eco,
      description: 'Outils, plantes, bricolage',
    ),
    CategoryModel(
      id: 'pets',
      name: 'Animaux',
      icon: Icons.pets,
      description: 'Nourriture, accessoires pour animaux',
    ),
  ];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon.codePoint,
      'description': description,
      'isActive': isActive,
      'subCategories': subCategories?.map((cat) => cat.toMap()).toList(),
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      icon: IconData(map['icon'] ?? Icons.category.codePoint, fontFamily: 'MaterialIcons'),
      description: map['description'] ?? '',
      isActive: map['isActive'] ?? true,
      subCategories: map['subCategories'] != null
          ? List<CategoryModel>.from(
              (map['subCategories'] as List).map((x) => CategoryModel.fromMap(x)))
          : null,
    );
  }
} 