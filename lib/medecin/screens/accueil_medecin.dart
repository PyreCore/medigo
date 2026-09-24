import 'package:flutter/material.dart';
import '../../models/medecin.dart';
import '../../models/rendez_vous.dart';
// "../../" = on remonte de DEUX dossiers depuis screens/medecin/ pour
// arriver à lib/, puis on redescend dans widgets/.
import '../../widgets/rendez_vous_card.dart';

/// Contenu de l'onglet "Accueil" de l'espace Médecin.
/// Affiche un résumé (statistiques du jour) + les rendez-vous du jour.
// StatelessWidget : cet écran ne stocke rien lui-même, il se contente
// d'afficher les données qu'on lui donne depuis l'extérieur (voir
// EspaceMedecin, qui construit ce widget avec les vraies données).
class AccueilMedecin extends StatelessWidget {
  // Toutes les données nécessaires à l'affichage, fournies par le parent.
  final Medecin medecin;
  final List<RendezVous> rendezVousDuJour;
  final int enAttente;
  final int patientsSuivis;

  // Fonctions "callback" : ce widget ne sait PAS naviguer tout seul,
  // il se contente d'appeler ces fonctions quand l'utilisateur interagit,
  // et laisse le parent (EspaceMedecin) décider quoi faire (ex: changer
  // d'onglet, ouvrir un écran de détail...). Ça garde ce widget "simple"
  // et réutilisable.
  final VoidCallback onVoirTout;
  // "ValueChanged<RendezVous>" est un type de fonction qui prend UN
  // RendezVous en paramètre et ne renvoie rien : c'est ce qu'on appelle
  // quand l'utilisateur tape sur une carte précise.
  final ValueChanged<RendezVous> onTapRendezVous;

  // Fonction asynchrone optionnelle, appelée quand l'utilisateur tire
  // l'écran vers le bas pour rafraîchir (voir RefreshIndicator plus bas).
  final Future<void> Function()? onRafraichir;

  const AccueilMedecin({
    super.key,
    required this.medecin,
    required this.rendezVousDuJour,
    required this.onVoirTout,
    required this.onTapRendezVous,
    // Valeurs par défaut : si le parent ne précise pas enAttente ou
    // patientsSuivis, on utilise 0 plutôt que d'obliger à toujours les donner.
    this.enAttente = 0,
    this.patientsSuivis = 0,
    this.onRafraichir,
  });

  @override
  Widget build(BuildContext context) {
    // Theme.of(context) récupère le thème Material défini dans main.dart
    // (couleurs, polices...) pour rester cohérent visuellement partout.
    final theme = Theme.of(context);

    // RefreshIndicator ajoute le geste "tirer vers le bas pour rafraîchir",
    // avec le petit cercle de chargement animé natif Material Design.
    return RefreshIndicator(
      // "??" = si onRafraichir est null, on utilise une fonction vide
      // qui ne fait rien, pour éviter un crash.
      onRefresh: onRafraichir ?? () async {},
      // ListView = liste défilante verticalement. On l'utilise même si
      // le contenu ne dépasse pas toujours la hauteur de l'écran, car
      // RefreshIndicator a besoin d'un widget "scrollable" pour fonctionner.
      child: ListView(
        // Espace vide de 16px tout autour du contenu de la liste.
        padding: const EdgeInsets.all(16),
        // "children" = la liste des widgets affichés les uns sous les autres.
        children: [
          // En-tête coloré avec avatar + nom + spécialité du médecin
          // (widget privé défini plus bas dans ce même fichier).
          _EnTeteMedecin(medecin: medecin),
          const SizedBox(height: 20), // espace vertical de 20px
          // Les 3 cartes de statistiques (RDV du jour / en attente / patients).
          _StatistiquesRow(
            rdvAujourdhui: rendezVousDuJour.length, // .length = nombre d'éléments dans la liste
            enAttente: enAttente,
            patientsSuivis: patientsSuivis,
          ),
          const SizedBox(height: 24),
          // Ligne avec le titre "Rendez-vous d'aujourd'hui" à gauche
          // et le bouton "Voir tout" à droite.
          Row(
            // Pousse le premier enfant tout à gauche et le dernier tout
            // à droite, avec l'espace disponible réparti entre les deux.
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rendez-vous d\'aujourd\'hui',
                // "?.copyWith(...)" : on part du style de titre déjà
                // défini par le thème, et on le modifie juste un peu
                // (ici : on le met en gras) sans tout redéfinir.
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                // Quand on appuie sur ce bouton, on exécute la fonction
                // reçue du parent (elle changera d'onglet, voir EspaceMedecin).
                onPressed: onVoirTout,
                child: const Text('Voir tout'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Affichage conditionnel : si la liste est vide, on montre un
          // petit message ; sinon, on affiche toutes les cartes.
          if (rendezVousDuJour.isEmpty)
            const _AucunRendezVous()
          else
            // "..." (spread operator) : .map() transforme chaque RendezVous
            // en un widget RendezVousCard, puis "..." étale ces widgets
            // directement dans la liste "children" (sans le "...", on
            // aurait une Liste DANS la liste, ce que Flutter refuse ici).
            ...rendezVousDuJour.map(
              (rdv) => RendezVousCard(
                rdv: rdv,
                // Fonction fléchée "() => ..." : quand on tape sur CETTE
                // carte précise, on appelle onTapRendezVous en lui passant
                // CE rdv précis (chaque carte "connaît" son propre rendez-vous).
                onTap: () => onTapRendezVous(rdv),
              ),
            ),
        ],
      ),
    );
  }
}

// Widget privé (le underscore _ devant le nom = invisible/inutilisable
// depuis les autres fichiers, seulement dans celui-ci). On sépare le
// code en petits widgets privés pour que build() ci-dessus reste lisible.
class _EnTeteMedecin extends StatelessWidget {
  final Medecin medecin;
  const _EnTeteMedecin({required this.medecin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2E6F6E), // vert-bleu foncé, couleur de marque
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Cercle qui affiche soit une vraie photo, soit une initiale.
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            // "medecin.photoUrl != null ? ... : null" est un opérateur
            // ternaire : "si photoUrl existe, télécharge cette image
            // depuis internet (NetworkImage), sinon backgroundImage reste null".
            backgroundImage:
                medecin.photoUrl != null ? NetworkImage(medecin.photoUrl!) : null,
            // "child" ne s'affiche que si backgroundImage est absent
            // (sinon la photo prendrait toute la place).
            child: medecin.photoUrl == null
                ? Text(
                    // Affiche la première lettre du prénom, ou "?" si le
                    // prénom est vide (pour éviter une erreur d'index).
                    medecin.prenom.isNotEmpty ? medecin.prenom[0] : '?',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E6F6E),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          // Expanded : le nom prend tout l'espace restant à droite de l'avatar.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medecin.nomComplet, // getter du modèle : "Dr Sarah Obame"
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // "$variable" insère une valeur dans une chaîne de texte.
                  '${medecin.specialite} · ${medecin.hopitalNom}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Widget privé pour la ligne des 3 cartes de statistiques.
class _StatistiquesRow extends StatelessWidget {
  final int rdvAujourdhui;
  final int enAttente;
  final int patientsSuivis;

  const _StatistiquesRow({
    required this.rdvAujourdhui,
    required this.enAttente,
    required this.patientsSuivis,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Chaque carte est enveloppée dans "Expanded" pour que les 3
        // cartes se partagent équitablement la largeur disponible
        // (1/3 chacune, comme il y a 3 Expanded dans cette Row).
        Expanded(
          child: _StatCard(
            label: 'RDV aujourd\'hui',
            // .toString() convertit le nombre (int) en texte, car un
            // widget Text n'accepte que des String, pas des nombres.
            valeur: rdvAujourdhui.toString(),
            couleur: const Color(0xFF2E6F6E),
            icone: Icons.calendar_today,
          ),
        ),
        const SizedBox(width: 10), // petit espace entre les cartes
        Expanded(
          child: _StatCard(
            label: 'En attente',
            valeur: enAttente.toString(),
            couleur: const Color(0xFFD98E04),
            icone: Icons.hourglass_bottom,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Patients suivis',
            valeur: patientsSuivis.toString(),
            couleur: const Color(0xFF3B5BA5),
            icone: Icons.people_alt,
          ),
        ),
      ],
    );
  }
}

// Widget privé représentant UNE carte de statistique individuelle
// (réutilisé 3 fois par _StatistiquesRow ci-dessus).
class _StatCard extends StatelessWidget {
  final String label; // texte en petit, ex: "RDV aujourd'hui"
  final String valeur; // gros chiffre, ex: "3"
  final Color couleur; // couleur thématique de cette carte
  final IconData icone; // petite icône affichée en haut

  const _StatCard({
    required this.label,
    required this.valeur,
    required this.couleur,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Espace intérieur différent en vertical (14) et horizontal (10).
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        // Bordure de la couleur de la carte, mais très transparente (20%),
        // pour un contour discret assorti à chaque statistique.
        border: Border.all(color: couleur.withOpacity(0.2)),
      ),
      child: Column(
        // Aligne tout le contenu à gauche à l'intérieur de la carte.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: couleur, size: 20),
          const SizedBox(height: 8),
          Text(
            valeur,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: couleur,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

// Widget privé affiché quand rendezVousDuJour est vide.
class _AucunRendezVous extends StatelessWidget {
  const _AucunRendezVous();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      // Centre le contenu (icône + texte) à l'intérieur du container.
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.event_available, size: 40, color: Colors.black26),
          SizedBox(height: 8),
          Text(
            'Aucun rendez-vous pour aujourd\'hui',
            style: TextStyle(color: Colors.black45),
          ),
        ],
      ),
    );
  }
}
