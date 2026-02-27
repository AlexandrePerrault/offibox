import 'package:flutter/material.dart';
import 'package:offibox/models/search_result.dart';

class ResultAction {
  final String label;
  final IconData icon;
  final String tooltip;

  final bool Function(SearchResult item) isVisible;
  final VoidCallback Function(SearchResult item) onTap;

  final bool isPrimary;

  const ResultAction({
    required this.label,
    required this.icon,
    required this.tooltip,
    required this.isVisible,
    required this.onTap,
    this.isPrimary = false,
  });
}
