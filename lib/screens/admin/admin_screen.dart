import 'package:flutter/material.dart';
import 'products_admin_tab.dart';
import 'orders_admin_tab.dart';
import 'users_admin_tab.dart';
import 'announcements_admin_tab.dart';
import 'package:provider/provider.dart';
import '../../providers/app_auth_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/cloudinary_service.dart';
import '../../config/cloudinary_config.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _currentIndex = 0;
  int _backPressCount = 0;
  DateTime? _lastBackPressTime;
  bool _isLoading = false;

  void _returnToHome() {
    setState(() {
      _currentIndex = 0;
    });
  }

  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      _returnToHome();
      return false;
    }

    final now = DateTime.now();
    if (_lastBackPressTime == null || 
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _backPressCount = 1;
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appuyez encore une fois pour quitter l\'application'),
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }

    if (_backPressCount == 1) {
      return true;
    }

    return false;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showProfileDialog() {
    final user = context.read<AppAuthProvider>().user;
    final nameController = TextEditingController(text: user?.name ?? '');
    ThemeMode themeMode = context.read<AppAuthProvider>().themeMode;
    File? imageFile;
    bool loading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> pickImage() async {
              try {
                final picker = ImagePicker();
                final picked = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 60,
                );
                if (picked != null) {
                  setState(() {
                    imageFile = File(picked.path);
                  });
                }
              } catch (e) {
                _showErrorSnackBar('Erreur lors de la sélection de l\'image');
              }
            }

            return AlertDialog(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: pickImage,
                      child: Stack(
                        children: [
                          imageFile != null
                              ? CircleAvatar(
                                  backgroundImage: FileImage(imageFile!),
                                  radius: 28,
                                )
                              : (user?.photoUrl != null && user!.photoUrl!.isNotEmpty)
                                  ? CircleAvatar(
                                      backgroundImage: NetworkImage(user.photoUrl!),
                                      radius: 28,
                                    )
                                  : const CircleAvatar(
                                      child: Icon(Icons.person),
                                      radius: 28,
                                    ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Nom',
                    ),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
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
                              DropdownMenuItem(
                                value: ThemeMode.system,
                                child: Text('Automatique'),
                              ),
                              DropdownMenuItem(
                                value: ThemeMode.light,
                                child: Text('Clair'),
                              ),
                              DropdownMenuItem(
                                value: ThemeMode.dark,
                                child: Text('Sombre'),
                              ),
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
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Déconnexion'),
                        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Annuler'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Déconnexion'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await context.read<AppAuthProvider>().signOut();
                    }
                  },
                  child: const Text('Déconnexion'),
                ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          setState(() => loading = true);
                          try {
                            if (imageFile != null) {
                              final url = await CloudinaryService().uploadImage(
                                imageFile: imageFile!,
                                folder: 'profiles',
                                publicId: user?.uid,
                              );
                              if (url != null) {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user?.uid)
                                    .update({
                                  'photoUrl': url,
                                });
                                await context.read<AppAuthProvider>().refreshUser();
                              }
                            }
                            if (nameController.text != user?.name) {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user?.uid)
                                  .update({
                                'name': nameController.text,
                              });
                              await context.read<AppAuthProvider>().refreshUser();
                            }
                            if (themeMode != context.read<AppAuthProvider>().themeMode) {
                              context.read<AppAuthProvider>().setThemeMode(themeMode);
                            }
                            if (mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profil mis à jour'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            _showErrorSnackBar('Erreur lors de la mise à jour du profil');
                          } finally {
                            if (mounted) {
                              setState(() => loading = false);
                            }
                          }
                        },
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHomeTab() {
    final user = context.watch<AppAuthProvider>().user;
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        try {
          await context.read<AppAuthProvider>().refreshUser();
        } catch (e) {
          _showErrorSnackBar('Erreur lors du rafraîchissement');
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                              ? NetworkImage(user.photoUrl!)
                              : null,
                          child: user?.photoUrl == null || user!.photoUrl!.isEmpty
                              ? Text(
                                  user?.name?.substring(0, 1).toUpperCase() ?? 'A',
                                  style: const TextStyle(fontSize: 24),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'Administrateur',
                                style: theme.textTheme.titleLarge,
                              ),
                              Text(
                                user?.email ?? '',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Actions rapides',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildActionCard(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Produits',
                  color: Colors.blue,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                _buildActionCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'Commandes',
                  color: Colors.orange,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _buildActionCard(
                  icon: Icons.people_outline,
                  title: 'Utilisateurs',
                  color: Colors.green,
                  onTap: () => setState(() => _currentIndex = 3),
                ),
                _buildActionCard(
                  icon: Icons.campaign_outlined,
                  title: 'Annonces',
                  color: Colors.purple,
                  onTap: () => setState(() => _currentIndex = 4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppAuthProvider>().user;
    final theme = Theme.of(context);
    
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: _currentIndex != 0,
          leading: _currentIndex != 0 ? IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _returnToHome,
          ) : null,
          elevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 32,
                  width: 32,
                ),
              ),
              const SizedBox(width: 12),
              const Flexible(
                child: Text(
                  'Espace Administrateur',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fonctionnalité à venir')),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Déconnexion'),
                    content: const Text('Voulez-vous vraiment vous déconnecter ?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Annuler'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Déconnexion'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await context.read<AppAuthProvider>().signOut();
                    if (mounted) {
                      Navigator.of(context).pushReplacementNamed('/login');
                    }
                  } catch (e) {
                    _showErrorSnackBar('Erreur lors de la déconnexion');
                  }
                }
              },
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showProfileDialog,
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
                child: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                    ? CircleAvatar(
                        backgroundImage: NetworkImage(user.photoUrl!),
                        radius: 18,
                      )
                    : CircleAvatar(
                        backgroundColor: theme.colorScheme.primary,
                        child: Text(
                          user?.name?.substring(0, 1).toUpperCase() ?? 'A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        radius: 18,
                      ),
              ),
            ),
          ],
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomeTab(),
            const ProductsAdminTab(),
            const OrdersAdminTab(),
            const UsersAdminTab(),
            const AnnouncementsAdminTab(),
          ],
        ),
        bottomNavigationBar: _currentIndex != 0
            ? BottomNavigationBar(
                currentIndex: _currentIndex - 1,
                onTap: (index) => setState(() => _currentIndex = index + 1),
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.shopping_bag_outlined),
                    label: 'Produits',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.receipt_long_outlined),
                    label: 'Commandes',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.people_outline),
                    label: 'Utilisateurs',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.campaign_outlined),
                    label: 'Annonces',
                  ),
                ],
              )
            : null,
      ),
    );
  }
} 