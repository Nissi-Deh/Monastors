import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class LogsAdminTab extends StatelessWidget {
  const LogsAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('logs').orderBy('timestamp', descending: true).limit(100).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Aucune activité enregistrée'));
        }
        final logs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            final date = log['timestamp'] != null ? DateFormat('dd/MM/yyyy HH:mm').format((log['timestamp'] as Timestamp).toDate()) : '';
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text('${log['action']} sur utilisateur ${log['targetUserId']}'),
              subtitle: Text('${log['details'] ?? ''}\n$date'),
              isThreeLine: true,
            );
          },
        );
      },
    );
  }
} 