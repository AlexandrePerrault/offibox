import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;

import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/constants/ui_constants.dart';
import 'package:offibox/firebase_options.dart';

/// Panneau « Boîte à idées » affiché sous la barre : suggestions, zone texte (500 car.), email.
class IdeasBoxPanel extends StatefulWidget {
  const IdeasBoxPanel({
    super.key,
    required this.onClose,
    this.barWidth,
  });

  final VoidCallback onClose;
  final double? barWidth;

  @override
  State<IdeasBoxPanel> createState() => _IdeasBoxPanelState();
}

class _IdeasBoxPanelState extends State<IdeasBoxPanel> {
  static const int _maxChars = 500;

  final _messageController = TextEditingController();
  final _emailController = TextEditingController();

  bool _sending = false;
  bool _sendSuccess = false;
  String? _emailError;

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  bool _isValidEmail(String s) =>
      s.isEmpty || _emailRegex.hasMatch(s.trim());

  @override
  void dispose() {
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final message = _messageController.text.trim();
    final email = _emailController.text.trim();

    if (email.isNotEmpty && !_isValidEmail(email)) {
      setState(() => _emailError = 'Adresse email invalide (ex. : nom@exemple.fr)');
      return;
    }
    setState(() => _emailError = null);

    setState(() => _sending = true);
    try {
      // Sur Windows le callable Cloud Functions n’établit pas le canal natif → appel HTTP
      if (defaultTargetPlatform == TargetPlatform.windows) {
        final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
        final url = Uri.parse(
          'https://us-central1-$projectId.cloudfunctions.net/sendIdeasEmailHttp',
        );
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'data': {'message': message, 'email': email}}),
        );
        if (response.statusCode != 200) {
          String detail = response.body;
          try {
            final json = jsonDecode(response.body) as Map<String, dynamic>?;
            detail = json?['detail'] as String? ?? json?['error'] as String? ?? detail;
          } catch (_) {}
          throw Exception('${response.statusCode}: $detail');
        }
      } else {
        final callable = FirebaseFunctions.instance.httpsCallable('sendIdeasEmail');
        await callable.call<void>(<String, dynamic>{
          'message': message,
          'email': email,
        });
      }
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sendSuccess = true;
      });
      // Afficher « Mail envoyé » brièvement puis fermer le panneau pour revenir à la barre au repos
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) widget.onClose();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur envoi : ${e.toString()}'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.barWidth ?? MediaQuery.sizeOf(context).width * 0.5;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        constraints: const BoxConstraints(maxWidth: 480, minHeight: 280),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),
          border: Border.all(color: OffiboxColors.primary.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: OffiboxColors.primary.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/icons/logo_offibox_installer.png',
                            height: 78,
                            width: 78,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.lightbulb_outline, size: 78, color: OffiboxColors.primary),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Boîte à idées',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Spinnaker',
                              color: OffiboxColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: widget.onClose,
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
              if (_sendSuccess) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: OffiboxColors.primary, size: 32),
                      SizedBox(width: 12),
                      Text(
                        'Mail envoyé',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Spinnaker',
                          color: OffiboxColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Vous avez une suggestion, des idées ? Soumettez-les ci-dessous, nous ne manquerons pas de vous répondre !',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Spinnaker',
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _messageController,
                  maxLength: _maxChars,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Votre message...',
                    hintStyle: TextStyle(
                      fontFamily: 'Spinnaker',
                      color: Colors.grey.shade500,
                      fontSize: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: OffiboxColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                    counterStyle: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Spinnaker',
                      color: Colors.grey.shade600,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Spinnaker',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {
                    if (_emailError != null) _emailError = null;
                  }),
                  decoration: InputDecoration(
                    labelText: 'Mon email',
                    errorText: _emailError,
                    errorStyle: TextStyle(
                      fontFamily: 'Spinnaker',
                      fontSize: 12,
                      color: Colors.red.shade700,
                    ),
                    labelStyle: TextStyle(
                      fontFamily: 'Spinnaker',
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _emailError != null ? Colors.red : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _emailError != null ? Colors.red : OffiboxColors.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Spinnaker',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: 'Envoyer',
                      decoration: BoxDecoration(
                        color: OffiboxColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Spinnaker',
                        fontSize: 13,
                      ),
                      child: FilledButton.icon(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: OffiboxColors.primary),
                              )
                            : Image.asset(
                                'assets/icons/send_mail.png',
                                width: 20,
                                height: 20,
                                fit: BoxFit.contain,
                                color: OffiboxColors.primary,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.send, size: 20, color: OffiboxColors.primary),
                              ),
                        label: const Text(
                          'Envoyer',
                          style: TextStyle(
                            fontFamily: 'Spinnaker',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: OffiboxColors.primary,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: OffiboxColors.primary,
                          side: const BorderSide(color: OffiboxColors.primary, width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
