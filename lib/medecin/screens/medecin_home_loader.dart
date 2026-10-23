import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/medecin.dart';
import '../../models/rendez_vous.dart';
import '../../services/medecin_service.dart';
import '../../theme/medigo_theme.dart';
import '../../widgets/ui_kit.dart';
import 'espace_medecin.dart';

/// Écran "intermédiaire" affiché juste après la connexion d'un médecin :
/// il charge son profil et ses rendez-vous depuis Firestore (via
/// MedecinService), affiche un indicateur pendant ce temps, puis montre
/// EspaceMedecin une fois les données prêtes. C'est ici que les données
/// RÉELLES (Firestore) remplacent les données mock qu'on utilisait pour
/// tester dans main.dart.
class MedecinHomeLoader extends StatefulWidget {
  const MedecinHomeLoader({super.key});

  @override
  State<MedecinHomeLoader> createState() => _MedecinHomeLoaderState();
}

class _MedecinHomeLoaderState extends State<MedecinHomeLoader> {
  final _service = MedecinService();

  // Nullable : tant que les données ne sont pas arrivées, ces variables
  // valent null et on affiche un indicateur de chargement à la place.
  Medecin? _medecin;

  /// Rendez-vous VISIBLES du médecin : confirmés et terminés seulement
  /// (règle d'affichage du point 3). Le chargement complet reste
  /// nécessaire pour la détection des notifications.
  List<RendezVous> _rendezVousVisibles = [];
  Map<String, int> _stats = {};

  /// Ids des consultations marquées « non terminées » (statut terminé +
  /// drapeau consultationTerminee = false, cf. MedecinService) : les
  /// écrans affichent « Non terminé » en style neutre.
  Set<String> _idsNonTermines = {};
  String? _erreur;

  /// Timer qui recharge automatiquement les données toutes les 5 s.
  /// Permet au médecin de voir les nouveaux rendez-vous (confirmés
  /// par la secrétaire) sans rafraîchir manuellement.
  Timer? _timerRafraichir;

  /// Statuts précédents (id → statut), pour détecter les rendez-vous
  /// qui DEVINENT visibles : nouveaux, ou confirmés par la secrétaire
  /// depuis le dernier rechargement.
  Map<String, StatutRendezVous> _anciensStatuts = {};

  /// Bannière « Nouveau rendez-vous » de l'accueil (maquette §4.1).
  /// null = rien à afficher. Remontée jusqu'à AccueilMedecin, qui la
  /// ferme via [_fermerNotification].
  ({String titre, String sousTitre})? _notificationRdv;

  /// Appelé par l'accueil quand l'utilisateur ferme la bannière
  /// (croix) : on vide l'état pour que la pastille rouge de la cloche
  /// disparaisse aussi.
  void _fermerNotification() {
    if (mounted) setState(() => _notificationRdv = null);
  }

  @override
  void initState() {
    super.initState();
    _charger();
    // Rechargement automatique toutes les 5 secondes.
    _timerRafraichir = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _charger(),
    );
  }

  @override
  void dispose() {
    _timerRafraichir?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() => _erreur = null);
    try {
      // On charge le profil d'abord, car on a besoin de son id pour
      // demander ensuite SES rendez-vous et SES statistiques.
      final medecin = await _service.getProfilConnecte();
      // getTousRendezVous (et non getRendezVousDuJour) : le médecin
      // doit voir TOUS ses RDV, y compris ceux confirmés par la
      // secrétaire à des dates futures. Le filtre "du jour" est fait
      // dans l'écran d'accueil si besoin.
      final rendezVous = await _service.getTousRendezVous(medecin.id);
      final stats = await _service.getStatistiques(medecin.id);
      // Drapeaux « consultation non terminée » (affichage « Non
      // terminé » en style neutre dans les écrans).
      final idsNonTermines =
          await _service.getConsultationsNonTerminees(medecin.id);

      // On ne met à jour l'état qu'une seule fois, avec toutes les
      // données prêtes en même temps, plutôt que 3 fois séparément
      // (évite 2 reconstructions d'écran inutiles).
      if (mounted) {
        // Règle d'affichage (point 3) : le médecin ne voit que SES
        // rendez-vous CONFIRMÉS et TERMINÉS. Les en attente sont
        // gérés par la secrétaire ; refusés/annulés ne le concernent
        // plus. Le chargement complet reste utilisé pour les
        // notifications (détection des RDV qui deviennent visibles).
        bool visible(RendezVous r) =>
            r.statut == StatutRendezVous.confirme ||
            r.statut == StatutRendezVous.termine;
        final visibles = rendezVous.where(visible).toList();

        // Rendez-vous qui DEVINNENT visibles depuis le dernier
        // rechargement : soit ils viennent d'apparaître, soit la
        // secrétaire vient de confirmer un rendez-vous que le médecin
        // ne voyait pas encore.
        bool etaitDejaVisible(RendezVous r) {
          final ancien = _anciensStatuts[r.id];
          return ancien == StatutRendezVous.confirme ||
              ancien == StatutRendezVous.termine;
        }

        final devenusVisibles =
            visibles.where((r) => !etaitDejaVisible(r)).toList();

        // Détection des REFUS (point 4c) : un rendez-vous connu passe
        // au statut « refusé » (la secrétaire refuse avec un motif).
        // Le refus est invisible dans les listes du médecin : la
        // bannière (et la pastille de la cloche, liée au même état)
        // sont son seul moyen de le savoir. Transition uniquement :
        // un refus déjà présent au premier chargement ne notifie pas.
        final refuses = rendezVous
            .where(
              (r) =>
                  r.statut == StatutRendezVous.refuse &&
                  _anciensStatuts.containsKey(r.id) &&
                  _anciensStatuts[r.id] != StatutRendezVous.refuse,
            )
            .toList();

        // Bannière (maquette §4.1) — priorité au refus (actionnable),
        // sinon « Nouveau rendez-vous » avec le premier RDV devenu
        // visible : « Alice Mba · 10:30 ».
        ({String titre, String sousTitre})? notification;
        if (refuses.isNotEmpty) {
          final refus = refuses.first;
          // Le mapping de getTousRendezVous ne transporte pas
          // motifRefus : lecture ciblée du motif (add-only).
          final motif = await _service.getMotifRefus(refus.id);
          notification = (
            titre: refuses.length == 1
                ? 'Rendez-vous refusé'
                : '${refuses.length} rendez-vous refusés',
            sousTitre: motif == null
                ? 'RDV de ${refus.patientNomComplet} refusé'
                : 'RDV de ${refus.patientNomComplet} refusé : $motif',
          );
        } else if (_anciensStatuts.isNotEmpty && devenusVisibles.isNotEmpty) {
          notification = (
            titre: devenusVisibles.length == 1
                ? 'Nouveau rendez-vous'
                : '${devenusVisibles.length} nouveaux rendez-vous',
            sousTitre:
                '${devenusVisibles.first.patientNomComplet} · '
                '${devenusVisibles.first.heure}',
          );
        }

        setState(() {
          _medecin = medecin;
          _rendezVousVisibles = visibles;
          _stats = stats;
          _idsNonTermines = idsNonTermines;
          // On ne réécrit la bannière QUE s'il y a une nouveauté :
          // un rechargement « vide » ne doit pas effacer une bannière
          // que l'utilisateur n'a pas encore fermée.
          if (notification != null) _notificationRdv = notification;
        });

        // On mémorise les statuts actuels pour le prochain rechargement.
        _anciensStatuts = {
          for (final r in rendezVous) r.id: r.statut,
        };
      }
    } catch (e) {
      if (mounted) setState(() => _erreur = e.toString());
    }
  }

  // NOTE : la CONFIRMATION (acceptation) et le refus des rendez-vous
  // appartiennent à la secrétaire : aucun bouton ni callback « Confirmer »
  // n'existe côté médecin. Le médecin ne fait que Terminer / Non terminé.

  Future<void> _nonTermine(RendezVous rdv) async {
    // Statut « terminé » + drapeau consultationTerminee = false
    // (arbitrage : l'enum du modèle n'a pas de 6ᵉ statut).
    await _service.marquerConsultationNonTerminee(rdv.id);
    await _charger();
    if (mounted) messageFlash(context, 'Consultation marquée non terminée');
  }

  Future<void> _terminer(RendezVous rdv) async {
    await _service.terminerRendezVous(rdv.id);
    await _charger();
    if (mounted) messageFlash(context, 'Consultation terminée');
  }

  Future<void> _deconnexion() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      // Deconnexion : on revient a l'accueil PUBLIC et on vide la pile.
      // Un simple pushReplacementNamed laisserait l'espace prive sous
      // l'accueil, et le bouton retour renverrait dans un ecran qui
      // suppose encore une session ouverte.
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cas 1 : une erreur est survenue (ex: pas de connexion internet,
    // profil introuvable...). État aux couleurs du design system.
    if (_erreur != null) {
      return Scaffold(
        backgroundColor: AppColors.fond,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Impossible de charger votre espace',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.texte,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Erreur : $_erreur',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.texteFaible,
                  ),
                ),
                const SizedBox(height: 20),
                BoutonPrincipal(
                  texte: 'Réessayer',
                  pleineLargeur: false,
                  onPressed: _charger,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Cas 2 : les données ne sont pas encore arrivées → squelette
    // pulsant « moulé » sur le tableau de bord (bien plus pro qu'un
    // simple spinner au centre de l'écran).
    if (_medecin == null) {
      return const Scaffold(
        backgroundColor: AppColors.fond,
        body: SqueletteChargement(
          message: 'Chargement de votre espace…',
        ),
      );
    }

    // Cas 3 : tout est prêt, on affiche l'écran principal avec les
    // vraies données et les vraies actions branchées sur Firestore.
    return EspaceMedecin(
      medecin: _medecin!,
      // Seuls les rendez-vous visibles (confirmés / terminés) sont
      // transmis aux écrans (règle du point 3).
      rendezVousDuJour: _rendezVousVisibles,
      patientsSuivis: _stats['patientsSuivis'] ?? 0,
      idsNonTermines: _idsNonTermines,
      notificationRdv: _notificationRdv,
      onFermerNotificationRdv: _fermerNotification,
      onRafraichir: _charger,
      onNonTermineRendezVous: _nonTermine,
      onTerminerRendezVous: _terminer,
      onDeconnexion: _deconnexion,
    );
  }
}
