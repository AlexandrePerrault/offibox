import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:offibox/constants/app_update_config.dart';

/// Première connexion : redirige l'utilisateur vers le formulaire web
/// d'inscription Offibox (inscription.html), puis lui demande de
/// valider l'e-mail (page validation) avant de se reconnecter.
///
/// Cette page est affichée quand TrialGuard.isOnboardingDone() renvoie false,
/// quel que soit le mode de connexion (Google ou e‑mail).
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    // Ouvre automatiquement la page d'inscription au premier affichage.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openInscriptionPage();
    });
  }

  Future<void> _openInscriptionPage() async {
    final uri = Uri.parse(AppUpdateConfig.publicInscriptionPageUrl);
    setState(() => _opening = true);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible d’ouvrir la page d’inscription.'),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _signOutAndReturnToLogin() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    if (!mounted) return;
    // L'écouteur authStateProvider ramènera automatiquement vers la page de login.
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Text(
                    'Compléter votre inscription',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade100,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Vous n’avez encore jamais complété votre fiche Offibox. '
                    'Un formulaire d’inscription vient d’être ouvert dans votre navigateur.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade300,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Étapes à suivre :',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade100,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _bullet(
                    '1. Remplir le formulaire « Créer un compte – Offibox » '
                    '(coordonnées officine, e‑mail, etc.).',
                  ),
                  _bullet(
                    '2. Valider l’e‑mail reçu en cliquant sur le lien (page offibox/validation) '
                    'et choisir votre mot de passe.',
                  ),
                  _bullet(
                    '3. Relancer Offibox et vous connecter depuis l’application. '
                    'Vous n’aurez plus rien à faire ensuite.',
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _opening ? null : _openInscriptionPage,
                      child: _opening
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Ouvrir la page d’inscription',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton(
                      onPressed: _signOutAndReturnToLogin,
                      child: const Text(
                        'J’ai terminé, revenir à l’écran de connexion',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Astuce : vous pouvez fermer cette fenêtre Offibox, compléter l’inscription '
                    'et relancer ensuite l’application. Après validation, cette étape '
                    'ne sera plus affichée.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade300,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade300,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
