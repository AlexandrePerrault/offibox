/// Données extraites d’un scan DataMatrix/GS1 (expiration, lot, n° de série).
class Gs1ScanPayload {
  const Gs1ScanPayload({
    this.expirationMMYY,
    this.lot,
    this.serialNumber,
  });

  /// Date de péremption au format "MM/YY" (ex. "03/29").
  final String? expirationMMYY;
  /// Numéro de lot (ex. "J1894" ou "MJ1894").
  final String? lot;
  /// Numéro de série (ex. "996845811089").
  final String? serialNumber;

  bool get hasAny =>
      (expirationMMYY?.isNotEmpty ?? false) ||
      (lot?.isNotEmpty ?? false) ||
      (serialNumber?.isNotEmpty ?? false);
}
