import 'package:flutter/material.dart';

class SearchHelpButtons extends StatelessWidget {
  const SearchHelpButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Scanner un code ou taper un nom',
      style: TextStyle(color: Colors.grey),
    );
  }
}
