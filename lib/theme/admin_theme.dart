import 'package:flutter/material.dart';

/// Palette de l'Espace Administrateur (admin système et admin hôpital).
/// Violet décliné en plusieurs nuances pour distinguer les tuiles tout en
/// gardant une identité homogène. Les espaces Médecin / Secrétaire / Patient
/// continuent d'utiliser la palette bleue de la maquette.
class AdminCouleurs {
  AdminCouleurs._();

  static const violet = Color(0xFF6D28D9);
  static const violetMoyen = Color(0xFF7C3AED);
  static const indigo = Color(0xFF4F46E5);
  static const pourpre = Color(0xFF9333EA);
  static const violetClair = Color(0xFFEDE9FE);

  /// Fin sombre du dégradé de navigation (proche de la maquette).
  static const violetFonce = Color(0xFF28211A);

  /// Dégradé principal de navigation (rail à gauche / barre du bas).
  static const degrade = LinearGradient(
    begin: Alignment(-0.34, -1),
    end: Alignment(0.34, 1),
    colors: [violet, violetFonce],
  );
}
