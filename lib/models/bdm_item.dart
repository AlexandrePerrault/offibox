class BdmItem {
  final String label;
  final String cip13;
  final String url; // contiendra le CIS
  final bool nsfp;
  final String? nsfpDate;

  BdmItem({
    required this.label,
    required this.cip13,
    required this.url,
    required this.nsfp,
    this.nsfpDate,
  });
}
