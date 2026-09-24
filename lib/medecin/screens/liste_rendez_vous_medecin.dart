import 'package:flutter/material.dart';
import '../../models/rendez_vous.dart';
import '../../widgets/rendez_vous_card.dart';

/// Onglet / écran "Rendez-vous" : liste complète, avec filtre par statut.
// "StatefulWidget" : contrairement à AccueilMedecin (StatelessWidget),
// cet écran a besoin de RETENIR une information qui change dans le temps
// PAR LUI-MÊME (quel filtre est sélectionné) sans dépendre du parent.
// Un StatefulWidget se décompose toujours en 2 classes : le Widget
// (ci-dessous) et son "State" associé (la classe _ListeRendezVousMedecinState
// juste après).
class ListeRendezVousMedecin extends StatefulWidget {
  final List<RendezVous> rendezVous; // tous les rendez-vous à afficher
  final ValueChanged<RendezVous> onTapRendezVous; // callback quand on tape une carte

  const ListeRendezVousMedecin({
    super.key,
    required this.rendezVous,
    required this.onTapRendezVous,
  });

  // Cette méthode est obligatoire pour un StatefulWidget : elle indique
  // à Flutter quelle classe "State" utiliser pour gérer la mémoire/l'affichage
  // de ce widget.
  @override
  State<ListeRendezVousMedecin> createState() =>
      _ListeRendezVousMedecinState();
}

// La classe "State" contient la MÉMOIRE de l'écran (les variables qui
// peuvent changer) et la logique d'affichage. Le préfixe "State<...>"
// donne accès à "widget" à l'intérieur, qui pointe vers l'objet
// ListeRendezVousMedecin ci-dessus (pour lire rendezVous, onTapRendezVous...).
class _ListeRendezVousMedecinState extends State<ListeRendezVousMedecin> {
  // Variable d'état : le filtre actuellement sélectionné.
  // "null" = pas de filtre = on affiche tous les statuts.
  // Cette variable PERSISTE entre chaque redessin de l'écran (contrairement
  // à une variable locale dans build(), qui serait recréée à chaque fois).
  StatutRendezVous? _filtre;

  @override
  Widget build(BuildContext context) {
    // On calcule la liste filtrée à afficher : si aucun filtre n'est
    // choisi, on garde tout ; sinon on ne garde que les rendez-vous dont
    // le statut correspond exactement au filtre sélectionné.
    final rdvFiltres = _filtre == null
        ? widget.rendezVous
        : widget.rendezVous.where((r) => r.statut == _filtre).toList();

    // Column = les éléments s'empilent verticalement : la barre de
    // filtres en haut, puis la liste juste en dessous.
    return Column(
      children: [
        // On donne une hauteur fixe (44px) à la zone des filtres, car
        // une ListView horizontale a besoin d'une hauteur définie pour
        // savoir combien de place elle occupe.
        SizedBox(
          height: 44,
          child: ListView(
            // Défilement HORIZONTAL (au lieu de vertical par défaut),
            // pour aligner les filtres côte à côte et pouvoir les
            // faire glisser si l'écran est étroit.
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: [
              // Premier chip : "Tous" (aucun filtre actif).
              _ChipFiltre(
                label: 'Tous',
                // "selectionne" est vrai quand aucun filtre n'est choisi.
                selectionne: _filtre == null,
                // "setState" est LA méthode clé des StatefulWidget :
                // elle change la valeur de _filtre ET dit à Flutter
                // "redessine cet écran maintenant, les données ont changé".
                // Sans setState, changer _filtre ne rafraîchirait pas l'écran.
                onTap: () => setState(() => _filtre = null),
              ),
              // On génère un chip pour CHAQUE valeur possible de l'enum
              // StatutRendezVous (5 chips en tout : confirmé, en attente...).
              // "StatutRendezVous.values" est une liste automatique de
              // toutes les valeurs de l'enum, fournie par Dart.
              ...StatutRendezVous.values.map(
                (s) => _ChipFiltre(
                  label: libelleStatutRdv(s), // fonction du fichier rendez_vous_card.dart
                  selectionne: _filtre == s,
                  onTap: () => setState(() => _filtre = s),
                ),
              ),
            ],
          ),
        ),
        // "Expanded" : la liste des rendez-vous prend TOUT l'espace
        // vertical restant en dessous des filtres (sinon Column ne
        // saurait pas quelle hauteur lui donner et planterait).
        Expanded(
          // Affichage conditionnel selon si la liste filtrée est vide ou non.
          child: rdvFiltres.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun rendez-vous dans cette catégorie',
                    style: TextStyle(color: Colors.black45),
                  ),
                )
              // ListView.builder est optimisé pour les LONGUES listes :
              // il ne construit que les cartes visibles à l'écran à un
              // instant donné (plutôt que toutes d'un coup comme ListView
              // normal), ce qui est plus performant.
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  // Nombre total d'éléments à afficher.
                  itemCount: rdvFiltres.length,
                  // Fonction appelée pour construire CHAQUE carte,
                  // "index" va de 0 à itemCount-1.
                  itemBuilder: (context, index) {
                    final rdv = rdvFiltres[index];
                    return RendezVousCard(
                      rdv: rdv,
                      onTap: () => widget.onTapRendezVous(rdv),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// Widget privé pour UN bouton de filtre (ex: "Confirmé", "En attente"...).
class _ChipFiltre extends StatelessWidget {
  final String label; // texte affiché sur le chip
  final bool selectionne; // vrai si ce filtre est actuellement actif
  final VoidCallback onTap; // fonction appelée quand on clique dessus

  const _ChipFiltre({
    required this.label,
    required this.selectionne,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8), // espace entre les chips
      // ChoiceChip est un widget Material tout fait pour ce genre de
      // "bouton sélectionnable parmi plusieurs".
      child: ChoiceChip(
        label: Text(label),
        selected: selectionne, // change l'apparence visuelle si sélectionné
        // "(_) =>" : ChoiceChip donne un booléen en paramètre (vrai/faux
        // du nouvel état), mais on n'en a pas besoin ici (d'où le "_",
        // qui veut dire "j'ignore ce paramètre"), on veut juste appeler onTap.
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFF2E6F6E), // fond quand sélectionné
        labelStyle: TextStyle(
          // Texte blanc si sélectionné, sinon presque noir.
          color: selectionne ? Colors.white : Colors.black87,
          fontSize: 12,
        ),
        backgroundColor: Colors.white, // fond quand PAS sélectionné
      ),
    );
  }
}
