import 'dart:io' show Platform;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:offibox/auth/google_sign_in_helper.dart';
import 'package:offibox/config/app_config.dart';
import 'package:offibox/constants/app_update_config.dart';
import 'package:offibox/constants/ui_constants.dart';
import 'package:offibox/ui/widgets/offibox_logo_complete.dart';
import 'package:offibox/services/cerp_client_service.dart';
import 'package:offibox/services/firestore_user_cache.dart';

/// Étape du flux de connexion / première connexion.
enum _LoginStep {
  mainLogin,
  firstConnectionEmail,
  firstConnectionPassword,
  firstConnectionSuccess,
}

/// Page de connexion : Gmail ou e-mail ; badge « Première connexion » pour l'inscription (email → lien → mot de passe → confirmation → téléchargement).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController firstConnectionEmailController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController pharmacyNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController faxController = TextEditingController();
  final TextEditingController cerpClientCodeController = TextEditingController();

  bool loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _rememberMe = true;
  bool _isCerpBaClient = false;

  _LoginStep _step = _LoginStep.mainLogin;
  String _firstConnectionEmail = '';

  /// Page de téléchargement affichée aux clients (offibox.fr/download, pas GitHub).
  static String get _downloadPageUrl => AppUpdateConfig.publicDownloadPageUrl;
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
    if (_isCerpBaClient && cerpClientCodeController.text.trim().isEmpty) {
      _showError('Veuillez saisir votre code client CERP BA.');
      return;
    }

    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _saveRememberedCredentials();
      if (_isCerpBaClient) {
        await CerpClientService.upsertForCurrentUser(
          isCerpBaClient: true,
          cerpBaClientCode: cerpClientCodeController.text.trim(),
        );
      }
    } catch (e) {
      _showError(_authErrorMessage(e.toString()));
    }
    if (mounted) setState(() => loading = false);
  }

  static String _randomPassword({int length = 12}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = Random.secure();
    return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// Première connexion – étape 1 : envoi du lien par email (création compte + reset pour définir le mot de passe).
  Future<void> _sendFirstConnectionEmail() async {
    final email = firstConnectionEmailController.text.trim();
    _firstConnectionEmail = email;
    if (email.isEmpty) {
      _showError('Veuillez saisir votre adresse e-mail.');
      return;
    }
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    if (firstName.isEmpty || lastName.isEmpty) {
      _showError('Veuillez saisir votre nom et votre prénom.');
      return;
    }

    setState(() => loading = true);
    try {
      final tempPassword = _randomPassword();
      final creds = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: tempPassword,
      );
      final user = creds.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {
            'email': email,
            'firstName': firstName,
            'lastName': lastName,
            'pharmacyName': pharmacyNameController.text.trim(),
            'phone': phoneController.text.trim(),
            'fax': faxController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
            'subscriptionStartedAt': FieldValue.serverTimestamp(),
            'trialEndsAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 15))),
            'plan': 'trial',
            'maxDevices': 5,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        FirestoreUserCache.instance.invalidate(user.uid);
      }
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        _showSuccess(
          'Un email vous a été envoyé. Cliquez sur le lien pour définir votre mot de passe, puis revenez ici.',
        );
        setState(() => _step = _LoginStep.firstConnectionPassword);
      }
    } catch (e) {
      if (e.toString().contains('email-already-in-use')) {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        if (mounted) {
          _showSuccess(
            'Un lien de réinitialisation a été envoyé à $email. Cliquez sur le lien pour définir votre mot de passe, puis revenez ici.',
          );
          setState(() => _step = _LoginStep.firstConnectionPassword);
        }
      } else {
        _showError(_authErrorMessage(e.toString()));
      }
    }
    if (mounted) setState(() => loading = false);
  }

  /// Première connexion – étape 2 : connexion avec le mot de passe défini via le lien, puis confirmation et redirection.
  Future<void> _confirmFirstConnectionAndRedirect() async {
    final email = _firstConnectionEmail.trim();
    final password = passwordController.text;
    final confirm = confirmPasswordController.text;
    if (password.isEmpty) {
      _showError('Veuillez saisir votre mot de passe.');
      return;
    }
    if (_isCerpBaClient && cerpClientCodeController.text.trim().isEmpty) {
      _showError('Veuillez saisir votre code client CERP BA.');
      return;
    }
    if (password != confirm) {
      _showError('Les deux mots de passe ne correspondent pas.');
      return;
    }

    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _saveRememberedCredentials();
      if (_isCerpBaClient) {
        await CerpClientService.upsertForCurrentUser(
          isCerpBaClient: true,
          cerpBaClientCode: cerpClientCodeController.text.trim(),
        );
      }
      if (mounted) {
        setState(() {
          _step = _LoginStep.firstConnectionSuccess;
          loading = false;
        });
        _openDownloadPageAfterDelay();
      }
    } catch (e) {
      _showError(_authErrorMessage(e.toString()));
      if (mounted) setState(() => loading = false);
    }
  }

  void _openDownloadPageAfterDelay() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    await _openDownloadPage();
  }

  Future<void> _openDownloadPage() async {
    final uri = Uri.parse(_downloadPageUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> signInWithGoogle() async {
    if (!OffiboxGoogleSignIn.isAvailable) {
      _showError(
        'Connexion Google non disponible sur Windows. Utilisez la connexion par e-mail.',
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
      if (_isCerpBaClient) {
        await CerpClientService.upsertForCurrentUser(
          isCerpBaClient: true,
          cerpBaClientCode: cerpClientCodeController.text.trim(),
        );
      }
    } catch (e) {
      _showError(_authErrorMessage(e.toString()));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _openForgotPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      _showError('Veuillez saisir votre adresse e-mail pour recevoir le lien de réinitialisation.');
      return;
    }

    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        _showSuccess(
          'Un lien de réinitialisation a été envoyé à $email. Cliquez sur le lien dans l\'email pour réinitialiser votre mot de passe.',
        );
      }
    } catch (e) {
      _showError(_authErrorMessage(e.toString()));
    }
    if (mounted) setState(() => loading = false);
  }

  String _authErrorMessage(String raw) {
    if (raw.contains('missing-email') ||
        raw.contains('An email address must be provided')) {
      return 'Veuillez saisir votre adresse e-mail.';
    }
    if (raw.contains('invalid-email')) return 'Adresse e-mail invalide.';
    if (raw.contains('user-not-found') || raw.contains('wrong-password')) {
      return 'E-mail ou mot de passe incorrect.';
    }
    if (raw.contains('email-already-in-use')) {
      return 'Un compte existe déjà avec cet e-mail.';
    }
    if (raw.contains('weak-password')) return 'Le mot de passe est trop faible.';
    if (raw.contains('network-request-failed')) {
      return 'Erreur réseau. Vérifiez votre connexion.';
    }
    if (raw.contains('MissingPluginException')) {
      return 'Connexion Google non disponible sur cette plateforme. Utilisez la connexion par e-mail.';
    }
    return raw;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    firstConnectionEmailController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    pharmacyNameController.dispose();
    phoneController.dispose();
    faxController.dispose();
    cerpClientCodeController.dispose();
    super.dispose();
  }

  InputDecoration _buildInputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
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
    );
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
                child: _step == _LoginStep.mainLogin
                    ? _buildMainLogin()
                    : _step == _LoginStep.firstConnectionEmail
                        ? _buildFirstConnectionEmail()
                        : _step == _LoginStep.firstConnectionPassword
                            ? _buildFirstConnectionPassword()
                            : _buildFirstConnectionSuccess(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainLogin() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: OffiboxLogoComplete(height: 56)),
        const SizedBox(height: 24),
        const Text(
          'Connectez-vous ou créez votre compte',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF3F4346),
            fontFamily: 'Spinnaker',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Connexion avec Gmail ou par e-mail',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontFamily: 'Spinnaker',
          ),
        ),
        const SizedBox(height: 24),

        // Connexion Gmail
        if (OffiboxGoogleSignIn.isAvailable) ...[
          OutlinedButton.icon(
            onPressed: loading ? null : signInWithGoogle,
            icon: SvgPicture.asset(
              'assets/icons/google_logo.svg',
              width: 22,
              height: 22,
              fit: BoxFit.contain,
            ),
            label: const Text(
              'Continuer avec Gmail',
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
          const SizedBox(height: 20),
        ],

        // Connexion par e-mail
        Text(
          'Ou par e-mail',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontFamily: 'Spinnaker',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: _buildInputDecoration('Email', hint: 'exemple@pharmacie.fr'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Mot de passe',
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
              borderSide:
                  const BorderSide(color: OffiboxColors.primary, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 22,
                color: Colors.grey.shade600,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (AppConfig.cerpFeaturesEnabled) ...[
          Row(
            children: [
              Checkbox(
                value: _isCerpBaClient,
                onChanged: loading ? null : (v) {
                  setState(() {
                    _isCerpBaClient = v ?? false;
                    if (!_isCerpBaClient) {
                      cerpClientCodeController.clear();
                    }
                  });
                },
                activeColor: OffiboxColors.primary,
              ),
              Flexible(
                child: GestureDetector(
                  onTap: loading ? null : () {
                    setState(() {
                      _isCerpBaClient = !_isCerpBaClient;
                      if (!_isCerpBaClient) {
                        cerpClientCodeController.clear();
                      }
                    });
                  },
                  child: Text(
                    'Je suis client CERP BA',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontFamily: 'Spinnaker',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          if (_isCerpBaClient) ...[
            const SizedBox(height: 8),
            TextField(
              controller: cerpClientCodeController,
              autocorrect: false,
              decoration: _buildInputDecoration('Code client', hint: 'ex: 12345'),
            ),
          ],
          const SizedBox(height: 8),
        ],

        const SizedBox(height: 8),
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
                onTap:
                    loading ? null : () => setState(() => _rememberMe = !_rememberMe),
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
            TextButton(
              onPressed: loading ? null : _openForgotPassword,
              style: TextButton.styleFrom(
                foregroundColor: OffiboxColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Mot de passe oublié ?'),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
            'Suivant',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Spinnaker',
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Badge Première connexion (style "Pas encore de compte")
        Material(
          color: OffiboxColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: loading
                ? null
                : () {
                    setState(() {
                      _step = _LoginStep.firstConnectionEmail;
                      _firstConnectionEmail = emailController.text.trim();
                      firstConnectionEmailController.text = _firstConnectionEmail;
                    });
                  },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Pas encore de compte ?',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                            fontFamily: 'Spinnaker',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Première connexion : recevez un lien par e-mail pour créer votre mot de passe.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontFamily: 'Spinnaker',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: OffiboxColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFirstConnectionEmail() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: loading
                  ? null
                  : () => setState(() => _step = _LoginStep.mainLogin),
              icon: const Icon(Icons.arrow_back),
              color: OffiboxColors.darkGray,
            ),
            const Text(
              'Première connexion',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'Spinnaker',
                color: Color(0xFF3F4346),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Saisissez votre e-mail. Nous vous enverrons un lien pour définir votre mot de passe.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            fontFamily: 'Spinnaker',
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: lastNameController,
          autocorrect: false,
          decoration: _buildInputDecoration('Nom', hint: 'Votre nom'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: firstNameController,
          autocorrect: false,
          decoration: _buildInputDecoration('Prénom', hint: 'Votre prénom'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: pharmacyNameController,
          autocorrect: false,
          decoration: _buildInputDecoration('Nom de la pharmacie (optionnel)', hint: 'Nom de votre pharmacie'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          autocorrect: false,
          decoration: _buildInputDecoration('Numéro de téléphone (optionnel)', hint: '06…'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: faxController,
          keyboardType: TextInputType.phone,
          autocorrect: false,
          decoration: _buildInputDecoration('Fax (optionnel)', hint: '02…'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: firstConnectionEmailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: _buildInputDecoration('Email', hint: 'exemple@pharmacie.fr'),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: loading ? null : _sendFirstConnectionEmail,
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
            'Envoyer le lien',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Spinnaker',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFirstConnectionPassword() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: loading ? null : () => setState(() => _step = _LoginStep.firstConnectionEmail),
              icon: const Icon(Icons.arrow_back),
              color: OffiboxColors.darkGray,
            ),
            const Text(
              'Définir votre mot de passe',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'Spinnaker',
                color: Color(0xFF3F4346),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Après avoir cliqué sur le lien reçu par e-mail, saisissez ici le mot de passe que vous avez choisi.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            fontFamily: 'Spinnaker',
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Mot de passe',
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
              borderSide:
                  const BorderSide(color: OffiboxColors.primary, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 22,
                color: Colors.grey.shade600,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: confirmPasswordController,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            labelText: 'Confirmer le mot de passe',
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
              borderSide:
                  const BorderSide(color: OffiboxColors.primary, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 22,
                color: Colors.grey.shade600,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ),
        const SizedBox(height: 28),
        // Bouton pill "Suivant"
        Center(
          child: Material(
            color: OffiboxColors.primary,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: loading ? null : _confirmFirstConnectionAndRedirect,
              borderRadius: BorderRadius.circular(24),
              child: const Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                child: Text(
                  'Suivant',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Spinnaker',
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFirstConnectionSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 24),
        const Icon(
          Icons.check_circle_outline,
          size: 64,
          color: OffiboxColors.primary,
        ),
        const SizedBox(height: 24),
        const Text(
          'Inscription confirmée !',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            fontFamily: 'Spinnaker',
            color: Color(0xFF3F4346),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Vous allez être redirigé vers la page de téléchargement.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade700,
            fontFamily: 'Spinnaker',
          ),
        ),
        const SizedBox(height: 32),
        OutlinedButton.icon(
          onPressed: _openDownloadPage,
          icon: const Icon(Icons.download, size: 20),
          label: Text(
            Platform.isWindows
                ? 'Télécharger — Windows ${_windowsVersionLabel()}'
                : 'Ouvrir la page de téléchargement',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFamily: 'Spinnaker',
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: OffiboxColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            side: const BorderSide(color: OffiboxColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ],
    );
  }

  String _windowsVersionLabel() {
    try {
      final v = Platform.operatingSystemVersion;
      if (v.contains('10.0')) return '10';
      if (v.contains('11') || v.contains('10.0.22')) return '11';
      return 'Windows';
    } catch (_) {
      return 'Windows';
    }
  }
}



