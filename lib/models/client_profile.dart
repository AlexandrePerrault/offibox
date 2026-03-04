/// Fiche client depuis Firestore users/{uid} (appVariant, groupement).
/// Utilisée pour adapter l'app selon Offibox classique vs Offibox-CERP.
class ClientProfile {
  const ClientProfile({
    required this.uid,
    this.appVariant,
    this.groupement,
    this.cerpBaClient = false,
    this.cerpBaClientCode,
  });

  final String uid;
  final String? appVariant;
  final String? groupement;
  final bool cerpBaClient;
  final String? cerpBaClientCode;

  bool get cerpBaValidated =>
      cerpBaClient && (cerpBaClientCode != null && cerpBaClientCode!.trim().isNotEmpty);

  /// Construit depuis le document Firestore users/{uid}.
  static ClientProfile? fromUserDoc(String uid, Map<String, dynamic>? data) {
    if (data == null) return null;
    return ClientProfile(
      uid: uid,
      appVariant: data['appVariant'] as String?,
      groupement: data['groupement'] as String?,
      cerpBaClient: (data['cerpBaClient'] as bool?) ?? false,
      cerpBaClientCode: data['cerpBaClientCode'] as String?,
    );
  }
}
