import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:offibox/constants/ui_constants.dart';
import 'package:offibox/utils/open_url.dart';

/// État du panier catalogue (code 7 chiffres -> nombre de boîtes).
class CatalogueCartNotifier extends ChangeNotifier {
  CatalogueCartNotifier({Map<String, double>? unitPriceByCode7})
      : _unitPriceByCode7 = unitPriceByCode7 ?? const {};

  final Map<String, int> _items = {};
  Map<String, double> _unitPriceByCode7;

  Map<String, int> get items => Map.unmodifiable(_items);

  int get totalItems => _items.values.fold(0, (a, b) => a + b);

  void setUnitPrices(Map<String, double> unitPriceByCode7) {
    _unitPriceByCode7 = unitPriceByCode7;
    notifyListeners();
  }

  double? unitPriceFor(String code7) {
    final code = code7.replaceAll(RegExp(r'\D'), '');
    return _unitPriceByCode7[code];
  }

  bool get hasUnknownPrices {
    if (_items.isEmpty) return false;
    for (final code in _items.keys) {
      if (_unitPriceByCode7[code] == null) return true;
    }
    return false;
  }

  double get totalAmountEur {
    double total = 0;
    for (final e in _items.entries) {
      final price = _unitPriceByCode7[e.key];
      if (price == null) continue;
      total += price * e.value;
    }
    return total;
  }

  void add(String code7, {int quantity = 1}) {
    if (code7.trim().isEmpty) return;
    final code = code7.replaceAll(RegExp(r'\D'), '');
    if (code.length != 7) return;
    _items[code] = (_items[code] ?? 0) + quantity;
    notifyListeners();
  }

  void setQuantity(String code7, int quantity) {
    final code = code7.replaceAll(RegExp(r'\D'), '');
    if (quantity <= 0) {
      _items.remove(code);
    } else {
      _items[code] = quantity;
    }
    notifyListeners();
  }

  void remove(String code7) {
    final code = code7.replaceAll(RegExp(r'\D'), '');
    _items.remove(code);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}

/// Icône panier avec badge (nombre d'articles) pour la toolbar PDF.
class CatalogueCartIcon extends StatelessWidget {
  const CatalogueCartIcon({
    super.key,
    required this.itemCount,
    this.totalAmountEur,
    required this.onTap,
  });

  final int itemCount;
  final double? totalAmountEur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amount = totalAmountEur;
    final amountLabel = amount == null ? '—' : '${amount.toStringAsFixed(2).replaceAll('.', ',')} €';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.shopping_cart_outlined, size: 22, color: Colors.white),
              Positioned(
                left: 26,
                top: 1,
                child: Text(
                  amountLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (itemCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      itemCount > 99 ? '99+' : '$itemCount',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialogue du panier : liste des codes + quantités, modifier, supprimer.
class CatalogueCartDialog extends StatelessWidget {
  const CatalogueCartDialog({
    super.key,
    required this.cart,
    required this.onClose,
    required this.francoThresholdEur,
    required this.orderRecipientEmail,
    required this.faxNumber,
  });

  final CatalogueCartNotifier cart;
  final VoidCallback onClose;
  final double francoThresholdEur;
  final String orderRecipientEmail;
  final String faxNumber;

  String _fmtEur(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} €';

  List<Map<String, dynamic>> _faxItemsPayload() {
    return cart.items.entries
        .map((e) => {
              'code7': e.key,
              'quantity': e.value,
              'unitPriceEur': cart.unitPriceFor(e.key),
            })
        .toList();
  }

  Future<void> _sendFaxViaApi(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Envoyer par fax'),
        content: Text('Envoyer la commande par fax au $faxNumber ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Non'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Oui'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Envoi du fax…'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'sendCerpEquipmentFax',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );
      final result = await callable.call<Map<String, dynamic>>(
        <String, dynamic>{
          'items': _faxItemsPayload(),
          'totalAmountEur': cart.totalAmountEur,
        },
      );
      if (!context.mounted) return;
      final data = (result.data as Map?) ?? {};
      final faxId = data['faxId'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fax envoyé (id: $faxId).'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      onClose();
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fax impossible: ${e.message ?? e.code}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fax impossible: $e'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _sendOrderEmail() async {
    final itemsLines = cart.items.entries.map((e) {
      final code = e.key;
      final qty = e.value;
      final p = cart.unitPriceFor(code);
      final lineTotal = p != null ? _fmtEur(p * qty) : '—';
      final unit = p != null ? _fmtEur(p) : '—';
      return '- $code  x$qty  (PU: $unit)  (Total: $lineTotal)';
    }).join('\n');

    final body = [
      'Bonjour,',
      '',
      'Merci de trouver ci-dessous une commande Offibox (Catalogue équipement).',
      '',
      itemsLines,
      '',
      'Total: ${_fmtEur(cart.totalAmountEur)}',
      '',
      'Option fax: $faxNumber',
    ].join('\n');

    final uri = Uri(
      scheme: 'mailto',
      path: orderRecipientEmail,
      queryParameters: {
        'subject': 'Commande catalogue équipement',
        'body': body,
      },
    );
    await openUrl(uri.toString());
  }

  Future<void> _confirmAndSend(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Envoyer la commande'),
        content: Text('Envoyer la commande par email à $orderRecipientEmail ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Non')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Oui')),
        ],
      ),
    );
    if (ok == true) {
      await _sendOrderEmail();
      if (context.mounted) onClose();
    }
  }

  void _showFaxInfo(BuildContext context) {
    final text = [
      'Fax: $faxNumber',
      '',
      'Commande (copier-coller):',
      ...cart.items.entries.map((e) => '${e.key};${e.value}'),
      '',
      'Total: ${_fmtEur(cart.totalAmountEur)}',
    ].join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bon de commande copié. Fax: $faxNumber'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = cart.totalAmountEur;
    final canOrder = cart.items.isNotEmpty &&
        !cart.hasUnknownPrices &&
        total >= francoThresholdEur;
    final orderDisabledReason = cart.items.isEmpty
        ? 'Panier vide'
        : (cart.hasUnknownPrices
            ? 'Prix indisponible (CSV prix manquant)'
            : (total < francoThresholdEur
                ? 'Franco non atteint (${_fmtEur(francoThresholdEur)})'
                : null));

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.shopping_cart, color: OffiboxColors.primary),
          const SizedBox(width: 8),
          const Text('Panier catalogue'),
          const Spacer(),
          if (cart.items.isNotEmpty)
            TextButton(
              onPressed: () {
                cart.clear();
              },
              child: const Text('Vider'),
            ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: cart.items.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Panier vide.\nSélectionnez un code à 7 chiffres dans le PDF puis ajoutez des boîtes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              )
            : ListView(
                shrinkWrap: true,
                children: cart.items.entries.map((e) {
                  final code = e.key;
                  final qty = e.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            code,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          onPressed: qty > 1
                              ? () => cart.setQuantity(code, qty - 1)
                              : () => cart.remove(code),
                        ),
                        Text('$qty', style: const TextStyle(fontWeight: FontWeight.w600)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          onPressed: () => cart.setQuantity(code, qty + 1),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          onPressed: () => cart.remove(code),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
      actions: [
        TextButton(
          onPressed: onClose,
          child: const Text('Fermer'),
        ),
        if (cart.items.isNotEmpty)
          Tooltip(
            message: canOrder ? 'Envoyer la commande' : (orderDisabledReason ?? 'Action indisponible'),
            child: FilledButton.icon(
              onPressed: canOrder ? () => _confirmAndSend(context) : null,
              icon: const Icon(Icons.send, size: 18),
              label: Text(canOrder ? 'Envoyer la commande' : 'Commander'),
            ),
          ),
        if (cart.items.isNotEmpty)
          Tooltip(
            message: canOrder ? 'Envoyer par fax' : (orderDisabledReason ?? 'Action indisponible'),
            child: OutlinedButton.icon(
              onPressed: canOrder ? () => _sendFaxViaApi(context) : null,
              icon: const Icon(Icons.print, size: 18),
              label: Text('Fax ($faxNumber)'),
            ),
          ),
        if (cart.items.isNotEmpty)
          TextButton.icon(
            onPressed: () => _showFaxInfo(context),
            icon: const Icon(Icons.copy_all, size: 18),
            label: const Text('Copier bon de commande'),
          ),
      ],
    );
  }
}
