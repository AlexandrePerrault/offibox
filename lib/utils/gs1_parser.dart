class Gs1DataMatrix {
  final String? cip13;
  final String? lot;
  final String? expiration; // YYYY-MM-DD

  Gs1DataMatrix({
    this.cip13,
    this.lot,
    this.expiration,
  });
}

Gs1DataMatrix parseGs1DataMatrix(String raw) {
  String? cip13;
  String? lot;
  String? expiration;

  final reg = RegExp(r'\((\d{2})\)([^()]+)');
  for (final match in reg.allMatches(raw)) {
    final ai = match.group(1);
    final value = match.group(2);

    switch (ai) {
      case '01': // GTIN / CIP13
        cip13 = value;
        break;
      case '10': // LOT
        lot = value;
        break;
      case '17': // DLUO YYMMDD
        if (value != null && value.length == 6) {
          expiration =
              '20${value.substring(0, 2)}-${value.substring(2, 4)}-${value.substring(4, 6)}';
        }
        break;
    }
  }

  return Gs1DataMatrix(
    cip13: cip13,
    lot: lot,
    expiration: expiration,
  );
}
