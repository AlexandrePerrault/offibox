import 'dart:convert';

import 'package:flutter/services.dart';

/// Ligne du CSV embarqué [assets/data/weleda_w_cip13.csv] (généré par
/// scripts/build_weleda_w_cip_from_bdpm.py).
class WeledaWcipRow {
  const WeledaWcipRow({required this.cip13, this.cis});

  final String cip13;
  final String? cis;
}

/// Carte Wxxx → CIP13 / CIS depuis le fichier asset (source BDPM.txt).
class WeledaWcipAsset {
  WeledaWcipAsset._();
  static final WeledaWcipAsset instance = WeledaWcipAsset._();

  Map<String, WeledaWcipRow>? _map;

  Future<Map<String, WeledaWcipRow>> loadMap() async {
    if (_map != null) return _map!;
    final out = <String, WeledaWcipRow>{};
    try {
      final s =
          await rootBundle.loadString('assets/data/weleda_w_cip13.csv');
      for (final line in const LineSplitter().convert(s)) {
        final t = line.trim();
        if (t.isEmpty || t.startsWith('#')) continue;
        final parts =
            t.split(';').map((x) => x.replaceAll('"', '').trim()).toList();
        if (parts.length < 2) continue;
        final key = parts[0].toUpperCase().trim();
        if (key == 'FORMULE_W' ||
            key == 'FORMULE W' ||
            key == 'FORMULEW') {
          continue;
        }
        if (!RegExp(r'^W\d+$').hasMatch(key)) continue;
        final cip = parts[1].replaceAll(RegExp(r'\D'), '');
        if (cip.length != 13 || !cip.startsWith('34009')) continue;
        final cisRaw =
            parts.length > 2 ? parts[2].replaceAll(RegExp(r'\D'), '').trim() : '';
        final cis = cisRaw.isEmpty ? null : cisRaw;
        out[key] = WeledaWcipRow(cip13: cip, cis: cis);
      }
    } catch (_) {}
    _map = out;
    return out;
  }
}
