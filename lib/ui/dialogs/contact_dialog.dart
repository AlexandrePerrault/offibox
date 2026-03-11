import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:offibox/constants/ui_constants.dart';
import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/utils/open_url.dart';

/// Email affiché et destinataire des mails du formulaire contact.
const String kContactEmailDisplay = 'contact@offibox.fr';
/// Destinataire du mailto (identique à l’affiché pour cohérence).
const String kContactMailtoRecipient = 'contact@offibox.fr';

/// Dialogue de contact : en-tête (téléphone, mail, adresse Offibox) + formulaire.
/// Peut être affiché en [Dialog] centré ou en panneau sous la barre via [ContactDialog.asPanel].
class ContactDialog extends StatefulWidget {
  const ContactDialog({super.key, this.maxWidth, this.onClose});

  /// Affiche le formulaire dans un panneau (sous la barre, largeur = [maxWidth], avec [onClose]).
  ContactDialog.asPanel({
    super.key,
    required this.maxWidth,
    required this.onClose,
  });

  final double? maxWidth;
  final VoidCallback? onClose;

  @override
  State<ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<ContactDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _mailController = TextEditingController();
  final _nomPharmacieController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _mailController.dispose();
    _nomPharmacieController.dispose();
    _telephoneController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, String hint) {
    final radius = BorderRadius.circular(OffiboxWindowUI.borderRadius);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: radius),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: OffiboxColors.primary.withValues(alpha: 0.85), width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Future<void> _sendMessage() async {
    if (_sending) return;
    final nom = _nomController.text.trim();
    final prenom = _prenomController.text.trim();
    final mail = _mailController.text.trim();
    final nomPharmacie = _nomPharmacieController.text.trim();
    final telephone = _telephoneController.text.trim();
    final subject = _subjectController.text.trim();
    final message = _bodyController.text.trim();

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir un message.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('sendContactEmail');
      final res = await callable.call<Map<String, dynamic>>({
        'nom': nom,
        'prenom': prenom,
        'email': mail,
        'pharmacie': nomPharmacie,
        'telephone': telephone,
        'subject': subject,
        'message': message,
      });
      final data = res.data;
      final ok = data['success'] == true;
      if (!ok) {
        final err = data['error']?.toString();
        throw Exception(err ?? 'Envoi impossible');
      }
      if (!mounted) return;
      if (widget.onClose != null) {
        widget.onClose!();
      } else {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message envoyé à Offibox.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Envoi impossible : $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _buildContent(double maxWidth) {
    final isPanel = widget.onClose != null;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isPanel ? 16 : 24, vertical: isPanel ? 14 : 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Formulaire de contact',
                      style: TextStyle(
                        fontSize: isPanel ? 16 : 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Spinnaker',
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (isPanel)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                      tooltip: 'Fermer',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                ],
              ),
              const SizedBox(height: 12),
                // Téléphone, mail, adresse (gris + Offibox)
                const _ContactLine(
                  icon: Icons.phone_outlined,
                  label: 'Téléphone',
                  value: '—',
                  onTap: null,
                ),
                const SizedBox(height: 6),
                _ContactLine(
                  icon: Icons.email_outlined,
                  label: 'Mail',
                  value: kContactEmailDisplay,
                  onTap: () => openUrl('mailto:$kContactMailtoRecipient'),
                  linkStyle: true,
                ),
                const SizedBox(height: 6),
                _ContactLine(
                  icon: Icons.location_on_outlined,
                  label: 'Adresse',
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Spinnaker',
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(
                          text: 'Offi',
                          style: TextStyle(color: OffiboxColors.primary, fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: 'box',
                          style: TextStyle(color: OffiboxColors.darkGray, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                const Text(
                  'Envoyer un message',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Spinnaker',
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nomController,
                        decoration: _dec('Nom', 'Votre nom'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _prenomController,
                        decoration: _dec('Prénom', 'Votre prénom'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _mailController,
                        decoration: _dec('Mail', 'votre@email.fr'),
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nomPharmacieController,
                        decoration: _dec('Nom de la pharmacie (optionnel)', 'Nom de votre pharmacie'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _telephoneController,
                        decoration: _dec('Téléphone (optionnel)', 'Numéro de téléphone'),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _subjectController,
                        decoration: _dec('Objet', 'Objet du message'),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _bodyController,
                        decoration: _dec('Message', 'Votre message…').copyWith(alignLabelWithHint: true),
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Annuler'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _sending ? null : _sendMessage,
                            style: FilledButton.styleFrom(
                              backgroundColor: OffiboxColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: _sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Envoyer'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],  // children of Column
            ),
          ),
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = widget.maxWidth ?? 360;
    if (widget.onClose != null) {
      return Material(
        elevation: 8,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        child: _buildContent(maxWidth),
      );
    }
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),
      ),
      child: _buildContent(maxWidth),
    );
  }
}

class _ContactLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? child;
  final VoidCallback? onTap;
  final bool linkStyle;

  const _ContactLine({
    required this.icon,
    required this.label,
    this.value,
    this.child,
    this.onTap,
    this.linkStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = child ??
        (value != null
            ? Text(
                value!,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Spinnaker',
                  color: linkStyle ? OffiboxColors.primary : Colors.grey.shade800,
                  fontWeight: FontWeight.w500,
                  decoration: linkStyle ? TextDecoration.underline : null,
                  decorationColor: linkStyle ? OffiboxColors.primary : null,
                ),
              )
            : const SizedBox.shrink());
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: OffiboxColors.darkGray),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$label :',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Spinnaker',
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              content,
            ],
          ),
        ),
      ],
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: row,
        ),
      );
    }
    return row;
  }
}
