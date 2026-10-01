// ─────────────────────────────────────────────────────────────────────
// CARTE DE RENDEZ-VOUS — composant partagé (médecin + secrétaire).
// Refaite sur le design system Medigo (lib/theme/medigo_theme.dart) :
// carte blanche arrondie + ombre douce, pastille horaire à gauche,
// badge de statut coloré à droite, effet de survol sur web.
// ─────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../models/rendez_vous.dart';
import '../theme/medigo_theme.dart';
import 'ui_kit.dart';

/// Associe une couleur de la palette Medigo à chaque statut.
/// (Fonction publique : d'autres écrans peuvent l'importer.)
Color couleurStatutRdv(StatutRendezVous statut) {
  // "switch" sur une valeur d'enum : chaque "case" correspond à une
  // valeur possible de StatutRendezVous.
  switch (statut) {
    case StatutRendezVous.confirme:
      return AppColors.vertSante; // vert santé : c'est validé
    case StatutRendezVous.enAttente:
      return AppColors.ambre; // ambre : ça attend une décision
    // Deux "case" collés sans "return" entre eux = même résultat :
    // refusé ET annulé partagent le même rouge.
    case StatutRendezVous.refuse:
    case StatutRendezVous.annule:
      return AppColors.rouge;
    case StatutRendezVous.termine:
      return AppColors.texteFaible; // gris-bleu discret : terminé
  }
}

/// Libellé français de chaque statut (l'enum, elle, reste en anglais
/// pour respecter les conventions de nommage Dart).
String libelleStatutRdv(StatutRendezVous statut) {
  switch (statut) {
    case StatutRendezVous.confirme:
      return 'Confirmé';
    case StatutRendezVous.enAttente:
      return 'En attente';
    case StatutRendezVous.refuse:
      return 'Refusé';
    case StatutRendezVous.annule:
      return 'Annulé';
    case StatutRendezVous.termine:
      return 'Terminé';
  }
}

/// Badge coloré du statut (« Confirmé », « En attente"...).
/// Réutilisé par la carte ci-dessous et par les écrans de détail.
class ChipStatutRdv extends StatelessWidget {
  final StatutRendezVous statut;

  const ChipStatutRdv({super.key, required this.statut});

  @override
  Widget build(BuildContext context) {
    final couleur = couleurStatutRdv(statut);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        // Couleur pleine diluée à 12 % → fond pastel assorti au statut.
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Rayons.pillule),
      ),
      child: Text(
        libelleStatutRdv(statut),
        style: TextStyle(
          color: couleur,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Carte cliquable représentant un rendez-vous.
/// Utilisée sur les deux dashboards et sur les écrans « liste des RDV ».
class RendezVousCard extends StatelessWidget {
  /// Le rendez-vous à afficher.
  final RendezVous rdv;

  /// Fonction appelée au clic (null = carte non cliquable).
  final VoidCallback? onTap;

  /// true côté secrétaire : elle voit plusieurs médecins mélangés, elle
  /// a donc besoin du nom du médecin concerné sous le nom du patient.
  final bool afficherMedecin;

  const RendezVousCard({
    super.key,
    required this.rdv,
    this.onTap,
    this.afficherMedecin = false,
  });

  @override
  Widget build(BuildContext context) {
    // Sous-titre : nom du médecin (si demandé), sinon le motif de la
    // consultation, sinon un texte par défaut.
    final sousTitre = afficherMedecin && rdv.medecinNom != null
        ? rdv.medecinNom!
        : (rdv.motif != null && rdv.motif!.isNotEmpty
              ? rdv.motif!
              : 'Consultation');

    // CarteMedigo apporte le blanc, les coins arrondis, l'ombre douce
    // et l'effet de survol — on ne gère ici que le CONTENU.
    return CarteMedigo(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          // Pastille horaire : l'information la plus lue d'un coup
          // d'œil, mise en avant à gauche ( fond bleu très clair).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bleuMedical.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(Rayons.petite),
            ),
            child: Text(
              rdv.heure,
              style: const TextStyle(
                color: AppColors.bleuMedical,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Expanded : le bloc de texte prend l'espace restant.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rdv.patientNomComplet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.texte,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sousTitre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.texteFaible,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ChipStatutRdv(statut: rdv.statut),
        ],
      ),
    );
  }
}

/// Panneau « répartition du jour » : comptage des rendez-vous par
/// statut, en lignes « libellé …… nombre » — sans icône.
/// Utilisé dans le panneau latéral des deux dashboards.
class RepartitionStatuts extends StatelessWidget {
  final List<RendezVous> rdvs;

  const RepartitionStatuts({super.key, required this.rdvs});

  @override
  Widget build(BuildContext context) {
    int nb(StatutRendezVous s) => rdvs.where((r) => r.statut == s).length;

    // (libellé, nombre, couleur) — record Dart 3.
    final lignes = <(String, int, Color)>[
      ('Confirmés', nb(StatutRendezVous.confirme), AppColors.vertSante),
      ('En attente', nb(StatutRendezVous.enAttente), AppColors.ambre),
      ('Terminés', nb(StatutRendezVous.termine), AppColors.texteFaible),
      (
        'Annulés / refusés',
        nb(StatutRendezVous.annule) + nb(StatutRendezVous.refuse),
        AppColors.rouge,
      ),
    ];

    return CarteMedigo(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
      child: Column(
        children: [
          for (var i = 0; i < lignes.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      lignes[i].$1,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.texteFaible,
                      ),
                    ),
                  ),
                  Text(
                    lignes[i].$2.toString(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: lignes[i].$3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
