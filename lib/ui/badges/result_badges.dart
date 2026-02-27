import 'package:flutter/material.dart';
import 'package:offibox/models/search_result.dart';

Widget? genericBadgeWidget(SearchResult item) {
  if (item.isGeneric != true || item.princepsName == null) return null;
  return Chip(label: Text('PRINCEPS : ${item.princepsName}'));
}

Widget? princepsBadgeWidget(SearchResult item) {
  if (item.isGeneric == true || item.genericName == null) return null;
  return Chip(label: Text('GÉNÉRIQUE : ${item.genericName}'));
}
