import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/category_model.dart';
import '../../services/cloudinary_service.dart';
import '../../config/cloudinary_config.dart';

class ProductsAdminTab extends StatelessWidget {
  const ProductsAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucun produit'));
          }
          final products = snapshot.data!.docs;
          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: product['imageUrl'] != null && product['imageUrl'].toString().isNotEmpty
                      ? Image.network(product['imageUrl'], width: 50, height: 50, fit: BoxFit.cover)
                      : const Icon(Icons.image, size: 40),
                  title: Text(product['name'] ?? ''),
                  subtitle: Text('${product['price']} FCFA'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            builder: (context) => ProductFormDialog(product: product),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await FirebaseFirestore.instance.collection('products').doc(product.id).delete();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showDialog(
            context: context,
            builder: (context) => ProductFormDialog(),
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'Ajouter un produit',
      ),
    );
  }
}

class ProductFormDialog extends StatefulWidget {
  final DocumentSnapshot? product;
  const ProductFormDialog({super.key, this.product});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  String? _selectedCategoryId;
  String? _selectedSubCategoryId;
  bool _isActive = true;
  List<File> _imageFiles = [];
  List<String> _imageUrls = [];
  bool _loading = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?['name'] ?? '');
    _descController = TextEditingController(text: widget.product?['description'] ?? '');
    _priceController = TextEditingController(text: widget.product?['price']?.toString() ?? '');
    _stockController = TextEditingController(text: widget.product?['stock']?.toString() ?? '');
    
    final productCategoryId = widget.product?['categoryId'] as String?;
    if (productCategoryId != null) {
      final isSubCategory = CategoryModel.predefinedCategories
          .any((category) => category.subCategories?.any((sub) => sub.id == productCategoryId) ?? false);
      
      if (isSubCategory) {
        for (var category in CategoryModel.predefinedCategories) {
          if (category.subCategories?.any((sub) => sub.id == productCategoryId) ?? false) {
            _selectedCategoryId = category.id;
            _selectedSubCategoryId = productCategoryId;
            break;
          }
        }
      } else {
        _selectedCategoryId = productCategoryId;
      }
    }
    
    _isActive = widget.product?['isActive'] ?? true;
    if (widget.product?['images'] != null) {
      _imageUrls = List<String>.from(widget.product!['images']);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    // Supprimer les messages précédents
    _removeOverlay();
    ScaffoldMessenger.of(context).clearSnackBars();

    // Créer un OverlayEntry pour le message
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isError ? Colors.red : Colors.green,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.check_circle_outline,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: _removeOverlay,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Afficher le message
    overlay.insert(_overlayEntry!);

    // Supprimer le message après un délai
    Future.delayed(Duration(seconds: isError ? 3 : 2), () {
      if (mounted && _overlayEntry != null) {
        _removeOverlay();
      }
    });
  }

  Future<void> _pickImage() async {
    if (_imageFiles.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 photos autorisées')),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null) {
      setState(() {
        _imageFiles.add(File(picked.path));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      if (index < _imageFiles.length) {
        _imageFiles.removeAt(index);
      } else {
        _imageUrls.removeAt(index - _imageFiles.length);
      }
    });
  }

  Future<String?> _uploadImage(File imageFile, String productId) async {
    try {
      final cloudinary = CloudinaryService();
      
      // Vérifier si Cloudinary est initialisé
      if (!cloudinary.isInitialized) {
        print('Initialisation de Cloudinary...');
        await cloudinary.initialize(
          cloudName: CloudinaryConfig.cloudName,
          apiKey: CloudinaryConfig.apiKey,
          apiSecret: CloudinaryConfig.apiSecret,
        );
        print('Cloudinary initialisé avec succès');
      }

      print('Début de l\'upload vers Cloudinary...');
      print('Détails de l\'upload:');
      print('- Dossier: products/$productId');
      print('- Public ID: ${DateTime.now().millisecondsSinceEpoch}');
      print('- Taille du fichier: ${await imageFile.length()} bytes');

      // Tentative d'upload avec retry
      int retryCount = 0;
      const maxRetries = 3;
      String? url;

      while (retryCount < maxRetries) {
        try {
          url = await cloudinary.uploadImage(
            imageFile: imageFile,
            folder: 'products/$productId',
            publicId: '${DateTime.now().millisecondsSinceEpoch}',
          );
          
          if (url != null) {
            print('Upload réussi: $url');
            break;
          }
        } catch (e) {
          print('Tentative ${retryCount + 1} échouée: $e');
          retryCount++;
          if (retryCount < maxRetries) {
            print('Nouvelle tentative dans ${retryCount} secondes...');
            await Future.delayed(Duration(seconds: retryCount));
          }
        }
      }

      if (url == null) {
        print('Échec de l\'upload après $maxRetries tentatives');
        _showMessage('Erreur lors de l\'upload de l\'image', isError: true);
      }
      
      return url;
    } catch (e) {
      print('Erreur lors de l\'upload de l\'image: $e');
      _showMessage('Erreur lors de l\'upload de l\'image: ${e.toString()}', isError: true);
      return null;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      _showMessage('Veuillez sélectionner une catégorie', isError: true);
      return;
    }

    // Vérifier le nombre minimum de photos
    if (_imageFiles.length + _imageUrls.length < 2) {
      _showMessage('Veuillez ajouter au moins 2 photos', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      // Créer ou obtenir l'ID du document produit
      final productRef = widget.product == null
          ? FirebaseFirestore.instance.collection('products').doc()
          : FirebaseFirestore.instance.collection('products').doc(widget.product!.id);

      // Upload des nouvelles images
      List<String> uploadedImageUrls = [];
      for (var imageFile in _imageFiles) {
        final url = await _uploadImage(imageFile, productRef.id);
        if (url != null) {
          uploadedImageUrls.add(url);
        }
      }

      // Combiner les URLs des nouvelles images avec les URLs existantes
      final allImageUrls = [...uploadedImageUrls, ..._imageUrls];

      if (allImageUrls.isEmpty) {
        throw Exception('Aucune image n\'a pu être uploadée');
    }

    final data = {
      'name': _nameController.text.trim(),
      'description': _descController.text.trim(),
      'price': double.tryParse(_priceController.text) ?? 0.0,
      'stock': int.tryParse(_stockController.text) ?? 0,
        'categoryId': _selectedSubCategoryId ?? _selectedCategoryId,
      'isActive': _isActive,
        'imageUrl': allImageUrls.first,
      'createdAt': widget.product?['createdAt'] ?? FieldValue.serverTimestamp(),
      'sellerId': widget.product?['sellerId'] ?? '',
        'images': allImageUrls,
    };

      // Sauvegarder les données du produit
      await productRef.set(data, SetOptions(merge: true));
      
      if (mounted) {
        Navigator.of(context).pop();
        _showMessage('Produit enregistré avec succès');
      }
    } catch (e) {
      print('Erreur lors de l\'enregistrement du produit: $e');
      if (mounted) {
        _showMessage('Erreur lors de l\'enregistrement: ${e.toString()}', isError: true);
    }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AlertDialog(
      title: Text(widget.product == null ? 'Ajouter un produit' : 'Modifier le produit'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                  // Section des photos
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Photos du produit',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (_imageFiles.length + _imageUrls.length) < 2 ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_imageFiles.length + _imageUrls.length}/5',
                              style: TextStyle(
                                color: (_imageFiles.length + _imageUrls.length) < 2 ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if ((_imageFiles.length + _imageUrls.length) < 2)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning,
                                color: Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Minimum 2 photos requises',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (_imageFiles.length + _imageUrls.length < 5)
              GestureDetector(
                onTap: _pickImage,
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.add_a_photo, size: 32),
                                ),
                              ),
                            ..._imageFiles.asMap().entries.map((entry) {
                              return _buildImageContainer(
                                FileImage(entry.value),
                                entry.key,
                              );
                            }).toList(),
                            ..._imageUrls.asMap().entries.map((entry) {
                              return _buildImageContainer(
                                NetworkImage(entry.value),
                                entry.key + _imageFiles.length,
                              );
                            }).toList(),
                          ],
                ),
                      ),
                    ],
              ),
              const SizedBox(height: 16),
                  // Reste du formulaire
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom du produit'),
                validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
                validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Prix (FCFA)'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(labelText: 'Stock'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.8,
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Catégorie principale',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Sélectionner une catégorie'),
                        ),
                        ...CategoryModel.predefinedCategories.map((category) {
                          return DropdownMenuItem(
                            value: category.id,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(category.icon, size: 18),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    category.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                          _selectedSubCategoryId = null;
                        });
                      },
                      validator: (v) => v == null ? 'Veuillez sélectionner une catégorie' : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_selectedCategoryId != null)
                    Builder(
                      builder: (context) {
                        final category = CategoryModel.predefinedCategories.firstWhere(
                          (c) => c.id == _selectedCategoryId,
                          orElse: () => CategoryModel.predefinedCategories.first,
                        );
                        if (category.subCategories == null || category.subCategories!.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return SizedBox(
                          width: MediaQuery.of(context).size.width * 0.8,
                          child: DropdownButtonFormField<String>(
                            value: _selectedSubCategoryId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Sous-catégorie',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Sélectionner une sous-catégorie'),
                              ),
                              ...category.subCategories!.map((subCategory) {
                                return DropdownMenuItem(
                                  value: subCategory.id,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(subCategory.icon, size: 18),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          subCategory.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedSubCategoryId = value;
                              });
                            },
                          ),
                        );
                      },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                title: const Text('Produit actif'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enregistrer'),
        ),
      ],
        ),
        if (_loading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildImageContainer(ImageProvider image, int index) {
    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        image: DecorationImage(
          image: image,
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: () => _removeImage(index),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
