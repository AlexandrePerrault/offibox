import 'package:flutter/material.dart';
import '../services/lpp_service.dart';
import 'package:url_launcher/url_launcher.dart';

const Color offiboxColor = Color(0xFF5A9094);

class LppSearchBar extends StatefulWidget {
  const LppSearchBar({super.key});

  @override
  State<LppSearchBar> createState() => _LppSearchBarState();
}

class _LppSearchBarState extends State<LppSearchBar> {
  Map<String, String> lppIndex = {};
  String input = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    LppService.loadIndex().then((data) {
      setState(() {
        lppIndex = data;
        loading = false;
      });
    });
  }

  void _openAmeli(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final bool isValidCode =
        RegExp(r'^\d{7}$').hasMatch(input) &&
        lppIndex.containsKey(input);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          keyboardType: TextInputType.number,
          maxLength: 7,
          decoration: const InputDecoration(
            labelText: 'Code LPP',
            counterText: '',
          ),
          onChanged: (value) {
            setState(() => input = value);
          },
        ),

        if (loading)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: CircularProgressIndicator(),
          ),

        if (!loading && isValidCode)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Text(
                  input,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _openAmeli(lppIndex[input]!),
                  icon: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Accéder à la nomenclature LPP-AMELI',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: offiboxColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
