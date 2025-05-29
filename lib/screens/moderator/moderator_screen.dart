import 'package:flutter/material.dart';

class ModeratorScreen extends StatelessWidget {
  const ModeratorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace Vendeur / Modérateur'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            leading: Icon(Icons.receipt_long),
            title: Text('Gérer les commandes'),
          ),
          ListTile(
            leading: Icon(Icons.inventory),
            title: Text('Gérer le stock'),
          ),
        ],
      ),
    );
  }
} 