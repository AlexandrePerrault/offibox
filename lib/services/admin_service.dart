import 'package:cloud_functions/cloud_functions.dart';

/// Statut licence : active (pro), gratuite (trial en cours), expirée.
enum LicenseStatus { active, free, expired }

/// Client affiché dans le tableau de bord admin.
class AdminUser {
  const AdminUser({
    required this.uid,
    required this.email,
    required this.plan,
    required this.status,
    this.trialEndsAt,
    this.createdAt,
  });

  final String uid;
  final String email;
  final String plan;
  final LicenseStatus status;
  final DateTime? trialEndsAt;
  final DateTime? createdAt;

  static LicenseStatus _parseStatus(String s) {
    switch (s) {
      case 'active':
        return LicenseStatus.active;
      case 'expired':
        return LicenseStatus.expired;
      default:
        return LicenseStatus.free;
    }
  }

  factory AdminUser.fromMap(Map<String, dynamic> m) {
    DateTime? parse(String? s) {
      if (s == null) return null;
      return DateTime.tryParse(s);
    }

    return AdminUser(
      uid: m['uid'] as String? ?? '',
      email: m['email'] as String? ?? '',
      plan: m['plan'] as String? ?? 'trial',
      status: _parseStatus(m['status'] as String? ?? 'free'),
      trialEndsAt: parse(m['trialEndsAt'] as String?),
      createdAt: parse(m['createdAt'] as String?),
    );
  }

  String get statusLabel {
    switch (status) {
      case LicenseStatus.active:
        return 'Active';
      case LicenseStatus.free:
        return 'Gratuite (essai)';
      case LicenseStatus.expired:
        return 'Expirée';
    }
  }
}

/// Service admin : récupère la liste des clients (réservé offibox17@gmail.com).
class AdminService {
  AdminService._();

  static const String adminEmail = 'offibox17@gmail.com';

  /// Emails exemptés de la limite de 5 appareils (admins Offibox)
  static const List<String> _deviceLimitExempt = [
    'offibox17@gmail.com',
    'offibox@gmail.com',
    'offibox@offibox.fr',
  ];

  static bool isAdmin(String? email) =>
      email != null && email.toLowerCase() == adminEmail;

  static bool isDeviceLimitExempt(String? email) =>
      email != null &&
      _deviceLimitExempt.any((e) => e.toLowerCase() == email.toLowerCase());

  static Future<List<AdminUser>> getUsers() async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('getAdminUsers')
        .call<Map<String, dynamic>>();

    final data = result.data as Map<String, dynamic>?;
    if (data == null) return [];

    final list = data['users'] as List<dynamic>? ?? [];
    return list
        .map((e) => AdminUser.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
