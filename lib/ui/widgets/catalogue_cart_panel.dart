import 'package:flutter/material.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/constants/ui_constants.dart';

/// État du panier catalogue (code 7 chiffres -> nombre de boîtes).
class CatalogueCartNotifier extends ChangeNotifier {
  final Map<String, int> _items = {};

  Map<String, int> get items => Map.unmodifiable(_items);

  int get totalItems => _items.values.fold(0, (a, b) => a + b);

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
    required this.onTap,
  });

  final int itemCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
  });

  final CatalogueCartNotifier cart;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
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
          FilledButton.icon(
            onPressed: () {
              // TODO: commander (lien externe ou API)
              onClose();
            },
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Commander'),
          ),
      ],
    );
  }
}
