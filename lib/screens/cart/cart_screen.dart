import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/cart_item.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panier'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Vider le panier'),
                  content: const Text('Voulez-vous vraiment vider le panier ?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () {
                        context.read<CartProvider>().clearCart();
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Confirmer'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<CartProvider>(
        builder: (context, cart, child) {
          if (cart.itemCount == 0) {
            return const Center(
              child: Text(
                'Votre panier est vide',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.items.length,
                  itemBuilder: (ctx, i) {
                    final item = cart.items.values.toList()[i];
                    return CartItemWidget(
                      id: item.product.id,
                      name: item.product.name,
                      price: item.product.price,
                      quantity: item.quantity,
                      imageUrl: item.product.imageUrl,
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${cart.totalAmount.toStringAsFixed(2)} €',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            _showShippingAddressDialog(context);
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Valider la commande'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showShippingAddressDialog(BuildContext context) {
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adresse de livraison'),
        content: TextField(
          controller: addressController,
          decoration: const InputDecoration(
            labelText: 'Adresse complète',
            hintText: 'Entrez votre adresse de livraison',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              if (addressController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Veuillez entrer une adresse de livraison'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.of(ctx).pop();
              // Afficher un dialogue ou une page indiquant que le paiement se fait en espèces ou par dépôt mobile.
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Paiement à effectuer'),
                  content: const Text(
                    'Merci pour votre commande !\n\nVeuillez effectuer le paiement en espèces à la livraison ou par dépôt Mobile Money/Airtel Money sur les numéros de la boutique.\n\nVotre commande sera traitée dès réception du paiement.'
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }
} 