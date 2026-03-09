import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:offibox/controllers/offibox_controller.dart';
import 'package:offibox/utils/firestore_desktop_safe.dart';
import 'package:offibox/config/google_oauth_config.dart';
import 'package:offibox/services/firestore_user_cache.dart';
import 'package:offibox/data/catalogue_pdf_search.dart';
import 'package:offibox/models/client_profile.dart';
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

/// Événements du jour (agenda Google) pour la barre d'info et la bulle de rappel.
final todayCalendarEventsProvider = FutureProvider.autoDispose<List<CalendarEvent>>((ref) {
  return GoogleCalendarService.getTodayEvents();
});

/// Dernier DGS-Urgent (sante.gouv.fr).
final dgsUrgentProvider = FutureProvider.autoDispose<DgsUrgentItem?>((ref) {
  return DgsUrgentService.fetchLast();
});

/// Dernier rappel de produit ANSM (informations-de-securite) — médicaments uniquement, pour la barre d'infos.
final ansmLastRappelProvider = FutureProvider.autoDispose<AnsmRappelItem?>((ref) {
  return AnsmLastRappelService.fetchLast();
});

/// Liste des rappels « Médicaments » (pour badge ligne 3 « rappel de produit + date » sur chaque médicament concerné).
final ansmMedicamentRappelsProvider = FutureProvider.autoDispose<List<AnsmRappelItem>>((ref) {
  return AnsmLastRappelService.fetchAllMedicamentRappels();
});

/// Dernière info statut ANSM (dernière ligne du CSV offiboxdata).
final ansmLastStatutProvider = FutureProvider.autoDispose<AnsmStatutItem?>((ref) {
  return AnsmStatutsCsvService.fetchLast();
});

/// OAuth Google Calendar configuré (Windows/Desktop).
final googleOAuthConfigReadyProvider = FutureProvider.autoDispose<bool>((ref) {
  return GoogleOAuthConfig.isConfigured;
});

/// Date de fin d'essai (pour afficher la durée restante). Lecture via cache partagé.
final trialEndsAtProvider = FutureProvider.autoDispose<DateTime?>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final data = await getUserDocCached(user.uid);
  if (data == null) return null;

  final trialEndsAt = data['trialEndsAt'] as Timestamp?;
  if (trialEndsAt == null) return null;

  final plan = data['plan'];
  if (plan == 'pro') return null;

  return trialEndsAt.toDate();
});

/// Fiche client (appVariant, groupement) depuis Firestore users/{uid}.
/// Utiliser pour adapter l'app selon Offibox classique vs Offibox-CERP.
/// Sur Windows, on évite .snapshots() (bug thread plateforme) en utilisant un stream par polling.
final clientProfileProvider = StreamProvider.autoDispose<ClientProfile?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(null);
  final docRef = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid) as DocumentReference<Map<String, dynamic>>;
  return documentSnapshotStream(docRef)
      .map((snap) => ClientProfile.fromUserDoc(user.uid, snap.data()));
});

/// True si le client a renseigné et validé son statut CERP BA (case cochée + code client).
final cerpBaValidatedProvider = Provider.autoDispose<bool>((ref) {
  final profile = ref.watch(clientProfileProvider).valueOrNull;
  return profile?.cerpBaValidated ?? false;
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

