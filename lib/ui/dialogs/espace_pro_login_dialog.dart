import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:offibox/data/espace_pro_credentials.dart';

/// Résultat retourné quand l'utilisateur clique "Se connecter" (pour connexion automatique en WebView).
typedef EspaceProConnectResult = ({String url, String username, String password});

/// Fenêtre de connexion Espace pro : laboratoire + logo, identifiant (ou email), mot de passe,
/// afficher/masquer mot de passe, "Se souvenir de moi", bouton Se connecter.
/// Permet de se connecter aux espaces pro avec identifiant et mot de passe (comme DigiPharmacie pour les factures).
class EspaceProLoginDialog extends StatefulWidget {
  const EspaceProLoginDialog({
    super.key,
    required this.url,
    required this.labName,
    this.iconPath,
    this.initialEmail,
    this.initialPassword,
  });

  final String url;
  final String labName;
  final String? iconPath;
  final String? initialEmail;
  final String? initialPassword;

  @override
  State<EspaceProLoginDialog> createState() => _EspaceProLoginDialogState();
}

class _EspaceProLoginDialogState extends State<EspaceProLoginDialog> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _obscurePassword = true;
  bool _rememberMe = true;

  static const Color _purple = Color(0xFF6B21A8);
  static const Color _yellow = Color(0xFFFACC15);

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    _passwordController = TextEditingController(text: widget.initialPassword ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saisissez votre identifiant ou adresse mail'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_rememberMe) {
      await EspaceProCredentials.save(widget.url, email, password);
    }
    if (!mounted) return;
    Navigator.of(context).pop<EspaceProConnectResult>(
      (url: widget.url, username: email, password: password),
    );
  }

  Widget _buildLabLogo(double size) {
    final raw = widget.iconPath?.trim();
    if (raw == null || raw.isEmpty) {
      return Icon(Icons.business_rounded, size: size, color: _purple);
    }
    final path = raw.replaceAll(r'\', '/');
    final lower = path.toLowerCase();
    if (lower.endsWith('.svg')) {
      return SvgPicture.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }
    return Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(Icons.business_rounded, size: size, color: _purple),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête : icône + Connexion souligné jaune
              const Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 28, color: Colors.black87),
                  SizedBox(width: 10),
                  Text(
                    'Connexion',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontFamily: 'Spinnaker',
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  width: 120,
                  height: 3,
                  decoration: BoxDecoration(
                    color: _yellow,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Laboratoire + logo
              Row(
                children: [
                  _buildLabLogo(40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.labName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B21A8),
                        fontFamily: 'Spinnaker',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Identifiant (email ou identifiant labo)
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Identifiant',
                  hintText: 'Adresse mail ou identifiant',
                  hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  prefixIcon: Icon(Icons.person_outline_rounded, color: Colors.grey.shade600, size: 22),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              // Mot de passe + afficher/masquer
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Mot de passe',
                  hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  prefixIcon: Icon(Icons.lock_outline_rounded, color: Colors.grey.shade600, size: 22),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.grey.shade600,
                      size: 22,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _connect(),
              ),
              const SizedBox(height: 16),
              // Se souvenir de moi + Se connecter
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (v) => setState(() => _rememberMe = v ?? true),
                    activeColor: _purple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                    child: Text(
                      'Se souvenir de moi',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _connect,
                    style: FilledButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Se connecter', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Annuler', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Connexion automatique lors de la prochaine connexion',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
