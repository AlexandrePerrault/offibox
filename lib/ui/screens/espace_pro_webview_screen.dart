import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:offibox/utils/open_url.dart';
import 'package:webview_windows/webview_windows.dart';

/// Écran WebView pour se connecter automatiquement à un Espace pro avec identifiants.
/// (Windows uniquement ; utilise WebView2.)
class EspaceProWebViewScreen extends StatefulWidget {
  const EspaceProWebViewScreen({
    super.key,
    required this.url,
    required this.username,
    required this.password,
    this.labName,
  });

  final String url;
  final String username;
  final String password;
  final String? labName;

  @override
  State<EspaceProWebViewScreen> createState() => _EspaceProWebViewScreenState();
}

class _EspaceProWebViewScreenState extends State<EspaceProWebViewScreen> {
  final WebviewController _controller = WebviewController();
  StreamSubscription<LoadingState>? _loadingSubscription;
  int _autoFillAttempts = 0;
  static const int _maxAutoFillAttempts = 2;
  bool _initError = false;
  String? _initErrorMessage;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _controller.initialize();
      await _controller.setBackgroundColor(Colors.white);
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      _loadingSubscription = _controller.loadingState.listen(_onLoadingState);
      await _controller.loadUrl(widget.url);
      if (!mounted) return;
      setState(() {});
    } on MissingPluginException catch (_) {
      // WebView Windows non disponible → connexion directe dans le navigateur par défaut
      if (!mounted) return;
      setState(() {
        _initError = true;
        _initErrorMessage =
            'WebView indisponible. Ouverture du site dans votre navigateur…';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await openUrl(widget.url);
        if (mounted) Navigator.of(context).pop();
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _initError = true;
        _initErrorMessage = e.message ?? e.code;
      });
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _initError = true;
        _initErrorMessage = e.toString();
      });
      debugPrintStack(stackTrace: st);
    }
  }

  void _onLoadingState(LoadingState state) {
    if (state != LoadingState.navigationCompleted) return;
    if (_autoFillAttempts >= _maxAutoFillAttempts) return;
    _runAutoFillWithDelay();
  }

  /// Délai pour laisser le formulaire (SPA/JS ou redirection) s'afficher avant de remplir.
  Future<void> _runAutoFillWithDelay() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted || _autoFillAttempts >= _maxAutoFillAttempts) return;
    _autoFillAttempts++;
    await _runAutoFill();
  }

  /// Tente de remplir et soumettre le formulaire de connexion (sélecteurs courants).
  Future<void> _runAutoFill() async {
    final u = jsonEncode(widget.username);
    final p = jsonEncode(widget.password);
    // Sélecteurs élargis (email, username, login, id) + déclenchement input/change pour frameworks JS
    final script = '''
      (function() {
        var u = $u;
        var p = $p;
        var userInput = document.querySelector('input[type="email"]') ||
            document.querySelector('input[name="email"]') ||
            document.querySelector('input[id="email"]') ||
            document.querySelector('input[name="username"]') ||
            document.querySelector('input[name="j_id0:j_id1:username"]') ||
            document.querySelector('input[id*="username"]') ||
            document.querySelector('input[id*="login"]') ||
            document.querySelector('input[id*="email"]') ||
            document.querySelector('input[type="text"]');
        var pwInput = document.querySelector('input[type="password"]') ||
            document.querySelector('input[name="password"]') ||
            document.querySelector('input[id*="password"]');
        function setValueAndNotify(input, value) {
          if (!input) return;
          input.focus();
          input.value = value;
          input.dispatchEvent(new Event('input', { bubbles: true }));
          input.dispatchEvent(new Event('change', { bubbles: true }));
          if (input.setAttribute) input.setAttribute('value', value);
          input.blur();
        }
        setValueAndNotify(userInput, u);
        setValueAndNotify(pwInput, p);
        if (userInput && pwInput) {
          var form = userInput.closest('form') || pwInput.closest('form');
          if (form) {
            if (typeof form.requestSubmit === 'function') {
              try { form.requestSubmit(); } catch (e) {
                var submit = form.querySelector('button[type="submit"]') || form.querySelector('input[type="submit"]') || form.querySelector('button');
                if (submit) submit.click();
              }
            } else {
              var submit = form.querySelector('button[type="submit"]') || form.querySelector('input[type="submit"]') || form.querySelector('button');
              if (submit) submit.click();
            }
          }
        }
      })();
    ''';
    try {
      await _controller.executeScript(script);
    } catch (_) {
      // Ignore (page peut avoir une structure différente)
    }
  }

  @override
  void dispose() {
    _loadingSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initError) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.labName ?? 'Espace pro')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  _initErrorMessage ?? 'WebView indisponible',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await openUrl(widget.url);
                      },
                      icon: const Icon(Icons.open_in_browser, size: 20),
                      label: const Text('Ouvrir dans le navigateur'),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Fermer'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Connexion directe au site dans Chrome (ou votre navigateur par défaut).',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!_controller.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.labName ?? 'Espace pro')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.labName ?? 'Espace pro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Ouvrir dans le navigateur',
            onPressed: () async {
              Navigator.of(context).pop();
              await openUrl(widget.url);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Webview(
            _controller,
            permissionRequested: (String url, WebviewPermissionKind kind, bool isUserInitiated) async {
              return WebviewPermissionDecision.allow;
            },
          ),
          StreamBuilder<LoadingState>(
            stream: _controller.loadingState,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data == LoadingState.loading) {
                return const LinearProgressIndicator();
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
