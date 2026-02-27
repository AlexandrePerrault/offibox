import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:offibox/controllers/offibox_controller.dart';
import 'package:offibox/config/google_oauth_config.dart';
import 'package:offibox/data/catalogue_pdf_search.dart';
import 'package:offibox/models/search_result.dart';
import 'package:offibox/models/source_type.dart';
import 'package:offibox/services/dgs_urgent_service.dart';
import 'package:offibox/services/ansm_last_rappel_service.dart';
import 'package:offibox/services/ansm_statuts_csv_service.dart';
import 'package:offibox/services/google_calendar_service.dart';
final offiboxControllerProvider =
    ChangeNotifierProvider.autoDispose<OffiboxController>((ref) {
  final controller = OffiboxController();
  // Ne pas appeler ref.onDispose(controller.dispose) : Riverpod appelle
  // déjà dispose() sur le ChangeNotifier à la libération du provider.
  // Un double appel provoquait "used after being disposed" au hot reload.
  return controller;
});

/// Prochains événements Google Calendar (utilisateur connecté avec Google).
final calendarEventsProvider = FutureProvider.autoDispose<List<CalendarEvent>>((ref) {
  return GoogleCalendarService.getUpcomingEvents(maxResults: 5);
});

/// Dernier DGS-Urgent (sante.gouv.fr).
final dgsUrgentProvider = FutureProvider.autoDispose<DgsUrgentItem?>((ref) {
  return DgsUrgentService.fetchLast();
});

/// Dernier rappel de produit ANSM (informations-de-securite).
final ansmLastRappelProvider = FutureProvider.autoDispose<AnsmRappelItem?>((ref) {
  return AnsmLastRappelService.fetchLast();
});

/// Dernière info statut ANSM (dernière ligne du CSV offiboxdata).
final ansmLastStatutProvider = FutureProvider.autoDispose<AnsmStatutItem?>((ref) {
  return AnsmStatutsCsvService.fetchLast();
});

/// OAuth Google Calendar configuré (Windows/Desktop).
final googleOAuthConfigReadyProvider = FutureProvider.autoDispose<bool>((ref) {
  return GoogleOAuthConfig.isConfigured;
});

/// Date de fin d'essai (pour afficher la durée restante).
final trialEndsAtProvider = FutureProvider.autoDispose<DateTime?>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();

  if (!doc.exists) return null;
  final trialEndsAt = doc.data()?['trialEndsAt'] as Timestamp?;
  if (trialEndsAt == null) return null;

  final plan = doc.data()?['plan'];
  if (plan == 'pro') return null;

  return trialEndsAt.toDate();
});

/// Catalogues avec URL PDF (col. G) pour la recherche dans les PDF.
final cataloguePdfItemsProvider = Provider.autoDispose<List<SearchResult>>((ref) {
  final c = ref.watch(offiboxControllerProvider);
  return c.allResults
      .where((r) =>
          r.source == SourceType.catalogue &&
          r.catalogueUrl != null &&
          r.catalogueUrl!.trim().isNotEmpty &&
          r.catalogueUrl!.toLowerCase().endsWith('.pdf'),)
      .toList();
});

/// Résultats de la recherche dans les PDF des catalogues (query = currentQuery).
final pdfSearchHitsProvider = FutureProvider.autoDispose<List<SearchResult>>((ref) async {
  final c = ref.watch(offiboxControllerProvider);
  final query = c.currentQuery.trim();
  if (query.length < 2) return [];
  final items = ref.watch(cataloguePdfItemsProvider);
  if (items.isEmpty) return [];
  return CataloguePdfSearch.searchInCatalogues(query, items);
});

/// Résultats affichés dans le panneau (recherche dans les PDF catalogues désactivée — trop lent).
final effectiveResultsProvider = Provider.autoDispose<List<SearchResult>>((ref) {
  final c = ref.watch(offiboxControllerProvider);
  return c.filteredResults;
});
