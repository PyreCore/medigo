import 'package:flutter/material.dart';

/// Onglet "Disponibilités" : gestion des horaires du médecin.
/// TODO: brancher sur Firestore (collection disponibilites) une fois le
/// schéma validé avec l'étudiant 3.
// StatelessWidget car pour l'instant cet écran est un "placeholder"
// (données fictives en dur) : rien de dynamique à mémoriser encore.
class DisponibilitesMedecin extends StatelessWidget {
  const DisponibilitesMedecin({super.key});

  @override
  Widget build(BuildContext context) {
    // Liste fixe des jours de la semaine, écrite "en dur" (hardcodée)
    // pour cette démo. Plus tard, ça pourrait venir de Firestore.
    final jours = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];

    // ListView.builder : liste défilante optimisée, une ligne par jour.
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: jours.length, // 7 éléments (7 jours)
      // Fonction appelée pour construire CHAQUE ligne de la liste.
      itemBuilder: (context, index) {
        // "Card" est un widget Material tout fait : un rectangle avec
        // une légère élévation/ombre par défaut (qu'on annule ici avec
        // elevation: 0 pour avoir un style plus plat, avec juste une bordure).
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.black.withOpacity(0.06)),
          ),
          // SwitchListTile = ligne prête à l'emploi avec un titre, un
          // sous-titre, ET un interrupteur (switch) à droite. Parfait
          // pour "activer/désactiver" un jour de disponibilité.
          child: SwitchListTile(
            title: Text(jours[index]), // "Lundi", "Mardi"...
            subtitle: const Text('08:00 - 16:00'), // horaire fixe pour la démo
            // "index < 5" = vrai pour les indices 0,1,2,3,4 (Lundi à
            // Vendredi), faux pour 5 et 6 (Samedi, Dimanche).
            // C'est juste pour que la démo ait un aspect réaliste (les
            // jours de semaine activés par défaut) : à remplacer par les
            // vraies disponibilités venant de Firestore.
            value: index < 5, // Lun-Ven actifs par défaut, démo uniquement
            activeColor: const Color(0xFF2E6F6E), // couleur du switch quand activé
            // Pour l'instant, on ne modifie rien réellement : on affiche
            // juste un message temporaire (SnackBar = petit bandeau qui
            // apparaît en bas de l'écran puis disparaît tout seul).
            // "(_)" = on ignore la nouvelle valeur du switch reçue en paramètre.
            onChanged: (_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Modification des horaires : à connecter à Firestore',
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
