import 'dart:async';

import 'package:offibox/utils/gs1_scan_payload.dart';

class ScanController {
  Timer? _timer;

  /// Traite un scan : si DataMatrix/GS1 et [onScanDataMatrix] fourni, l’appelle avec CIP13 et payload ;
  /// sinon si GS1 appelle [onSearch](cip13). Retourne (isDataMatrix, cip13, payload).
  ({bool isDataMatrix, String? cip13, Gs1ScanPayload? payload}) handle({
    required String raw,
    required void Function(String) onSearch,
    void Function(String cip13, Gs1ScanPayload? payload)? onScanDataMatrix,
  }) {
    final normalized = raw.trim();

    if (normalized.isEmpty) return (isDataMatrix: false, cip13: null, payload: null);

    final parsed = _parseGs1(normalized);
    if (parsed != null) {
      final cip13 = parsed.cip13;
      final payload = parsed.payload;
      if (onScanDataMatrix != null) {
        onScanDataMatrix(cip13, payload);
        return (isDataMatrix: true, cip13: cip13, payload: payload);
      }
      onSearch(cip13);
      return (isDataMatrix: true, cip13: cip13, payload: payload);
    }

    onSearch(normalized);
    return (isDataMatrix: false, cip13: null, payload: null);
  }

  /// Parse GS1 : (01)14 → CIP13, (21) → série, (17)6 → expiration MM/YY, (10) → lot.
  /// Retourne (cip13, payload) ou null.
  ({String cip13, Gs1ScanPayload? payload})? _parseGs1(String raw) {
    final match = RegExp(r'01(\d{14})').firstMatch(raw);
    if (match == null) return null;

    final gtin14 = match.group(1)!;
    final cip13 = gtin14.startsWith('0') ? gtin14.substring(1) : gtin14;

    int offset = match.start + 2 + 14; // après 01 + 14 chiffres
    String? expirationMMYY;
    String? lot;
    String? serialNumber;

    // (21) numéro de série — variable, souvent que des chiffres jusqu’à (17)
    final rest = raw.substring(offset);
    final ai21 = RegExp(r'21(\d+)');
    final ai17 = RegExp(r'17(\d{6})');
    // (10) lot : optionnellement précédé du séparateur de groupe (0x1d ou ?)
    final ai10 = RegExp(r'10[\x1d?]?([^\x1d?]+)');

    final m21 = ai21.firstMatch(rest);
    if (m21 != null) serialNumber = m21.group(1);

    final m17 = ai17.firstMatch(rest);
    if (m17 != null) {
      final yymmdd = m17.group(1)!;
      if (yymmdd.length >= 4) {
        final yy = yymmdd.substring(0, 2);
        final mm = yymmdd.substring(2, 4);
        expirationMMYY = '$mm/$yy';
      }
    }

    final m10 = ai10.firstMatch(rest);
    if (m10 != null) {
      final batch = m10.group(1)?.trim();
      if (batch != null && batch.isNotEmpty) lot = batch;
    }

    final payload = (expirationMMYY != null || lot != null || serialNumber != null)
        ? Gs1ScanPayload(
            expirationMMYY: expirationMMYY,
            lot: lot,
            serialNumber: serialNumber,
          )
        : null;

    return (cip13: cip13, payload: payload);
  }

  void dispose() {
    _timer?.cancel();
  }
}
