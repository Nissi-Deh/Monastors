import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AnnouncementsAdminTab extends StatefulWidget {
  const AnnouncementsAdminTab({super.key});

  @override
  State<AnnouncementsAdminTab> createState() => _AnnouncementsAdminTabState();
}

class _AnnouncementsAdminTabState extends State<AnnouncementsAdminTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _type = 'info';
  bool _sending = false;

  Future<void> _sendAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    await FirebaseFirestore.instance.collection('announcements').add({
      'title': _titleController.text.trim(),
      'message': _messageController.text.trim(),
      'type': _type,
      'timestamp': FieldValue.serverTimestamp(),
    });
    setState(() => _sending = false);
    _titleController.clear();
    _messageController.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Annonce envoyée !')));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nouvelle annonce', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Titre'),
                  validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _messageController,
                  decoration: const InputDecoration(labelText: 'Message'),
                  maxLines: 2,
                  validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _type,
                  items: const [
                    DropdownMenuItem(value: 'info', child: Text('Information')),
                    DropdownMenuItem(value: 'promo', child: Text('Promotion')),
                    DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                    DropdownMenuItem(value: 'stock', child: Text('Fin de stock')),
                  ],
                  onChanged: (v) => setState(() => _type = v!),
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _sendAnnouncement,
                    child: _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Envoyer'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text('Historique des annonces', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('announcements').orderBy('timestamp', descending: true).limit(50).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('Aucune annonce'));
              }
              final ann = snapshot.data!.docs;
              return ListView.builder(
                itemCount: ann.length,
                itemBuilder: (context, index) {
                  final a = ann[index];
                  final date = a['timestamp'] != null ? DateFormat('dd/MM/yyyy HH:mm').format((a['timestamp'] as Timestamp).toDate()) : '';
                  return ListTile(
                    leading: Icon(
                      a['type'] == 'promo' ? Icons.local_offer : a['type'] == 'maintenance' ? Icons.build : a['type'] == 'stock' ? Icons.warning : Icons.info,
                      color: a['type'] == 'promo' ? Colors.green : a['type'] == 'maintenance' ? Colors.orange : a['type'] == 'stock' ? Colors.red : Colors.blue,
                    ),
                    title: Text(a['title'] ?? ''),
                    subtitle: Text('${a['message'] ?? ''}\n$date'),
                    isThreeLine: true,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
} 