import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrdersAdminTab extends StatelessWidget {
  const OrdersAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Aucune commande'));
        }
        final orders = snapshot.data!.docs;
        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text('Commande #${order.id.substring(0, 8)}'),
                subtitle: Text('${order['totalAmount']} € - ${order['status']}'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      builder: (context) => OrderDetailDialog(order: order),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class OrderDetailDialog extends StatefulWidget {
  final order;
  const OrderDetailDialog({super.key, required this.order});

  @override
  State<OrderDetailDialog> createState() => _OrderDetailDialogState();
}

class _OrderDetailDialogState extends State<OrderDetailDialog> {
  late String _status;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _status = widget.order['status'] ?? 'pending';
  }

  Future<void> _updateStatus() async {
    setState(() => _loading = true);
    await FirebaseFirestore.instance.collection('orders').doc(widget.order.id).update({'status': _status});
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Commande #${widget.order.id.substring(0, 8)}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Montant total : ${widget.order['totalAmount']} €'),
          const SizedBox(height: 8),
          Text('Adresse : ${widget.order['shippingAddress'] ?? 'Non renseignée'}'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Statut'),
            items: const [
              DropdownMenuItem(value: 'pending', child: Text('En attente')),
              DropdownMenuItem(value: 'processing', child: Text('En cours de traitement')),
              DropdownMenuItem(value: 'shipped', child: Text('Expédiée')),
              DropdownMenuItem(value: 'delivered', child: Text('Livrée')),
              DropdownMenuItem(value: 'cancelled', child: Text('Annulée')),
            ],
            onChanged: (v) => setState(() => _status = v!),
          ),
          const SizedBox(height: 16),
          const Text('Articles :', style: TextStyle(fontWeight: FontWeight.bold)),
          ...((widget.order['items'] as List<dynamic>).map((item) {
            final product = item['product'] as Map<String, dynamic>;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: product['imageUrl'] != null && product['imageUrl'].toString().isNotEmpty
                  ? Image.network(product['imageUrl'], width: 40, height: 40, fit: BoxFit.cover)
                  : const Icon(Icons.image, size: 32),
              title: Text(product['name'] ?? ''),
              subtitle: Text('Quantité : ${item['quantity']}'),
              trailing: Text('${product['price']} €'),
            );
          })),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _updateStatus,
          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enregistrer'),
        ),
      ],
    );
  }
} 