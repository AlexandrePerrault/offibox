/// Prochaine journée mondiale (santé / WHO) à venir. On affiche la suivante dès que la précédente est passée.
class JourneesMondiales {
  JourneesMondiales._();

  /// (mois 1-based, jour, libellé après "Journée mondiale de ")
  static const List<({int month, int day, String deLabel})> _days = [
    (month: 1, day: 30, deLabel: 'la lèpre'),
    (month: 2, day: 4, deLabel: 'le cancer'),
    (month: 2, day: 14, deLabel: "l'épilepsie"),
    (month: 3, day: 3, deLabel: "l'audition"),
    (month: 3, day: 24, deLabel: 'la tuberculose'),
    (month: 4, day: 7, deLabel: 'la santé'),
    (month: 4, day: 11, deLabel: 'Parkinson'),
    (month: 4, day: 25, deLabel: 'le paludisme'),
    (month: 5, day: 5, deLabel: "l'hygiène des mains"),
    (month: 5, day: 12, deLabel: 'la fibromyalgie'),
    (month: 5, day: 31, deLabel: 'sans tabac'),
    (month: 6, day: 14, deLabel: 'le don du sang'),
    (month: 7, day: 28, deLabel: 'les hépatites'),
    (month: 9, day: 10, deLabel: 'la prévention du suicide'),
    (month: 9, day: 21, deLabel: "Alzheimer"),
    (month: 10, day: 10, deLabel: 'la santé mentale'),
    (month: 10, day: 16, deLabel: "l'alimentation"),
    (month: 10, day: 29, deLabel: "l'AVC"),
    (month: 11, day: 14, deLabel: 'le diabète'),
    (month: 11, day: 18, deLabel: "l'usage prudent des antibiotiques"),
    (month: 12, day: 1, deLabel: 'le sida'),
  ];

  /// Retourne la prochaine journée mondiale à venir.
  /// Format : "Prochaine journée mondiale : Journée mondiale de [thème] (date)".
  static ({String label, String dateShort})? getNext(DateTime from) {
    final year = from.year;
    final today = DateTime(from.year, from.month, from.day);
    DateTime? nextDate;
    String? nextDeLabel;
    for (final d in _days) {
      var dt = DateTime(year, d.month, d.day);
      if (dt.isBefore(today)) dt = DateTime(year + 1, d.month, d.day);
      if (nextDate == null || dt.isBefore(nextDate)) {
        nextDate = dt;
        nextDeLabel = d.deLabel;
      }
    }
    if (nextDate == null || nextDeLabel == null) return null;
    final months = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];
    final dateShort = '${nextDate.day} ${months[nextDate.month - 1]}';
    return (
      label: 'Prochaine journée mondiale : Journée mondiale de $nextDeLabel ($dateShort)',
      dateShort: dateShort,
    );
  }
}
