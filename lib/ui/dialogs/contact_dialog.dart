import 'package:flutter/material.dart';
import 'package:offibox/constants/ui_constants.dart';
import 'package:offibox/utils/open_url.dart';

/// Email affiché et destinataire des mails du formulaire contact.
const String kContactEmailDisplay = 'contact@offibox.fr';
/// Destinataire du mailto (identique à l’affiché pour cohérence).
const String kContactMailtoRecipient = 'contact@offibox.fr';

/// Dialogue de contact : en-tête (téléphone, mail, adresse Offibox) + formulaire qui ouvre le client mail.
class ContactDialog extends StatefulWidget {
  const ContactDialog({super.key});

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

  void _sendMail() {
    final nom = _nomController.text.trim();
    final prenom = _prenomController.text.trim();
    final mail = _mailController.text.trim();
    final nomPharmacie = _nomPharmacieController.text.trim();
    final telephone = _telephoneController.text.trim();
    final subject = _subjectController.text.trim();
    final message = _bodyController.text.trim();
    final bodyParts = <String>[];
    if (nom.isNotEmpty) bodyParts.add('Nom : $nom');
    if (prenom.isNotEmpty) bodyParts.add('Prénom : $prenom');
    if (mail.isNotEmpty) bodyParts.add('Mail : $mail');
    if (nomPharmacie.isNotEmpty) bodyParts.add('Nom de la pharmacie : $nomPharmacie');
    if (telephone.isNotEmpty) bodyParts.add('Téléphone : $telephone');
    if (message.isNotEmpty) bodyParts.add('\n$message');
    final body = bodyParts.join('\n');
    final uri = Uri(
      scheme: 'mailto',
      path: kContactMailtoRecipient,
      query: _encodeMailtoQuery(subject: subject.isNotEmpty ? subject : 'Message depuis Offibox', body: body),
    );
    openUrl(uri.toString());
    if (mounted) Navigator.of(context).pop();
  }

  String? _encodeMailtoQuery({String? subject, String? body}) {
    final parts = <String>[];
    if (subject != null && subject.isNotEmpty) {
      parts.add('subject=${Uri.encodeComponent(subject)}');
    }
    if (body != null && body.isNotEmpty) {
      parts.add('body=${Uri.encodeComponent(body)}');
    }
    return parts.isEmpty ? null : parts.join('&');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Contact',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Spinnaker',
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                // Téléphone, mail, adresse (gris + Offibox)
                _ContactLine(
                  icon: Icons.phone_outlined,
                  label: 'Téléphone',
                  value: '—',
                  onTap: null,
                ),
                const SizedBox(height: 8),
                _ContactLine(
                  icon: Icons.email_outlined,
                  label: 'Mail',
                  value: kContactEmailDisplay,
                  onTap: () => openUrl('mailto:$kContactMailtoRecipient'),
                  linkStyle: true,
                ),
                const SizedBox(height: 8),
                _ContactLine(
                  icon: Icons.location_on_outlined,
                  label: 'Adresse',
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 13,
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
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),
                const Text(
                  'Envoyer un message',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Spinnaker',
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nomController,
                        decoration: const InputDecoration(
                          labelText: 'Nom',
                          hintText: 'Votre nom',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _prenomController,
                        decoration: const InputDecoration(
                          labelText: 'Prénom',
                          hintText: 'Votre prénom',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _mailController,
                        decoration: const InputDecoration(
                          labelText: 'Mail',
                          hintText: 'votre@email.fr',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nomPharmacieController,
                        decoration: const InputDecoration(
                          labelText: 'Nom de la pharmacie (optionnel)',
                          hintText: 'Nom de votre pharmacie',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _telephoneController,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone (optionnel)',
                          hintText: 'Numéro de téléphone',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Objet',
                          hintText: 'Objet du message',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _bodyController,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          hintText: 'Votre message…',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Annuler'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _sendMail,
                            style: FilledButton.styleFrom(
                              backgroundColor: OffiboxColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Envoyer'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
