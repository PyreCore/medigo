import 'package:flutter/material.dart';
import '../../models/rendez_vous.dart';
import '../../widgets/rendez_vous_card.dart';

/// Écran de détail d'un rendez-vous, avec actions accepter / refuser.
// StatelessWidget : cet écran affiche juste les infos du rdv reçu et
// délègue les actions (accepter/refuser) à des fonctions fournies par
// le parent — il ne gère aucun état lui-même.
class DetailRendezVousMedecin extends StatelessWidget {
  final RendezVous rdv; // le rendez-vous dont on affiche le détail

  // Fonctions optionnelles et ASYNCHRONES (elles retournent Future<void>
  // car elles vont probablement appeler Firestore, qui prend du temps).
  // Si elles sont null, les boutons correspondants seront désactivés
  // (voir plus bas : onPressed: null quand la fonction n'est pas fournie).
  final Future<void> Function()? onAccepter;
  final Future<void> Function()? onRefuser;

  const DetailRendezVousMedecin({
    super.key,
    required this.rdv,
    this.onAccepter,
    this.onRefuser,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = couleurStatutRdv(rdv.statut);
    // On ne veut proposer "Accepter/Refuser" que si le rendez-vous est
    // encore "en attente" : ça n'aurait pas de sens de refuser un
    // rendez-vous déjà confirmé, par exemple.
    final enAttente = rdv.statut == StatutRendezVous.enAttente;

    // "Scaffold" = la structure de base d'un écran Material (zone pour
    // la barre du haut, zone pour le contenu, etc.). Contrairement aux
    // autres écrans (qui ne sont que le CONTENU d'un onglet), celui-ci
    // a son propre Scaffold car il s'ouvre en PLEIN ÉCRAN par-dessus
    // les onglets (via Navigator.push, voir espace_medecin.dart).
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      // AppBar = la barre en haut, avec le titre et (ici) automatiquement
      // une flèche "retour" ajoutée par Flutter car cet écran a été ouvert
      // via Navigator.push (il sait qu'il peut revenir en arrière).
      appBar: AppBar(title: const Text('Détail du rendez-vous')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Carte principale avec le nom du patient, le statut, l'heure...
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ligne du haut : nom du patient à gauche, badge de statut à droite.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      rdv.patientNomComplet,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: couleur.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        libelleStatutRdv(rdv.statut),
                        style: TextStyle(
                          color: couleur,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Ligne "libellé …… valeur" (widget privé, sans icône).
                _LigneInfo(libelle: 'Heure', valeur: rdv.heure),
                // "..." (spread) avec "if" : ce bloc n'ajoute des widgets à
                // "children" QUE SI la condition est vraie (motif existe
                // et n'est pas vide). Sinon, rien n'est ajouté du tout —
                // différent d'un "if" classique qui devrait choisir entre
                // deux widgets, ici on peut carrément n'en ajouter aucun.
                if (rdv.motif != null && rdv.motif!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _LigneInfo(libelle: 'Motif', valeur: rdv.motif!),
                ],
              ],
            ),
          ),
          // Les boutons Accepter/Refuser ne s'affichent QUE si le
          // rendez-vous est encore en attente (voir variable "enAttente"
          // calculée plus haut).
          if (enAttente) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                // Expanded fait que chaque bouton prend la moitié de la largeur.
                Expanded(
                  // OutlinedButton = bouton avec juste un contour, pas de
                  // fond plein (style "action secondaire", ici Refuser).
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828), // texte rouge
                      side: const BorderSide(color: Color(0xFFC62828)), // contour rouge
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    // Opérateur ternaire : si onRefuser est null (le
                    // parent n'a pas fourni de fonction), le bouton est
                    // DÉSACTIVÉ (grisé, non cliquable) car onPressed: null.
                    // Sinon, on définit une fonction asynchrone qui...
                    onPressed: onRefuser == null
                        ? null
                        : () async {
                            // ...attend que le refus soit bien enregistré...
                            await onRefuser!();
                            // ...puis vérifie que l'écran est toujours affiché
                            // (context.mounted) avant de fermer cet écran de
                            // détail et revenir à l'écran précédent. Cette
                            // vérification évite une erreur si l'utilisateur
                            // a déjà quitté l'écran pendant que "await" attendait.
                            if (context.mounted) Navigator.pop(context);
                          },
                    child: const Text('Refuser'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  // ElevatedButton = bouton avec un fond plein (style
                  // "action principale", ici Accepter, mis en avant).
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E6F6E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: onAccepter == null
                        ? null
                        : () async {
                            await onAccepter!();
                            if (context.mounted) Navigator.pop(context);
                          },
                    child: const Text('Accepter'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// Petit widget privé : ligne "libellé …… valeur" — sans icône
// (utilisé pour l'heure et le motif dans la carte au-dessus).
class _LigneInfo extends StatelessWidget {
  final String libelle;
  final String valeur;
  const _LigneInfo({required this.libelle, required this.valeur});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            libelle,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(width: 12),
          // Flexible : si la valeur (ex: un long motif) est trop longue,
          // elle passe à la ligne au lieu de faire déborder l'écran.
          Expanded(
            child: Text(
              valeur,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
