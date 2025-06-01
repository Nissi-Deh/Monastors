import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UsersAdminTab extends StatefulWidget {
  const UsersAdminTab({super.key});

  @override
  State<UsersAdminTab> createState() => _UsersAdminTabState();
}

class _UsersAdminTabState extends State<UsersAdminTab> {
  String _search = '';
  String _roleFilter = 'all';
  final int _pageSize = 20;
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _loadingMore = false;
  List<DocumentSnapshot> _users = [];
  Set<String> _selectedIds = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers({bool loadMore = false}) async {
    if (_loadingMore || (!_hasMore && loadMore)) return;
    setState(() => _loadingMore = true);
    Query query = FirebaseFirestore.instance.collection('users').orderBy('createdAt', descending: true);
    if (_lastDoc != null) {
      query = query.startAfterDocument(_lastDoc!);
    }
    final snap = await query.limit(_pageSize).get();
    if (snap.docs.isNotEmpty) {
      setState(() {
        _lastDoc = snap.docs.last;
        _users.addAll(snap.docs);
        _hasMore = snap.docs.length == _pageSize;
        _loadingMore = false;
      });
    } else {
      setState(() {
        _hasMore = false;
        _loadingMore = false;
      });
    }
  }

  void _resetAndFetch() {
    setState(() {
      _users.clear();
      _lastDoc = null;
      _hasMore = true;
    });
    _fetchUsers();
  }

  void _toggleSelectAll(List<DocumentSnapshot> filtered) {
    setState(() {
      if (_selectAll) {
        _selectedIds.clear();
        _selectAll = false;
      } else {
        _selectedIds = filtered.map((u) => u.id).toSet();
        _selectAll = true;
      }
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _logAction(String action, String targetUserId, {String? details}) async {
    final currentUser = FirebaseFirestore.instance.collection('users').doc(); // À remplacer par l'ID de l'admin connecté si disponible
    await FirebaseFirestore.instance.collection('logs').add({
      'action': action,
      'targetUserId': targetUserId,
      'details': details ?? '',
      'timestamp': FieldValue.serverTimestamp(),
      // 'adminId': currentUser.id, // À activer si tu as l'ID de l'admin connecté
    });
  }

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer les utilisateurs'),
        content: Text('Voulez-vous vraiment supprimer ${_selectedIds.length} utilisateur(s) ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm == true) {
      for (final id in _selectedIds) {
        await FirebaseFirestore.instance.collection('users').doc(id).delete();
        await _logAction('delete_user', id);
      }
      setState(() => _selectedIds.clear());
    }
  }

  Future<void> _changeRoleSelected(String role) async {
    for (final id in _selectedIds) {
      await FirebaseFirestore.instance.collection('users').doc(id).update({'role': role});
      await _logAction('change_role', id, details: 'Nouveau rôle : $role');
    }
    setState(() => _selectedIds.clear());
  }

  Future<void> logAction(String action, String targetUserId, {String? details}) => _logAction(action, targetUserId, details: details);

  @override
  Widget build(BuildContext context) {
    List<DocumentSnapshot> filtered = _users;
    if (_search.isNotEmpty) {
      filtered = filtered.where((u) {
        final name = (u['name'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        return name.contains(_search) || email.contains(_search);
      }).toList();
    }
    if (_roleFilter != 'all') {
      filtered = filtered.where((u) => u['role'] == _roleFilter).toList();
    }
    // Statistiques
    final total = _users.length;
    final admins = _users.where((u) => u['role'] == 'admin').length;
    final vendeurs = _users.where((u) => u['role'] == 'vendeur').length;
    final clients = _users.where((u) => u['role'] == 'user').length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatCard(label: 'Total', value: total, color: Colors.blue),
                _StatCard(label: 'Admins', value: admins, color: Colors.red),
                _StatCard(label: 'Vendeurs', value: vendeurs, color: Colors.green),
                _StatCard(label: 'Clients', value: clients, color: Colors.grey),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Rechercher',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (v) {
                  setState(() => _search = v.trim().toLowerCase());
                  _resetAndFetch();
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _selectAll && filtered.isNotEmpty,
                    onChanged: (_) => _toggleSelectAll(filtered),
                  ),
                  const Text('Tout sélectionner'),
                  const Spacer(),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: DropdownButton<String>(
                      value: _roleFilter,
                      isDense: true,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Tous')),
                        DropdownMenuItem(value: 'user', child: Text('Clients')),
                        DropdownMenuItem(value: 'admin', child: Text('Admins')),
                        DropdownMenuItem(value: 'vendeur', child: Text('Vendeurs')),
                      ],
                      onChanged: (v) {
                        setState(() => _roleFilter = v!);
                        _resetAndFetch();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_selectedIds.isNotEmpty)
          Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.blue.shade900.withOpacity(0.3)
                : Colors.blue.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_selectedIds.length} sélectionné(s)',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _deleteSelected,
                        icon: const Icon(Icons.delete),
                        label: const Text('Supprimer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade800
                              : Colors.white,
                        ),
                        dropdownColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade800
                            : Colors.white,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                        hint: Text(
                          'Changer rôle',
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade300
                                : Colors.grey.shade700,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'user', child: Text('Client')),
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                          DropdownMenuItem(value: 'vendeur', child: Text('Vendeur')),
                        ],
                        onChanged: (role) {
                          if (role != null) _changeRoleSelected(role);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('Aucun utilisateur trouvé'))
              : ListView.builder(
                  itemCount: filtered.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < filtered.length) {
                      return UserAdminTile(
                        user: filtered[index],
                        selected: _selectedIds.contains(filtered[index].id),
                        onSelect: () => _toggleSelect(filtered[index].id),
                        onLogAction: logAction,
                      );
                    } else {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: _loadingMore
                              ? const CircularProgressIndicator()
                              : ElevatedButton(
                                  onPressed: _fetchUsers,
                                  child: const Text('Charger plus'),
                                ),
                        ),
                      );
                    }
                  },
                ),
        ),
      ],
    );
  }
}

class UserAdminTile extends StatelessWidget {
  final user;
  final bool selected;
  final VoidCallback? onSelect;
  final Future<void> Function(String, String, {String? details})? onLogAction;

  const UserAdminTile({
    super.key,
    required this.user,
    this.selected = false,
    this.onSelect,
    this.onLogAction,
  });

  @override
  Widget build(BuildContext context) {
    final data = user.data() as Map<String, dynamic>;
    final disabled = data['disabled'] ?? false;
    final createdAt = data['createdAt'] as Timestamp?;
    final lastLogin = data['lastLogin'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () => _showUserDetails(context, data),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (onSelect != null)
              Checkbox(
                value: selected,
                  onChanged: (_) => onSelect!(),
                ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 24,
                backgroundImage: data['photoUrl'] != null && data['photoUrl'].toString().isNotEmpty
                    ? NetworkImage(data['photoUrl'])
                    : null,
                child: data['photoUrl'] == null || data['photoUrl'].toString().isEmpty
                    ? Text(
                        (data['name'] ?? 'A').substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 20),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
              Expanded(
                child: Text(
                            data['name'] ?? 'Sans nom',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildRoleChip(data['role'] ?? 'user'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['email'] ?? '',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Inscrit le ${DateFormat('dd/MM/yyyy').format(createdAt?.toDate() ?? DateTime.now())}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (lastLogin != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Dernière connexion: ${DateFormat('dd/MM/yyyy HH:mm').format(lastLogin.toDate())}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                                  ),
                                ],
                              ),
              ),
              PopupMenuButton<String>(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: const [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Modifier'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'role',
                    child: Row(
                      children: const [
                        Icon(Icons.person_outline, size: 20),
                        SizedBox(width: 8),
                        Text('Changer le rôle'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: disabled ? 'enable' : 'disable',
                    child: Row(
                      children: [
                        Icon(
                          disabled ? Icons.check_circle : Icons.cancel,
                          size: 20,
                          color: disabled ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(disabled ? 'Réactiver' : 'Désactiver'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: const [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Supprimer', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) => _handleMenuAction(context, value, data),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    Color color;
    IconData icon;
    String label;

    switch (role) {
      case 'admin':
        color = Colors.red;
        icon = Icons.admin_panel_settings;
        label = 'Admin';
        break;
      case 'vendeur':
        color = Colors.green;
        icon = Icons.store;
        label = 'Vendeur';
        break;
      default:
        color = Colors.grey;
        icon = Icons.person;
        label = 'Client';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: data['photoUrl'] != null && data['photoUrl'].toString().isNotEmpty
                  ? NetworkImage(data['photoUrl'])
                  : null,
              child: data['photoUrl'] == null || data['photoUrl'].toString().isEmpty
                  ? Text(
                      (data['name'] ?? 'A').substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontSize: 20),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['name'] ?? 'Sans nom',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    data['email'] ?? '',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(Icons.person_outline, 'Rôle', data['role'] ?? 'user'),
              if (data['createdAt'] != null)
                _buildDetailRow(
                  Icons.calendar_today,
                  'Inscrit le',
                  DateFormat('dd/MM/yyyy').format((data['createdAt'] as Timestamp).toDate()),
                ),
              if (data['lastLogin'] != null)
                _buildDetailRow(
                  Icons.access_time,
                  'Dernière connexion',
                  DateFormat('dd/MM/yyyy HH:mm').format((data['lastLogin'] as Timestamp).toDate()),
                ),
              if (data['phone'] != null)
                _buildDetailRow(Icons.phone, 'Téléphone', data['phone']),
              if (data['address'] != null)
                _buildDetailRow(Icons.location_on, 'Adresse', data['address']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '$label : ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenuAction(BuildContext context, String value, Map<String, dynamic> data) async {
    switch (value) {
      case 'edit':
        // TODO: Implémenter l'édition
        break;
      case 'role':
        final role = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Changer le rôle'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: Colors.red),
                  title: const Text('Administrateur'),
                  onTap: () => Navigator.of(context).pop('admin'),
                ),
                ListTile(
                  leading: const Icon(Icons.store, color: Colors.green),
                  title: const Text('Vendeur'),
                  onTap: () => Navigator.of(context).pop('vendeur'),
                ),
                ListTile(
                  leading: const Icon(Icons.person, color: Colors.grey),
                  title: const Text('Client'),
                  onTap: () => Navigator.of(context).pop('user'),
                ),
              ],
            ),
          ),
        );
        if (role != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.id).update({'role': role});
          if (onLogAction != null) {
            await onLogAction!('change_role', user.id, details: 'Nouveau rôle : $role');
          }
        }
        break;
      case 'enable':
      case 'disable':
        final disabled = value == 'disable';
        await FirebaseFirestore.instance.collection('users').doc(user.id).update({'disabled': disabled});
        if (onLogAction != null) {
          await onLogAction!(
            disabled ? 'disable_user' : 'enable_user',
            user.id,
          );
        }
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Supprimer l\'utilisateur'),
            content: const Text('Voulez-vous vraiment supprimer cet utilisateur ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await FirebaseFirestore.instance.collection('users').doc(user.id).delete();
          if (onLogAction != null) {
            await onLogAction!('delete_user', user.id);
          }
        }
        break;
    }
  }
}

class UserOrdersDialog extends StatelessWidget {
  final String userId;
  final String userName;
  const UserOrdersDialog({super.key, required this.userId, required this.userName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Commandes de $userName'),
      content: SizedBox(
        width: 350,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('orders').where('userId', isEqualTo: userId).orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Text('Aucune commande');
            }
            final orders = snapshot.data!.docs;
            return ListView.builder(
              shrinkWrap: true,
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return ListTile(
                  title: Text('Commande #${order.id.substring(0, 8)}'),
                  subtitle: Text('${order['totalAmount']} € - ${order['status']}'),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

class UserDetailDialog extends StatelessWidget {
  final user;
  const UserDetailDialog({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final data = user.data() as Map<String, dynamic>? ?? {};
    final photoUrl = data['photoUrl'] ?? '';
    final disabled = data['disabled'] ?? false;

    return AlertDialog(
      title: Row(
        children: [
          photoUrl.isNotEmpty
              ? CircleAvatar(backgroundImage: NetworkImage(photoUrl), radius: 28)
              : const CircleAvatar(child: Icon(Icons.person), radius: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              data['name'] ?? '',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.email, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Email : ${data['email'] ?? ''}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (data['phone'] != null)
              Row(
                children: [
                  const Icon(Icons.phone, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Téléphone : ${data['phone']}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            if (data['role'] != null)
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rôle : ${data['role']}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            if (data['createdAt'] != null)
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Inscrit le : ${DateFormat('dd/MM/yyyy').format((data['createdAt'] as Timestamp).toDate())}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            if (disabled)
              Row(
                children: const [
                  Icon(Icons.warning, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'Compte désactivé',
                    style: TextStyle(color: Colors.red, fontSize: 14),
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
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}
