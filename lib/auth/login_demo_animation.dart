import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:offibox/constants/offibox_window_ui.dart';
import 'package:offibox/services/news_popup_service.dart';
import 'package:offibox/ui/widgets/offibox_logo_complete.dart';
/// Couleur teal Offibox (barre, icônes).
const Color _teal = Color(0xFF5A9094);

/// Vert toggle / indicateur ON (type Apple).
const Color _trackOnGreen = Color(0xFF34C759);

/// Gris anthracite (badge date/heure barre d'infos).
const Color _infoBarAnthracite = Color(0xFF37474F);

/// Vert badge INFOS.
const Color _infosBadgeGreen = Color(0xFF4E8A72);

/// Fond sombre (copie fidèle de la capture : barre sur fond noir).
const Color _darkBg = Color(0xFF1A1A1A);

/// Orange alerte ANSM (ticker).
const Color _tickerOrange = Color(0xFFE65100);

/// Animation de démo sur la page de connexion web : copie à l’identique de la barre
/// (info bar + search bar) comme sur la capture — fond sombre, toggle vert, date, INFOS, ticker orange, barre de recherche, logo.
class LoginDemoAnimation extends StatefulWidget {
  const LoginDemoAnimation({super.key});

  @override
  State<LoginDemoAnimation> createState() => _LoginDemoAnimationState();
}

class _LoginDemoAnimationState extends State<LoginDemoAnimation> {
  Future<NewsEntry?>? _newsFuture;
  final DateTime _dateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _newsFuture = fetchLatestNews();
  }

  String get _dateTimeFormatted {
    final d = _dateTime;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _darkBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoBar(context),
          const SizedBox(height: OffiboxWindowUI.tickerBarGap),
          _buildSearchBar(context),
        ],
      ),
    );
  }

  /// Barre d’infos : toggle vert, badge date, badge INFOS, ticker orange (alerte ANSM).
  Widget _buildInfoBar(BuildContext context) {
    const barHeight = OffiboxWindowUI.tickerBarHeight;
    const badgeHeight = OffiboxWindowUI.tickerBadgeHeight;

    return Container(
      height: barHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildToggle(),
          const SizedBox(width: 6),
          Container(
            height: badgeHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            decoration: BoxDecoration(
              color: _infoBarAnthracite,
              borderRadius: BorderRadius.circular(OffiboxWindowUI.tickerBadgeBorderRadius),
            ),
            alignment: Alignment.center,
            child: Text(
              _dateTimeFormatted,
              style: GoogleFonts.spinnaker(
                fontSize: OffiboxWindowUI.tickerBadgeFontSize,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            height: badgeHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            decoration: BoxDecoration(
              color: _infosBadgeGreen,
              borderRadius: BorderRadius.circular(OffiboxWindowUI.tickerBadgeBorderRadius),
            ),
            alignment: Alignment.center,
            child: Text(
              'INFOS',
              style: GoogleFonts.spinnaker(
                fontSize: OffiboxWindowUI.tickerBadgeFontSize,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTickerContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    const trackWidth = 27.0;
    const trackHeight = 17.0;
    const knobSize = 12.0;
    return Container(
      width: trackWidth,
      height: trackHeight,
      decoration: BoxDecoration(
        color: _trackOnGreen,
        borderRadius: BorderRadius.circular(trackHeight / 2),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: knobSize,
          height: knobSize,
          margin: const EdgeInsets.only(right: 2),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Color(0x35000000), blurRadius: 3, offset: Offset(0, 1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTickerContent(BuildContext context) {
    return FutureBuilder<NewsEntry?>(
      future: _newsFuture,
      builder: (context, snapshot) {
        final text = snapshot.hasData && snapshot.data != null
            ? (snapshot.data!.title.isNotEmpty ? snapshot.data!.title : snapshot.data!.body)
            : 'nière alerte ANSM : info : ANSM: Tension d\'approvisionnement (09/03/2026) - Emend 125 mg, poudre pour suspension buvable - [aprépitant]';
        return Container(
          height: OffiboxWindowUI.tickerBadgeHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
          decoration: BoxDecoration(
            color: _tickerOrange,
            borderRadius: BorderRadius.circular(OffiboxWindowUI.tickerBadgeBorderRadius),
          ),
          alignment: Alignment.centerLeft,
          child: Marquee(
            text: text,
            style: GoogleFonts.spinnaker(
              fontSize: OffiboxWindowUI.tickerBadgeFontSize,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1,
            ),
          ),
        );
      },
    );
  }

  /// Barre de recherche : bouton filtre (teal), placeholder, « mis à jour le », icône recherche, logo Offibox.
  Widget _buildSearchBar(BuildContext context) {
    const barHeight = OffiboxWindowUI.barHeight;
    const buttonSize = OffiboxWindowUI.menuButtonSize;

    return Container(
      height: barHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(OffiboxWindowUI.borderRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildTealCircle(Icons.tune, buttonSize),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rechercher sur Offibox (CIP, DCI, labos, législation, )',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Spinnaker',
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            'mis à jour le ${_dateTime.day.toString().padLeft(2, '0')}/${_dateTime.month.toString().padLeft(2, '0')}/${_dateTime.year}',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade500,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 8),
          _buildTealCircle(Icons.search, buttonSize),
          const SizedBox(width: 6),
          SizedBox(
            width: OffiboxWindowUI.pillSize + 4,
            height: OffiboxWindowUI.pillSize + 4,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(OffiboxWindowUI.tickerBadgeBorderRadius),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: const OffiboxLogoComplete(height: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTealCircle(IconData icon, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _teal.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(icon, size: 22, color: _teal),
    );
  }
}

/// Défilement horizontal infini pour le texte du ticker.
class Marquee extends StatefulWidget {
  const Marquee({super.key, required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      final maxExtent = _controller.position.maxScrollExtent;
      if (maxExtent <= 0) return;
      _controller.jumpTo(0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.text, style: widget.style),
          const SizedBox(width: 40),
          Text(widget.text, style: widget.style),
        ],
      ),
    );
  }
}
