// ─────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM MEDIGO — « jetons de design » (design tokens) + thème
// Material 3.
//
// TOUTES les couleurs, formes et ombres de la partie Médecin/Secrétaire
// sont centralisées ICI : une seule source de vérité. Pour relooker
// l'application, on ne modifie que ce fichier.
//
// Palette inspirée de Doctolib / Zocdoc : beaucoup de blanc, bleu
// médical, touches de turquoise et de vert « santé », gris terne évité.
// ─────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

/// Couleurs officielles de Medigo.
class AppColors {
  // Constructeur privé : cette classe n'est qu'un « catalogue » de
  // constantes, on ne doit pas écrire `AppColors()` pour l'instancier.
  AppColors._();

  /// Bleu médical principal (proche du bleu Doctolib) : boutons,
  /// liens, icône de l'onglet actif.
  static const bleuMedical = Color(0xFF0B57D0);

  /// Bleu profond (nuit) : dégradés d'en-tête et titres sur fond blanc.
  static const bleuNuit = Color(0xFF0A2F66);

  /// Turquoise : couleur secondaire (informations, éléments « patients »).
  static const turquoise = Color(0xFF12B5C9);

  /// Vert santé : confirmation, succès, disponibilité.
  static const vertSante = Color(0xFF12B76A);

  /// Ambre : états « en attente » (accentuation douce, jamais une erreur).
  static const ambre = Color(0xFFF59E0B);

  /// Rouge : refus, annulation, déconnexion (danger).
  static const rouge = Color(0xFFE5484D);

  /// Fond des écrans : blanc très légèrement bleuté → propre et aéré,
  /// contrairement à un gris terne.
  static const fond = Color(0xFFF4F7FC);

  /// Surfaces (cartes, barres du haut/bas) : blanc pur.
  static const surface = Colors.white;

  /// Texte principal sur fond clair (quasi-noir, légèrement bleuté).
  static const texte = Color(0xFF0F172A);

  /// Texte secondaire : libellés, dates, aides contextuelles.
  static const texteFaible = Color(0xFF64748B);

  /// Traits / contour des cartes et champs : gris-bleu très clair.
  static const trait = Color(0xFFE4EAF3);
}

/// Formes (rayons des coins arrondis) standardisées.
class Rayons {
  Rayons._();

  /// Cartes : généreusement arrondies (look « clean UI »).
  static const double carte = 18;

  /// Petits éléments (pastilles, badges).
  static const double petite = 12;

  /// Très arrondi ≈ pilule : boutons et chips.
  static const double pillule = 999;
}

/// Ombres portées douces — teintées « bleu nuit » plutôt que noir pur,
/// ce qui donne une ombre plus naturelle sur le fond blanc-bleuté.
class Ombres {
  Ombres._();

  /// Ombre standard sous une carte au repos.
  static final carte = BoxShadow(
    color: AppColors.bleuNuit.withValues(alpha: 0.07),
    blurRadius: 18,
    offset: const Offset(0, 6),
  );

  /// Ombre légèrement plus marquée au survol (hover web/desktop).
  static final survol = BoxShadow(
    color: AppColors.bleuMedical.withValues(alpha: 0.16),
    blurRadius: 24,
    offset: const Offset(0, 10),
  );
}

/// Thème Material 3 de Medigo.
///
/// Pour l'appliquer à un écran sans toucher au `main.dart` (qui appartient
/// à l'Étudiant 1), on enveloppe simplement le Scaffold :
///
/// ```dart
/// return Theme(
///   data: MedigoTheme.claire(),
///   child: Scaffold(...),
/// );
/// ```
class MedigoTheme {
  MedigoTheme._();

  /// Retourne le thème clair complet (couleurs, AppBar, barre de
  /// navigation du bas, boutons, champs de formulaire...).
  static ThemeData claire() {
    // ColorScheme.fromSeed() dérive toute une palette cohérente à partir
    // d'une seule couleur graine ; on lui donne ensuite EXACTEMENT les
    // couleurs Medigo qu'on veut imposer.
    final colorScheme =
        ColorScheme.fromSeed(seedColor: AppColors.bleuMedical).copyWith(
          primary: AppColors.bleuMedical,
          onPrimary: Colors.white,
          secondary: AppColors.turquoise,
          tertiary: AppColors.vertSante,
          surface: AppColors.surface,
          onSurface: AppColors.texte,
          error: AppColors.rouge,
          outline: AppColors.trait,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.fond,

      // AppBar : blanche, sans ombre ni teinte bleutée, titre bleu nuit
      // en gras → l'aspect épuré des dashboards santé.
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.bleuNuit,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: AppColors.bleuNuit,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),

      // Barre de navigation du bas : pastille d'indicateur bleue très
      // claire, libellé en gras + coloré quand l'onglet est sélectionné.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        height: 68,
        indicatorColor: AppColors.bleuMedical.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (etats) => TextStyle(
            fontSize: 12,
            fontWeight: etats.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: etats.contains(WidgetState.selected)
                ? AppColors.bleuMedical
                : AppColors.texteFaible,
          ),
        ),
      ),

      // Boutons principaux : entièrement arrondis (pilule), hauteurs
      // généreuses, texte en gras.
      // NB : elevatedButtonTheme attend un ElevatedButtonThemeData,
      // qui ENROULE un ButtonStyle (retourné par styleFrom).
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.bleuMedical,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.bleuMedical.withValues(
            alpha: 0.45,
          ),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      // Liens de texte (« Voir tout »...) : bleus et en gras.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.bleuMedical,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // Champs de formulaire : fond blanc, coins arrondis, contour
      // discret qui devient bleu quand le champ est focalisé.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.texteFaible),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Rayons.petite),
          borderSide: const BorderSide(color: AppColors.trait),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Rayons.petite),
          borderSide: const BorderSide(color: AppColors.trait),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Rayons.petite),
          borderSide: const BorderSide(color: AppColors.bleuMedical, width: 1.6),
        ),
      ),

      // Séparateurs de liste : le même trait clair que les cartes.
      dividerTheme: const DividerThemeData(
        color: AppColors.trait,
        thickness: 1,
      ),
    );
  }
}
