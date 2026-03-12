import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:offibox/services/admin_service.dart';

/// Tableau de bord admin : liste des clients avec statut licence.
/// Accessible uniquement à offibox17@gmail.com.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  List<AdminUser> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final users = await AdminService.getUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _loading = false;
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message ?? 'Erreur ${e.code}';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Color _statusColor(AdminUser u) {
    switch (u.status) {
      case LicenseStatus.active:
        return Colors.green;
      case LicenseStatus.free:
        return Colors.blue;
      case LicenseStatus.expired:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Tableau de bord Offibox',
          style: TextStyle(fontFamily: 'Spinnaker'),
        ),
        backgroundColor: const Color(0xFF5A9094),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                          columns: const [
                            DataColumn(label: Text('E-mail', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Plan', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Statut licence', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Fin essai', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _users.map((u) {
                            return DataRow(
                              cells: [
                                DataCell(Text(u.email, style: const TextStyle(fontFamily: 'Spinnaker'))),
                                DataCell(Text(u.plan, style: const TextStyle(fontFamily: 'Spinnaker'))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _statusColor(u).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      u.statusLabel,
                                      style: TextStyle(
                                        color: _statusColor(u),
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Spinnaker',
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    u.trialEndsAt != null
                                        ? '${u.trialEndsAt!.day.toString().padLeft(2, '0')}/${u.trialEndsAt!.month.toString().padLeft(2, '0')}/${u.trialEndsAt!.year}'
                                        : '-',
                                    style: const TextStyle(fontFamily: 'Spinnaker'),
                                  ),
                                ),
                                DataCell(
                                  u.plan == 'pro'
                                      ? const SizedBox.shrink()
                                      : _ExtendTrialButton(
                                          uid: u.uid,
                                          email: u.email,
                                          onDone: _load,
                                        ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _ExtendTrialButton extends StatelessWidget {
  const _ExtendTrialButton({
    required this.uid,
    required this.email,
    required this.onDone,
  });

  final String uid;
  final String? email;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        // TODO: appeler une Cloud Function pour prolonger l'essai (uid)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Prolonger essai: ${email ?? uid}')),
        );
        onDone();
      },
      child: const Text('Prolonger'),
    );
  }
}
