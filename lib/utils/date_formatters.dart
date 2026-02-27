
  // ==========================================================================
  // 🗓️ FORMAT DATES
  // ==========================================================================

  String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String formatAnsmDate(String raw) {
    if (raw.isEmpty) return raw;

    final iso = DateTime.tryParse(raw);
    if (iso != null) {
      return '${iso.day.toString().padLeft(2, '0')}/'
          '${iso.month.toString().padLeft(2, '0')}/'
          '${iso.year}';
    }

    final jsRegex = RegExp(r'\w{3}\s(\w{3})\s(\d{1,2})\s(\d{4})');
    final match = jsRegex.firstMatch(raw);
    if (match != null) {
      const months = {
        'Jan': '01',
        'Feb': '02',
        'Mar': '03',
        'Apr': '04',
        'May': '05',
        'Jun': '06',
        'Jul': '07',
        'Aug': '08',
        'Sep': '09',
        'Oct': '10',
        'Nov': '11',
        'Dec': '12',
      };
      final month = months[match.group(1)];
      final day = match.group(2)!.padLeft(2, '0');
      final year = match.group(3)!;
      if (month != null) return '$day/$month/$year';
    }

    return raw;
  }

String formatDateFr(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}



 String formatToFrDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return s;

  // 1) FR : d/M/yyyy ou dd/MM/yyyy (avec ou sans heure)
  final fr = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})(?:\s+\d{1,2}:\d{2}:\d{2})?$');
  final mFr = fr.firstMatch(s);
  if (mFr != null) {
    final d = mFr.group(1)!.padLeft(2, '0');
    final m = mFr.group(2)!.padLeft(2, '0');
    final y = mFr.group(3)!;
    return '$d/$m/$y';
  }

  // 2) ISO : yyyy-MM-dd (avec ou sans heure / timezone)
  final isoLike = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:[ T].*)?$');
  final mIso = isoLike.firstMatch(s);
  if (mIso != null) {
    final y = mIso.group(1)!;
    final m = mIso.group(2)!;
    final d = mIso.group(3)!;
    return '$d/$m/$y';
  }

  // 3) Date JS/texte : Tue Feb 28 2023 ...
  final jsRegex = RegExp(r'\w{3}\s(\w{3})\s(\d{1,2})\s(\d{4})');
  final match = jsRegex.firstMatch(s);
  if (match != null) {
    const months = {
      'Jan': '01',
      'Feb': '02',
      'Mar': '03',
      'Apr': '04',
      'May': '05',
      'Jun': '06',
      'Jul': '07',
      'Aug': '08',
      'Sep': '09',
      'Oct': '10',
      'Nov': '11',
      'Dec': '12',
    };
    final month = months[match.group(1)];
    final day = match.group(2)!.padLeft(2, '0');
    final year = match.group(3)!;
    if (month != null) return '$day/$month/$year';
  }

  // 4) Dernier recours : tenter parse "classique"
  final dt = DateTime.tryParse(s);
  if (dt != null) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }

  // Si vraiment impossible
  return s;
}

/// Parse une chaîne de date (FR, ISO, JS) et retourne DateTime ou null.
DateTime? parseToDateTime(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;

  // 1) FR : d/M/yyyy ou dd/MM/yyyy
  final fr = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})');
  final mFr = fr.firstMatch(s);
  if (mFr != null) {
    final d = int.tryParse(mFr.group(1)!);
    final m = int.tryParse(mFr.group(2)!);
    final y = int.tryParse(mFr.group(3)!);
    if (d != null && m != null && y != null) return DateTime(y, m, d);
  }

  // 2) ISO : yyyy-MM-dd
  final iso = DateTime.tryParse(s);
  if (iso != null) return iso;

  // 3) JS : Tue Feb 28 2023
  final jsRegex = RegExp(r'\w{3}\s(\w{3})\s(\d{1,2})\s(\d{4})');
  final match = jsRegex.firstMatch(s);
  if (match != null) {
    const months = {'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,};
    final month = months[match.group(1)!];
    final day = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (month != null && day != null && year != null) return DateTime(year, month, day);
  }
  return null;
}

/// Retourne true si la date est dans les [months] derniers mois.
bool isDateWithinMonths(String? raw, int months) {
  if (raw == null || raw.isEmpty) return false;
  final dt = parseToDateTime(raw);
  if (dt == null) return false;
  final now = DateTime.now();
  final limit = DateTime(now.year, now.month - months, now.day);
  return !dt.isBefore(limit);
}
