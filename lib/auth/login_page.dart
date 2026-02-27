import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:offibox/auth/google_sign_in_helper.dart';
import 'package:offibox/constants/ui_constants.dart';
import 'package:offibox/ui/widgets/offibox_logo_complete.dart';

/// Page de connexion : première connexion avec Windows (compte Microsoft) ou e-mail.
/// Essai 15 jours. Connexion par e-mail : créer un mot de passe à l'inscription.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool loading = false;
  bool _obscurePassword = true;
  /// Par défaut true : une fois identifiants saisis à la première ouverture, l'app se lance sans redemander.
  bool _rememberMe = true;

  static const String _offiboxUrl = 'https://www.offibox.fr/';
  static const String _keyRememberEmail = 'login_remember_email';
  static const String _keyRememberPassword = 'login_remember_password';

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString(_keyRememberEmail);
    final savedPassword = prefs.getString(_keyRememberPassword);
    if (savedEmail != null && savedEmail.isNotEmpty && mounted) {
      setState(() {
        emailController.text = savedEmail;
        if (savedPassword != null && savedPassword.isNotEmpty) {
          passwordController.text = savedPassword;
        }
        _rememberMe = true;
      });
    }
  }

  Future<void> _saveRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString(_keyRememberEmail, emailController.text.trim());
      await prefs.setString(_keyRememberPassword, passwordController.text);
    } else {
      await prefs.remove(_keyRememberEmail);
      await prefs.remove(_keyRememberPassword);
    }
  }

  Future<void> signInWithEmail() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    if (email.isEmpty) {
      _showError('Veuillez saisir votre adresse e-mail.');
      return;
    }
    if (password.isEmpty) {
      _showError('Veuillez saisir votre mot de passe.');
      return;
    }

    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _saveRememberedCredentials();
    } catch (e) {
      _showError(_authErrorMessage(e.toString()));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> register() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    if (email.isEmpty) {
      _showError('Veuillez saisir votre adresse e-mail.');
      return;
    }
    if (password.isEmpty) {
      _showError('Veuillez saisir un mot de passe.');
      return;
    }

    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      _showError(_authErrorMessage(e.toString()));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> signInWithGoogle() async {
    if (!OffiboxGoogleSignIn.isAvailable) {
      _showError(
        'Connexion Google non disponible sur Windows. Utilisez e-mail/mot de passe.',
      );
      return;
    }
    setState(() => loading = true);
    try {
      final creds = await OffiboxGoogleSignIn.signIn();
      if (creds == null) {
        if (mounted) setState(() => loading = false);
        return;
      }

      await FirebaseAuth.instance.signInWithCredential(creds.firebaseCredential);
    } catch (e) {
      _showError(_authErrorMessage(e.toString()));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _openForgotPassword() async {
    final uri = Uri.parse(_offiboxUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _authErrorMessage(String raw) {
    if (raw.contains('missing-email') || raw.contains('An email address must be provided')) {
      return 'Veuillez saisir votre adresse e-mail.';
    }
    if (raw.contains('invalid-email')) return 'Adresse e-mail invalide.';
    if (raw.contains('user-not-found') || raw.contains('wrong-password')) {
      return 'E-mail ou mot de passe incorrect.';
    }
    if (raw.contains('email-already-in-use')) return 'Un compte existe déjà avec cet e-mail.';
    if (raw.contains('weak-password')) return 'Le mot de passe est trop faible.';
    if (raw.contains('network-request-failed')) return 'Erreur réseau. Vérifiez votre connexion.';
    if (raw.contains('MissingPluginException')) {
      return 'Connexion Google non disponible sur cette plateforme. Utilisez e-mail/mot de passe.';
    }
    return raw;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0F1),
      body: Center(
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 380),
              child: Container(
                margin: const EdgeInsets.all(24),
                width: 420,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo complet Offibox
                const Center(
                  child: OffiboxLogoComplete(height: 56),
                ),
                const SizedBox(height: 24),

                // Titre avec identité Offibox
                RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3F4346),
                      fontFamily: 'Spinnaker',
                    ),
                    children: [
                      TextSpan(text: 'Connectez-vous à '),
                      TextSpan(
                        text: 'Offi',
                        style: TextStyle(color: Color(0xFF5A9094)),
                      ),
                      TextSpan(
                        text: 'Box',
                        style: TextStyle(color: Color(0xFF3F4346)),
                      ),
                      TextSpan(text: ' pour continuer :'),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Choix : email ou Google (icône Google en premier)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/icons/google_logo.svg',
                      width: 22,
                      height: 22,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Connexion avec e-mail ou connexion Google',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontFamily: 'Spinnaker',
                        ),
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Adresse e-mail*
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Adresse e-mail*',
                    hintText: 'exemple@pharmacie.fr',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: OffiboxColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),

                // Mot de passe*
                TextField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe*',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: OffiboxColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 22,
                        color: Colors.grey.shade600,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Se souvenir de moi + Mot de passe oublié
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: loading
                          ? null
                          : (v) => setState(() => _rememberMe = v ?? false),
                      activeColor: OffiboxColors.primary,
                    ),
                    Flexible(
                      child: GestureDetector(
                        onTap: loading
                            ? null
                            : () => setState(() => _rememberMe = !_rememberMe),
                        child: Text(
                          'Se souvenir de moi',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            fontFamily: 'Spinnaker',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: TextButton(
                        onPressed: loading ? null : _openForgotPassword,
                        style: TextButton.styleFrom(
                          foregroundColor: OffiboxColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Mot de passe oublié ?'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Continuer
                ElevatedButton(
                  onPressed: loading ? null : signInWithEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OffiboxColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Continuer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Spinnaker',
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Vous n'avez pas de compte ? Inscription
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Première connexion ? Créez votre mot de passe : ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontFamily: 'Spinnaker',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: loading ? null : register,
                      style: TextButton.styleFrom(
                        foregroundColor: OffiboxColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Inscription'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Connexion Google
                if (OffiboxGoogleSignIn.isAvailable) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: loading ? null : signInWithGoogle,
                    icon: SvgPicture.asset(
                      'assets/icons/google_logo.svg',
                      width: 22,
                      height: 22,
                      fit: BoxFit.contain,
                    ),
                    label: const Text(
                      'Continuer avec Google',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Spinnaker',
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OffiboxColors.darkGray,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: OffiboxColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  ),
    );
  }
}
