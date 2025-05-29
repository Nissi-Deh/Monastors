import 'package:flutter/material.dart';
import 'products_admin_tab.dart';
import 'orders_admin_tab.dart';
import 'users_admin_tab.dart';
import 'logs_admin_tab.dart';
import 'announcements_admin_tab.dart';
import 'package:provider/provider.dart';
import '../../providers/app_auth_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vous êtes déjà dans l’espace administrateur. Pour quitter, changez de rôle ou déconnectez-vous.'),
        duration: Duration(seconds: 2),
      ),
    );
    return false;
  }

  void _showProfileDialog() {
    final user = context.read<AppAuthProvider>().user;
    final nameController = TextEditingController(text: user?.name ?? '');
    ThemeMode themeMode = context.read<AppAuthProvider>().themeMode;
    File? imageFile;
    bool loading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> pickImage() async {
              final picker = ImagePicker();
              final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
              if (picked != null) {
                setState(() {
                  imageFile = File(picked.path);
                });
              }
            }

            Future<void> saveProfile() async {
              setState(() => loading = true);
              String? photoUrl = user?.photoUrl;
              if (imageFile != null) {
                final ref = FirebaseStorage.instance.ref().child('users/${user?.uid}/profile.jpg');
                await ref.putFile(imageFile!);
                photoUrl = await ref.getDownloadURL();
              }
              await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
                'name': nameController.text.trim(),
                'photoUrl': photoUrl,
              });
              context.read<AppAuthProvider>().setThemeMode(themeMode);
              setState(() => loading = false);
              if (context.mounted) Navigator.of(context).pop();
            }

            return AlertDialog(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: pickImage,
                      child: imageFile != null
                          ? CircleAvatar(backgroundImage: FileImage(imageFile!), radius: 28)
                          : (user?.photoUrl != null && user!.photoUrl!.isNotEmpty)
                              ? CircleAvatar(backgroundImage: NetworkImage(user.photoUrl!), radius: 28)
                              : const CircleAvatar(child: Icon(Icons.person), radius: 28),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(border: InputBorder.none, hintText: 'Nom'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Email : ${user?.email ?? ''}'),
                    const SizedBox(height: 16),
                    const Text('Apparence :'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.brightness_6),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<ThemeMode>(
                            isExpanded: true,
                            value: themeMode,
                            items: const [
                              DropdownMenuItem(value: ThemeMode.system, child: Text('Automatique')),
                              DropdownMenuItem(value: ThemeMode.light, child: Text('Clair')),
                              DropdownMenuItem(value: ThemeMode.dark, child: Text('Sombre')),
                            ],
                            onChanged: (mode) {
                              if (mode != null) setState(() => themeMode = mode);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fermer'),
                ),
                ElevatedButton.icon(
                  onPressed: loading ? null : saveProfile,
                  icon: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                  label: const Text('Enregistrer'),
                ),
                ElevatedButton.icon(
                  onPressed: loading
                      ? null
                      : () async {
                          await context.read<AppAuthProvider>().signOut();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            Navigator.pushReplacementNamed(context, '/login');
                          }
                        },
                  icon: const Icon(Icons.logout),
                  label: const Text('Se déconnecter'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Espace Administrateur'),
          actions: [
            IconButton(
              icon: const Icon(Icons.account_circle),
              tooltip: 'Profil',
              onPressed: _showProfileDialog,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.shopping_bag), text: 'Produits'),
              Tab(icon: Icon(Icons.receipt_long), text: 'Commandes'),
              Tab(icon: Icon(Icons.people), text: 'Utilisateurs'),
              Tab(icon: Icon(Icons.history), text: 'Logs'),
              Tab(icon: Icon(Icons.campaign), text: 'Annonces'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [
            ProductsAdminTab(),
            OrdersAdminTab(),
            UsersAdminTab(),
            LogsAdminTab(),
            AnnouncementsAdminTab(),
          ],
        ),
      ),
    );
  }
} 