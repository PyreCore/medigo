// ─────────────────────────────────────────────────────────────────────
// JETONS DE DESIGN DE LA MAQUETTE « Medigo Médecin et Secrétaire »
// (fichier MAQUETTE_SPEC.md, §1 — Design tokens).
//
// Ce fichier est la source de vérité des valeurs de la maquette. Il
// N'EST PAS medigo_theme.dart et ne le remplace pas : il est utilisé
// UNIQUEMENT par les espaces Médecin et Secrétaire (et par les copies
// locales de composants de lib/widgets/maquette_widgets.dart). Les
// espaces Patient / Admin continuent d'utiliser medigo_theme.dart.
// ─────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

/// Couleurs officielles de la maquette (§1).
class MaquetteCouleurs {
  MaquetteCouleurs._();

  /// Fond d'écran des espaces Médecin / Secrétaire.
  static const fond = Color(0xFFF4F6FB);

  /// Surface des cartes.
  static const surface = Colors.white;

  /// Bordure 1 px des cartes et champs.
  static const bordure = Color(0xFFE3E8F2);

  /// Texte principal.
  static const texte = Color(0xFF16203A);

  /// Texte secondaire (libellés, dates, aides).
  static const texteSecondaire = Color(0xFF5B6784);

  /// Bleu principal.
  static const bleu = Color(0xFF2458D3);

  /// Bleu clair (pastilles d'icône, avatars, pastilles d'heure, onglet
  /// actif de la barre de navigation).
  static const bleuClair = Color(0xFFE8EFFD);

  /// Pastille du bouton de notification : rouge vif.
  static const alerteNotif = Color(0xFFD92D20);

  // ── Statuts (fond / texte) ────────────────────────────────────────
  static const confirmeFond = Color(0xFFE3F5EC);
  static const confirmeTexte = Color(0xFF137A4B);
  static const attenteFond = Color(0xFFFFF1DA);
  static const attenteTexte = Color(0xFF9A5B00);
  // Refusé ET Annulé partagent la même paire rouge.
  static const refuseFond = Color(0xFFFDE8E6);
  static const refuseTexte = Color(0xFFB3261E);
  static const termineFond = Color(0xFFE9EDF5);
  static const termineTexte = Color(0xFF4B5671);
}

/// Dégradés de la maquette (§1).
class MaquetteDegrades {
  MaquetteDegrades._();

  /// Dégradé principal « G » : environ 80° (forte pente verticale),
  /// #2458D3 → #28211A. Utilisé sur la barre de navigation, le menu
  /// latéral, les boutons principaux, le filtre actif, les cartes de
  /// statistiques (PC) et les avatars du menu latéral.
  static const principal = LinearGradient(
    // ≈ 80° : on part du haut en décalant légèrement vers la gauche et
    // on descend vers la droite (voisin du vertical).
    begin: Alignment(-0.34, -1),
    end: Alignment(0.34, 1),
    colors: [Color(0xFF2458D3), Color(0xFF28211A)],
  );

  /// Dégradé vertical de la carte « Prochain rendez-vous » :
  /// #4B80FC (haut) → #28211A (bas).
  static const carteProchain = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF4B80FC), Color(0xFF28211A)],
  );

  /// Dégradé des bannières de notification : ≈ 80°,
  /// #7A6BE6 → #28211A.
  static const banniere = LinearGradient(
    begin: Alignment(-0.34, -1),
    end: Alignment(0.34, 1),
    colors: [Color(0xFF7A6BE6), Color(0xFF28211A)],
  );
}

/// Rayons des coins arrondis (§1).
class MaquetteRayons {
  MaquetteRayons._();

  /// Cartes : 18 à 24 selon la carte.
  static const double carte = 18;
  static const double carteHaute = 24;

  /// Boutons.
  static const double bouton = 16;

  /// Pastilles de statut (pilule).
  static const double pillule = 999;

  /// Puces de filtre.
  static const double puce = 22;
}

/// Tailles de texte (§1) — repères pour rester cohérents entre écrans.
class MaquetteTypo {
  MaquetteTypo._();

  static const double titreEcran = 24; // poids 800
  static const double titreSection = 17; // poids 800
  static const double courant = 15;
  static const double secondaire = 13;
  static const double badgeStatut = 12; // poids 700
}

/// Hauteur de zone tactile minimale (§1).
const double maquetteCibleMin = 44;
