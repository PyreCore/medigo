// ─────────────────────────────────────────────────────────────────────
// BOÎTE À OUTILS UI (« UI kit ») DE MEDIGO — composants réutilisables
// partagés par les écrans Médecin et Secrétaire.
//
// Chaque composant est autonome : on l'importe et on l'utilise, sans
// refaire la mise en forme à chaque écran. C'est LE cœur du design
// system (voir aussi lib/theme/medigo_theme.dart pour les couleurs).
// ─────────────────────────────────────────────────────────────────────
import 'dart:convert';

import 'package:flutter/material.dart';
import '../models/rendez_vous.dart';
import '../theme/medigo_theme.dart';

// ─────────────────────────────────────────────────────────────────────
// Helpers utilitaires (fonctions libres, pas des widgets)
// ─────────────────────────────────────────────────────────────────────

// Jours/mois en français, indexés à partir de 0 (weekday de Dart commence
// à 1 = lundi, d'où le « - 1 » dans dateDuJour).
const List<String> _jours = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];
const List<String> _mois = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// Date longue en français, ex: « Mardi 27 septembre ».
/// volontairement SANS le package intl : une dépendance de moins.
String dateDuJour([DateTime? date]) {
  final d = date ?? DateTime.now();
  return '${_jours[d.weekday - 1]} ${d.day} ${_mois[d.month - 1]}';
}

/// Initiales pour les avatars : « Sarah Obame » → « SO ».
/// Retourne « ? » si les deux noms sont vides (évite un crash d'index).
String initiales(String prenom, String nom) {
  final p = prenom.trim();
  final n = nom.trim();
  final resultat =
      '${p.isEmpty ? '' : p[0]}${n.isEmpty ? '' : n[0]}'.toUpperCase();
  return resultat.isEmpty ? '?' : resultat;
}

/// Transforme la valeur stockée dans "photoUrl" en ImageProvider.
/// Deux formats possibles :
///  · "data:image/jpeg;base64,..." → photo enregistrée DANS Firestore
///    (palier gratuit, aucune carte bancaire) ;
///  · "https://..." → simple lien réseau (anciens profils).
/// Retourne null si la valeur est absente ou illisible (l'avatar
/// retombe alors sur les initiales).
ImageProvider? imageProfil(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('data:')) {
    final virgule = url.indexOf(',');
    if (virgule < 0) return null;
    try {
      return MemoryImage(base64Decode(url.substring(virgule + 1)));
    } catch (_) {
      return null; // donnée corrompue → initiales
    }
  }
  return NetworkImage(url);
}

/// Jour relatif d'un rendez-vous pour la liste : « Aujourd'hui »,
/// « Demain », « Hier », sinon la date courte « 15 octobre ».
/// Réutilise la table `_mois` définie plus haut.
String jourRelatif(DateTime date) {
  final maintenant = DateTime.now();
  final aujourdhui = DateTime(maintenant.year, maintenant.month, maintenant.day);
  final jour = DateTime(date.year, date.month, date.day);
  final ecart = jour.difference(aujourdhui).inDays;
  if (ecart == 0) return 'Aujourd\'hui';
  if (ecart == 1) return 'Demain';
  if (ecart == -1) return 'Hier';
  return '${date.day} ${_mois[date.month - 1]}';
}

// ─────────────────────────────────────────────────────────────────────
// Widgets réutilisables
// ─────────────────────────────────────────────────────────────────────

/// Carte de base « Medigo » : fond blanc, coins très arrondis, ombre
/// douce — et une micro-animation de survol (léger zoom + ombre plus
/// marquée) sur web/desktop quand la carte est cliquable.
class CarteMedigo extends StatefulWidget {
  final Widget child;

  /// Espace à l'INTÉRIEUR de la carte.
  final EdgeInsetsGeometry padding;

  /// Espace en DEHORS (ex: marge entre deux cartes d'une liste).
  final EdgeInsetsGeometry margin;

  /// Si fournie, la carte devient cliquable (curseur « main » + hover).
  final VoidCallback? onTap;

  final Color couleur;
  final double rayon;

  const CarteMedigo({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.couleur = AppColors.surface,
    this.rayon = Rayons.carte,
  });

  @override
  State<CarteMedigo> createState() => _CarteMedigoState();
}

class _CarteMedigoState extends State<CarteMedigo> {
  // Vrai quand la souris survole la carte (effet utile surtout sur web).
  bool _survol = false;

  // Vrai pendant que l'utilisateur maintient le clic enfoncé : la carte
  // « s'enfonce » légèrement puis ressort — effet tactile premium.
  bool _enfonce = false;

  @override
  Widget build(BuildContext context) {
    // Une carte non cliquable ne réagit ni au survol ni à l'enfoncement.
    final cliquable = widget.onTap != null;

    return MouseRegion(
      // Curseur « main » pour signifier « cliquable ».
      cursor: cliquable ? SystemMouseCursors.click : MouseCursor.defer,
      onHover: (_) {
        if (cliquable && !_survol) setState(() => _survol = true);
      },
      onExit: (_) {
        if (_survol) setState(() => _survol = false);
      },
      // Listener reçoit TOUS les pointeurs : l'enfoncement est perçu
      // même si un widget enfant remporte la compétition de gestes.
      child: Listener(
        onPointerDown: (_) {
          if (cliquable) setState(() => _enfonce = true);
        },
        onPointerUp: (_) {
          if (_enfonce) setState(() => _enfonce = false);
        },
        onPointerCancel: (_) {
          if (_enfonce) setState(() => _enfonce = false);
        },
        child: GestureDetector(
          onTap: widget.onTap,
          // Trois états animés : repos (1) · survol (1,015) · enfoncé
          // (0,985). On évite Matrix4.scale, déprécié sur Flutter récent.
          child: AnimatedScale(
            scale: _enfonce ? 0.985 : (_survol ? 1.015 : 1.0),
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              margin: widget.margin,
              padding: widget.padding,
              decoration: BoxDecoration(
                color: widget.couleur,
                borderRadius: BorderRadius.circular(widget.rayon),
                border: Border.all(color: AppColors.trait),
                // L'ombre passe doucement de « repos » à « survol ».
                boxShadow: [_survol ? Ombres.survol : Ombres.carte],
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Enveloppe d'enfoncement partagée par les boutons : le bouton se
/// rétracte légèrement quand on le maintient (effet « touche physique »)
/// puis ressort. On utilise Listener plutôt que GestureDetector car il
/// reçoit TOUS les événements pointeur, même quand le bouton interne
/// remporte la compétition de gestes.
class _Enfoncement extends StatefulWidget {
  final Widget child;

  /// false = pas d'animation (bouton désactivé ou en chargement).
  final bool actif;

  const _Enfoncement({required this.child, this.actif = true});

  @override
  State<_Enfoncement> createState() => _EnfoncementState();
}

class _EnfoncementState extends State<_Enfoncement> {
  bool _enfonce = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        if (widget.actif && !_enfonce) setState(() => _enfonce = true);
      },
      onPointerUp: (_) {
        if (_enfonce) setState(() => _enfonce = false);
      },
      onPointerCancel: (_) {
        if (_enfonce) setState(() => _enfonce = false);
      },
      child: AnimatedScale(
        scale: _enfonce ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Bouton d'action principal : large, arrondi en pilule, avec un état
/// de chargement animé (spinner) pendant l'enregistrement.
class BoutonPrincipal extends StatelessWidget {
  final String texte;

  /// Null = bouton désactivé (par défaut inactif tant que le formulaire
  /// n'est pas complet, par exemple).
  final VoidCallback? onPressed;

  /// true = on affiche le spinner et on désactive le clic.
  final bool enChargement;

  final Color couleur;

  /// true (défaut) : le bouton prend toute la largeur disponible.
  final bool pleineLargeur;

  /// Hauteur : 52 par défaut (formulaires), plus compact (≈42) quand
  /// le bouton vit dans un en-tête de page.
  final double hauteur;

  const BoutonPrincipal({
    super.key,
    required this.texte,
    required this.onPressed,
    this.enChargement = false,
    this.couleur = AppColors.bleuMedical,
    this.pleineLargeur = true,
    this.hauteur = 52,
  });

  @override
  Widget build(BuildContext context) {
    final bouton = ElevatedButton(
      // Pendant le chargement : clics ignorés (évite les doubles envois).
      onPressed: enChargement ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: couleur,
        foregroundColor: Colors.white,
        // Version atténuée du bouton pendant le spinner / si inactif.
        disabledBackgroundColor: couleur.withValues(alpha: 0.5),
        disabledForegroundColor: Colors.white,
        elevation: 0,
        shape: const StadiumBorder(),
        minimumSize: Size(pleineLargeur ? double.infinity : 0, hauteur),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      // Pas d'icône : libellé seul (parti pris « zéro emoji/icône »
      // de l'interface, purement textuel et international).
      child: enChargement
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: Colors.white,
              ),
            )
          : Text(texte),
    );

    // AnimatedOpacity : fondu rapide quand l'état change (actif ↔ spin).
    // _Enfoncement : enfoncement léger au clic, sur toute la surface.
    return _Enfoncement(
      actif: onPressed != null && !enChargement,
      child: AnimatedOpacity(
        opacity: enChargement || onPressed != null ? 1 : 0.55,
        duration: const Duration(milliseconds: 180),
        child: bouton,
      ),
    );
  }
}

/// Bouton secondaire « contour » : pilule blanche, texte et bordure
/// bleus (ou rouge pour une action destructive comme la déconnexion).
/// Utilisé à côté d'un BoutonPrincipal pour les actions secondaires.
class BoutonContour extends StatelessWidget {
  final String texte;
  final VoidCallback? onPressed;
  final Color couleur;
  final double hauteur;
  final bool pleineLargeur;

  const BoutonContour({
    super.key,
    required this.texte,
    required this.onPressed,
    this.couleur = AppColors.bleuMedical,
    this.hauteur = 42,
    this.pleineLargeur = false,
  });

  @override
  Widget build(BuildContext context) {
    return _Enfoncement(
      actif: onPressed != null,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: couleur,
          // Bordure assortie au texte, légèrement atténuée.
          side: BorderSide(color: couleur.withValues(alpha: 0.55)),
          backgroundColor: AppColors.surface,
          minimumSize: Size(pleineLargeur ? double.infinity : 0, hauteur),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        child: Text(texte),
      ),
    );
  }
}

/// Micro-animation d'apparition : fondu + glissement vers le haut, avec
/// un décalage (delay) pour créer l'effet « liste qui se remplit
/// progressivement » (stagger) façon Doctolib.
///
/// Utilisation dans une liste :
/// ```dart
/// ...liste.asMap().entries.map(
///   (e) => Apparition(
///     delaiMs: 60 * e.key,   // 0 ms, 60 ms, 120 ms...
///     child: MaCarte(...),
///   ),
/// )
/// ```
class Apparition extends StatefulWidget {
  final Widget child;

  /// Délai avant que l'animation démarre (en millisecondes).
  final int delaiMs;

  const Apparition({super.key, required this.child, this.delaiMs = 0});

  @override
  State<Apparition> createState() => _ApparitionState();
}

class _ApparitionState extends State<Apparition> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    // On démarre l'animation APRÈS le délai demandé (une seule fois).
    Future.delayed(Duration(milliseconds: widget.delaiMs), () {
      // mounted = le widget est toujours dans l'arbre ? Sinon on ne
      // touche à rien (l'écran a peut-être été quitté entre-temps).
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        // Départ 8 % de la hauteur plus bas, arrivée à zéro.
        offset: _visible ? Offset.zero : const Offset(0, 0.08),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────
/// DÉGRADÉ SIGNATURE MEDIGO — la carte « Prochain rendez-vous » et la
/// première tuile de statistiques des deux dashboards. Bleu médical en
/// haut qui descend vers un bleu-nuit profond : c'est l'identité visuelle
/// de Medigo sur les écrans de tableau de bord.
/// ─────────────────────────────────────────────────────────────────────
const LinearGradient degradeMedigo = LinearGradient(
  // Diagonal : bleu vif en haut à gauche → noir profond en bas à droite
  // (aligné sur la maquette « Medigo Médecin et Secrétaire »).
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF3B5BFD), Color(0xFF0B0A1A)],
);

/// Carte au dégradé signature : même géométrie que CarteMedigo (coins
/// arrondis, ombre douce) mais fond en dégradé et texte BLANC. Utilisée
/// pour la carte « Prochain rendez-vous » et la première tuile de stats.
class CarteGradientMedigo extends StatelessWidget {
  /// Le contenu affiché sur le dégradé (texte blanc).
  final Widget child;

  /// Espace à l'intérieur de la carte.
  final EdgeInsetsGeometry padding;

  /// Espace en dehors (marge par rapport aux cartes voisines).
  final EdgeInsetsGeometry margin;

  /// Si fournie, la carte est cliquable (ex: ouvrir le détail du RDV).
  final VoidCallback? onTap;

  /// Rayon des coins (24 px pour la carte « Prochain rendez-vous »).
  final double rayon;

  const CarteGradientMedigo({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.rayon = 24,
  });

  @override
  Widget build(BuildContext context) {
    final carte = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: degradeMedigo,
        borderRadius: BorderRadius.circular(rayon),
        // Lombre reprend la teinte du dégradé pour un rendu cohérent.
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B5BFD).withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    // Non cliquable : on renvoie simplement la carte.
    if (onTap == null) return carte;

    // Cliquable : curseur « main » + effet d'enfoncement au clic,
    // exactement comme CarteMedigo.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: carte,
      ),
    );
  }
}

/// Carte de statistique (« métrique ») du dashboard : un grand chiffre,
/// un libellé discret et un fin trait d'accent coloré en haut —
/// SANS icône (parti pris visuel : interface purement textuelle).
class TuileStat extends StatelessWidget {
  final String valeur;
  final String libelle;

  /// Couleur du trait d'accent (elle différencie les métriques sans
  /// alourdir l'affichage).
  final Color couleur;

  /// true = la tuile est peinte avec le dégradé signature Medigo
  /// (bleu → nuit) et le texte devient blanc. C'est la PREMIÈRE tuile
  /// des deux dashboards qui l'utilise, pour attirer l'œil.
  final bool fondDegrade;

  const TuileStat({
    super.key,
    required this.valeur,
    required this.libelle,
    this.couleur = AppColors.bleuMedical,
    this.fondDegrade = false,
  });

  @override
  Widget build(BuildContext context) {
    // Sur dégradé : le texte est blanc (sinon illisible sur le bleu).
    final couleurValeur = fondDegrade ? Colors.white : AppColors.texte;
    final couleurLibelle =
        fondDegrade ? Colors.white.withValues(alpha: 0.85) : AppColors.texteFaible;

    final contenu = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compteur animé : le chiffre « défile » de 0 jusqu'à sa
        // valeur au chargement, puis se ré-anime quand il change.
        _CompteurAnime(valeur: valeur, couleur: couleurValeur),
        const SizedBox(height: 5),
        Text(
          libelle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: couleurLibelle,
          ),
        ),
      ],
    );

    // Version standard : carte blanche du design system.
    if (!fondDegrade) {
      return CarteMedigo(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        rayon: Rayons.carte,
        child: contenu,
      );
    }

    // Version dégradé : même disposition, fond signature.
    return CarteGradientMedigo(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      rayon: Rayons.carte,
      child: contenu,
    );
  }
}

/// Compteur animé utilisé par TuileStat : le nombre monte de 0 à sa
/// valeur (700 ms, courbe amortie), comme sur les tableaux de bord
/// professionnels. Si la valeur n'est pas un nombre (ex : « 1 j »),
/// elle est affichée telle quelle.
class _CompteurAnime extends StatelessWidget {
  final String valeur;

  /// Couleur du chiffre (blanc sur dégradé, quasi-noir sur carte blanche).
  final Color couleur;

  const _CompteurAnime({required this.valeur, this.couleur = AppColors.texte});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 26,
      height: 1,
      fontWeight: FontWeight.w800,
      color: couleur,
    );
    final cible = int.tryParse(valeur);
    if (cible == null) return Text(valeur, style: style);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: cible.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, valeurAnimee, _) => Text(
        valeurAnimee.round().toString(),
        style: style,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// COMPOSANTS DE LA MAQUETTE « Medigo Médecin et Secrétaire »
// Badges de statut, pastilles d'heure, avatars à initiales, tuiles de
// statistiques à icône, bandeaux d'information et dégradés signature.
// (Ajoutés sans modifier les composants existants, pour ne pas déteindre
// sur l'espace Patient qui réutilise CarteMedigo.)
// ─────────────────────────────────────────────────────────────────────

/// Dégradé SIGNATURE de la maquette : bleu vif en haut à gauche qui
/// descend vers un noir profond en bas à droite (diagonal). Utilisé par
/// la carte « Prochain rendez-vous », le bouton « Accepter » et la barre
/// de navigation.
const LinearGradient degradeSignature = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF3B5BFD), Color(0xFF0B0A1A)],
);

/// Dégradé de l'en-tête du détail d'un rendez-vous : lavande très claire
/// en haut à gauche → indigo en bas à droite. Le texte y reste NAVY
/// (donc lisible sur la partie claire).
const LinearGradient degradeDetail = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFEFEDFB), Color(0xFF5A6BFF)],
);

/// Dégradé des bandeaux d'information (« Lecture seule ») : lavande à
/// gauche → bleu à droite (horizontal).
const LinearGradient degradeBandeau = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFFECEAFA), Color(0xFF5566FF)],
);

/// Badge de statut d'un rendez-vous : fond pastel + texte coloré,
/// entièrement arrondi (pilule). Reproduit exactement la maquette
/// (Confirmé vert, En attente ambre, Refusé rouge, Terminé gris).
class PastilleStatut extends StatelessWidget {
  final StatutRendezVous statut;

  const PastilleStatut({super.key, required this.statut});

  // Fond pastel du badge selon le statut.
  static Color _fond(StatutRendezVous s) {
    switch (s) {
      case StatutRendezVous.confirme:
        return AppColors.vertClair;
      case StatutRendezVous.refuse:
        return AppColors.roseClair;
      case StatutRendezVous.enAttente:
        return AppColors.ambreClair;
      case StatutRendezVous.annule:
      case StatutRendezVous.termine:
        return AppColors.grisClair;
    }
  }

  // Texte coloré du badge selon le statut.
  static Color _texte(StatutRendezVous s) {
    switch (s) {
      case StatutRendezVous.confirme:
        return AppColors.vertBadge;
      case StatutRendezVous.refuse:
        return AppColors.rougeBadge;
      case StatutRendezVous.enAttente:
        return AppColors.ambreBadge;
      case StatutRendezVous.annule:
      case StatutRendezVous.termine:
        return AppColors.grisBadge;
    }
  }

  // Libellé affiché selon le statut.
  static String _libelle(StatutRendezVous s) {
    switch (s) {
      case StatutRendezVous.confirme:
        return 'Confirmé';
      case StatutRendezVous.refuse:
        return 'Refusé';
      case StatutRendezVous.enAttente:
        return 'En attente';
      case StatutRendezVous.annule:
        return 'Annulé';
      case StatutRendezVous.termine:
        return 'Terminé';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _fond(statut),
        borderRadius: BorderRadius.circular(Rayons.pillule),
      ),
      child: Text(
        _libelle(statut),
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: _texte(statut),
        ),
      ),
    );
  }
}

/// Pilule de filtre (onglets « Rendez-vous ») : active = fond sombre +
/// texte blanc ; inactive = blanc cerné d'un fin liseré. Comme la maquette.
class ChipFiltrePilule extends StatelessWidget {
  final String label;
  final bool selectionne;
  final VoidCallback onTap;

  const ChipFiltrePilule({
    super.key,
    required this.label,
    required this.selectionne,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rayons.pillule),
            color: selectionne ? AppColors.navy : Colors.white,
            border: selectionne ? null : Border.all(color: AppColors.trait),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selectionne ? Colors.white : AppColors.texte,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pastille d'heure de la liste du tableau de bord : carré arrondi bleu
/// clair, heure en bleu vif gras (ex : « 09:00 »).
class PastilleHeure extends StatelessWidget {
  final String heure;

  const PastilleHeure({super.key, required this.heure});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bleuClair,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        heure,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.bleuVif,
        ),
      ),
    );
  }
}

/// Avatar circulaire à initiales (fond bleu clair, initiales bleues) —
/// utilisé pour les patients dans les listes et le détail.
class AvatarInitiales extends StatelessWidget {
  final String lettres;

  /// Rayon du cercle (rayon 22 → 44 px de large, comme la maquette).
  final double rayon;

  /// Photo éventuelle (base64 ou réseau) ; si absente → initiales.
  final ImageProvider? photo;

  const AvatarInitiales({
    super.key,
    required this.lettres,
    this.rayon = 22,
    this.photo,
  });

  @override
  Widget build(BuildContext context) {
    final taille = rayon * 2;
    // Photo présente : on l'affiche dans un cercle.
    if (photo != null) {
      return ClipOval(
        child: Image(
          image: photo!,
          width: taille,
          height: taille,
          fit: BoxFit.cover,
        ),
      );
    }
    // Sinon : initiales sur fond pastel.
    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppColors.bleuClair, shape: BoxShape.circle),
      child: Text(
        lettres,
        style: TextStyle(
          fontSize: rayon * 0.72,
          fontWeight: FontWeight.w800,
          color: AppColors.bleuVif,
        ),
      ),
    );
  }
}

/// Tuile de statistique de la maquette : pastille d'icône pastel en
/// haut, grand chiffre animé, puis libellé gris (peut tenir sur 2 lignes).
class TuileStatIcone extends StatelessWidget {
  final IconData icone;
  final Color couleur; // couleur de l'icône
  final Color fondPastel; // fond circulaire pastel de l'icône
  final String valeur;
  final String libelle;

  const TuileStatIcone({
    super.key,
    required this.icone,
    required this.couleur,
    required this.fondPastel,
    required this.valeur,
    required this.libelle,
  });

  @override
  Widget build(BuildContext context) {
    return CarteMedigo(
      padding: const EdgeInsets.all(15),
      rayon: Rayons.carte,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pastille d'icône.
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: fondPastel, shape: BoxShape.circle),
            child: Icon(icone, size: 20, color: couleur),
          ),
          const SizedBox(height: 12),
          // Grand chiffre animé (comme TuileStat).
          _CompteurAnime(valeur: valeur, couleur: AppColors.texte),
          const SizedBox(height: 3),
          Text(
            libelle,
            maxLines: 2,
            style: const TextStyle(fontSize: 12, color: AppColors.texteFaible),
          ),
        ],
      ),
    );
  }
}

/// Bandeau d'information (ex : « Lecture seule » des disponibilités) :
/// dégradé lavande→bleu, pastille bleue avec icône blanche, titre gras
/// navy et corps de texte navy.
class BandeauInfo extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String corps;

  const BandeauInfo({
    super.key,
    required this.icone,
    required this.titre,
    required this.corps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: degradeBandeau,
        borderRadius: BorderRadius.circular(Rayons.carte),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pastille bleue avec icône blanche.
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.bleuVif,
              shape: BoxShape.circle,
            ),
            child: Icon(icone, size: 22, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  corps,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton principal en dégradé signature (bleu → nuit), texte blanc gras.
/// Utilisé pour « Accepter » dans le détail d'un rendez-vous.
class BoutonDegrade extends StatelessWidget {
  final String texte;
  final VoidCallback? onPressed;
  final bool pleineLargeur;
  final double hauteur;

  const BoutonDegrade({
    super.key,
    required this.texte,
    required this.onPressed,
    this.pleineLargeur = true,
    this.hauteur = 52,
  });

  @override
  Widget build(BuildContext context) {
    return _Enfoncement(
      actif: onPressed != null,
      child: Opacity(
        opacity: onPressed != null ? 1 : 0.55,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            height: hauteur,
            width: pleineLargeur ? double.infinity : null,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              gradient: degradeSignature,
              borderRadius: BorderRadius.circular(Rayons.pillule),
            ),
            child: Text(
              texte,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte de rendez-vous du TABLEAU DE BORD (« Rendez-vous d'aujourd'hui »)
/// : pastille d'heure à gauche, nom + motif au milieu, badge de statut à
/// droite. Reproduit la maquette. (Distincte de RendezVousCard, qui sert
/// l'espace Patient et garde sa flèche.)
class CarteRdvTableau extends StatelessWidget {
  final RendezVous rdv;
  final VoidCallback? onTap;

  /// Sous-titre forcé (ex : « Dr X » pour la secrétaire). Si null, on
  /// affiche le motif du rendez-vous.
  final String? sousTitre;

  const CarteRdvTableau({
    super.key,
    required this.rdv,
    this.onTap,
    this.sousTitre,
  });

  @override
  Widget build(BuildContext context) {
    final texte = sousTitre ?? (rdv.motif ?? '');
    return CarteMedigo(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      rayon: Rayons.carte,
      child: Row(
        children: [
          PastilleHeure(heure: rdv.heure),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rdv.patientNomComplet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.texte,
                  ),
                ),
                if (texte.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    texte.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.texteFaible,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          PastilleStatut(statut: rdv.statut),
        ],
      ),
    );
  }
}

/// Carte de rendez-vous de la LISTE (« Rendez-vous ») : avatar à initiales
/// à gauche, nom + « jour · heure » + motif au milieu, badge de statut à
/// droite. Reproduit la maquette.
class CarteRdvListe extends StatelessWidget {
  final RendezVous rdv;
  final VoidCallback? onTap;

  /// Dernière ligne forcée (ex : « Dr X » pour la secrétaire). Si null,
  /// on affiche le motif du rendez-vous.
  final String? sousTitre;

  const CarteRdvListe({
    super.key,
    required this.rdv,
    this.onTap,
    this.sousTitre,
  });

  @override
  Widget build(BuildContext context) {
    final motif = (sousTitre ?? rdv.motif ?? '').trim();
    return CarteMedigo(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      rayon: Rayons.carte,
      child: Row(
        children: [
          AvatarInitiales(lettres: initiales(rdv.patientPrenom, rdv.patientNom)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rdv.patientNomComplet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.texte,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${jourRelatif(rdv.date)} · ${rdv.heure}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.texteFaible,
                  ),
                ),
                if (motif.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    motif,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.texteFaible,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          PastilleStatut(statut: rdv.statut),
        ],
      ),
    );
  }
}

/// État « liste vide » sobre : un message court et un détail —
/// sans icône (parti pris visuel de l'application).
class EtatVide extends StatelessWidget {
  final String message;
  final String? detail;

  const EtatVide({super.key, required this.message, this.detail});

  @override
  Widget build(BuildContext context) {
    return CarteMedigo(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.texte,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 4),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.texteFaible,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Titre de section + éventuel lien d'action à droite (« Voir tout »).
class EnTeteSection extends StatelessWidget {
  final String titre;
  final String? action;
  final VoidCallback? onAction;

  const EnTeteSection({
    super.key,
    required this.titre,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Flexible : un très long titre est coupé au lieu de sortir
          // de l'écran en poussant le bouton hors de la zone visible.
          Flexible(
            child: Text(
              titre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.texte,
              ),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

/// Barre du haut standardisée : blanche, sans ombre, titre bleu nuit
/// en gras. Factorisée pour que les espaces Médecin et Secrétaire
/// soient strictement identiques.
class BarreHauteMedigo extends StatelessWidget
    implements PreferredSizeWidget {
  final String titre;
  final List<Widget>? actions;

  const BarreHauteMedigo({super.key, required this.titre, this.actions});

  // Hauteur standard d'une AppBar (constante Flutter kToolbarHeight).
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(titre),
      actions: actions,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.bleuNuit,
      // Empêche Material 3 d'ajouter sa teinte bleutée sur la barre :
      // on veut du blanc pur.
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: const TextStyle(
        color: AppColors.bleuNuit,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Barre de navigation du bas standardisée : fond blanc, pastille
/// d'indicateur bleue translucide, libellé en gras + coloré quand
/// l'onglet est sélectionné.
/// (NOTE : remplacée par la barre à libellés SEULS de
/// lib/widgets/structure_espace.dart — l'application n'utilise plus
/// d'icônes de navigation.)

// ─────────────────────────────────────────────────────────────────────
// EFFETS DE PRODUCTION — transitions, messages, chargement
// ─────────────────────────────────────────────────────────────────────

/// Transition d'écran « premium » : l'écran entrant glisse légèrement
/// depuis la droite avec un fondu, au lieu de la transition Material
/// par défaut. Utilisée à la place de MaterialPageRoute pour les
/// écrans poussés (détail, formulaires).
///
/// Utilisation : `Navigator.push(context, routeMedigo(builder: (_) => MaPage()))`
Route<T> routeMedigo<T>({required Widget Function(BuildContext) builder}) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, _, _) => builder(context),
    transitionsBuilder: (_, animation, _, child) {
      final courbe = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: courbe,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(courbe),
          child: child,
        ),
      );
    },
  );
}

/// Message flottant de confirmation : fond vert santé pour un succès,
/// rouge pour une erreur — coins arrondis, sans icône. Affiché après
/// une action (« Rendez-vous confirmé », « Photo mise à jour »...).
void messageFlash(BuildContext context, String texte, {bool succes = true}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        texte,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: succes ? AppColors.vertSante : AppColors.rouge,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Rayons.carte),
      ),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Squelette de chargement : blocs gris qui « pulsent » doucement,
/// moulés sur la forme du tableau de bord (en-tête + métriques + liste).
/// Bien plus professionnel qu'un simple spinner au centre de l'écran.
class SqueletteChargement extends StatefulWidget {
  final String message;

  const SqueletteChargement({super.key, this.message = 'Chargement…'});

  @override
  State<SqueletteChargement> createState() => _SqueletteChargementState();
}

class _SqueletteChargementState extends State<SqueletteChargement>
    with SingleTickerProviderStateMixin {
  // Boucle 0,45 → 1 → 0,45 : la « pulsation » douce des blocs gris.
  late final AnimationController _pulsation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulsation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1.0).animate(
        CurvedAnimation(parent: _pulsation, curve: Curves.easeInOut),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // En-tête : avatar + deux lignes de texte.
          const Row(
            children: [
              _Bloc(52, 52, rayon: 26),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bloc(double.infinity, 16),
                    SizedBox(height: 8),
                    _Bloc(double.infinity, 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Trois métriques.
          const Row(
            children: [
              Expanded(child: _Bloc(double.infinity, 76)),
              SizedBox(width: 10),
              Expanded(child: _Bloc(double.infinity, 76)),
              SizedBox(width: 10),
              Expanded(child: _Bloc(double.infinity, 76)),
            ],
          ),
          const SizedBox(height: 24),
          const _Bloc(double.infinity, 15),
          const SizedBox(height: 12),
          const _Bloc(double.infinity, 76),
          const SizedBox(height: 12),
          const _Bloc(double.infinity, 76),
          const SizedBox(height: 12),
          const _Bloc(double.infinity, 76),
          const SizedBox(height: 24),
          Center(
            child: Text(
              widget.message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.texteFaible,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un bloc gris du squelette (largeur double.infinity = toute la place).
class _Bloc extends StatelessWidget {
  final double largeur;
  final double hauteur;
  final double rayon;

  const _Bloc(this.largeur, this.hauteur, {this.rayon = 14});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: largeur,
      height: hauteur,
      decoration: BoxDecoration(
        color: const Color(0xFFE3E9F4),
        borderRadius: BorderRadius.circular(rayon),
      ),
    );
  }
}
