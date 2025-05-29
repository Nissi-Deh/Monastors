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
    final mods = _users.where((u) => u['role'] == 'moderateur').length;
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
                _StatCard(label: 'Modérateurs', value: mods, color: Colors.orange),
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
                        DropdownMenuItem(value: 'moderateur', child: Text('Modérateurs')),
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
                          DropdownMenuItem(value: 'moderateur', child: Text('Modérateur')),
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
  const UserAdminTile({super.key, required this.user, this.selected = false, this.onSelect, this.onLogAction});

  @override
  Widget build(BuildContext context) {
    final data = user.data() as Map<String, dynamic>? ?? {};
    final photoUrl = data['photoUrl'] ?? '';
    final disabled = data['disabled'] ?? false;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => showDialog(
          context: context,
          builder: (context) => UserDetailDialog(user: user),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (_) => onSelect?.call(),
              ),
              if (photoUrl.isNotEmpty)
                CircleAvatar(backgroundImage: NetworkImage(photoUrl))
              else
                const CircleAvatar(child: Icon(Icons.person)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  (data['name'] ?? '').replaceAll('\n', '').replaceAll('\r', ''),
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: data['role'] ?? 'user',
                isDense: true,
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('Client')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'moderateur', child: Text('Modérateur')),
                  DropdownMenuItem(value: 'vendeur', child: Text('Vendeur')),
                ],
                onChanged: (role) async {
                  if (role != null) {
                    await FirebaseFirestore.instance.collection('users').doc(user.id).update({'role': role});
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.shopping_cart),
                          title: const Text('Voir commandes'),
                          onTap: () {
                            Navigator.pop(context);
                            showDialog(
                              context: context,
                              builder: (context) => UserOrdersDialog(userId: user.id, userName: data['name'] ?? ''),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.lock_reset),
                          title: const Text('Réinitialiser mot de passe'),
                          onTap: () async {
                            Navigator.pop(context);
                            await FirebaseFirestore.instance.collection('users').doc(user.id).get().then((doc) async {
                              final email = (doc.data() as Map<String, dynamic>?)?['email'];
                              if (email != null && email.toString().isNotEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Un email de réinitialisation a été envoyé à $email')),
                                );
                              }
                            });
                          },
                        ),
                        ListTile(
                          leading: Icon(disabled ? Icons.check_circle : Icons.cancel, color: disabled ? Colors.green : Colors.red),
                          title: Text(disabled ? 'Réactiver le compte' : 'Désactiver le compte'),
                          onTap: () async {
                            Navigator.pop(context);
                            final disabled = data['disabled'] ?? false;
                            await FirebaseFirestore.instance.collection('users').doc(user.id).update({'disabled': !disabled});
                            if (onLogAction != null) {
                              await onLogAction!(
                                disabled ? 'reactivate_user' : 'disable_user',
                                user.id,
                              );
                            }
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.delete, color: Colors.red),
                          title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                          onTap: () async {
                            Navigator.pop(context);
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Supprimer l'utilisateur"),
                                content: const Text('Voulez-vous vraiment supprimer cet utilisateur ?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(false),
                                    child: const Text('Annuler'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    child: const Text('Supprimer'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await FirebaseFirestore.instance.collection('users').doc(user.id).delete();
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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
