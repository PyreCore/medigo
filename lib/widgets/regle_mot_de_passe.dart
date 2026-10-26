/// Règles de mot de passe appliquées à la CRÉATION de tous les comptes :
/// admin système, admin hôpital, médecin, secrétaire et patient.
///
/// Firebase Authentication n'impose que 6 caractères, sans réglage pour
/// l'élever. On durcit donc côté application, et on refuse un mot de passe
/// qui ne remplit pas TOUS les critères de [criteresMotDePasse].
///
/// Le contrôle est côté client : il protège des mots de passe faibles
/// saisis dans l'application, mais ne remplace pas les garde-fous serveur
/// de Firebase, ni la 2FA sur les comptes admin.
library;

import 'package:flutter/material.dart';

/// Longueur minimale imposée.
const int longueurMinimaleMotDePasse = 8;

/// Caractères acceptés comme « caractère spécial ».
const String caracteresSpeciaux = r'!@#$%^&*()_+-=[]{};:"|,.<>/?~`';

/// Libellé d'aide sous le champ mot de passe.
const String aideMotDePasse = '$longueurMinimaleMotDePasse caractères minimum';

// ── Tests unitaires sur une valeur ────────────────────────────────────

bool _aChiffre(String v) => v.contains(RegExp(r'[0-9]'));
bool _aMajuscule(String v) => v.contains(RegExp(r'[A-Z]'));
bool _aMinuscule(String v) => v.contains(RegExp(r'[a-z]'));
bool _aLettre(String v) => v.contains(RegExp(r'[A-Za-z]'));
bool _aSpecial(String v) => v.split('').any(caracteresSpeciaux.contains);

/// Les 4 exigences de la maquette, dans l'ordre d'affichage :
/// (libellé affiché, critère satisfait ?).
List<(String, bool)> criteresMotDePasse(String valeur) {
  return [
    (
      'Au moins $longueurMinimaleMotDePasse caractères.',
      valeur.length >= longueurMinimaleMotDePasse,
    ),
    (
      'Un mélange de majuscules et de minuscules.',
      _aMajuscule(valeur) && _aMinuscule(valeur),
    ),
    (
      'Un mélange de chiffres et de lettres.',
      _aChiffre(valeur) && _aLettre(valeur),
    ),
    (
      'Utilise au moins un caractère spécial, par exemple [ ! @ # ? ].',
      _aSpecial(valeur),
    ),
  ];
}

/// Nombre de critères satisfaits, de 0 à 4.
int scoreMotDePasse(String valeur) =>
    criteresMotDePasse(valeur).where((critere) => critere.$2).length;

/// Vrai si le mot de passe remplit tous les critères.
bool motDePasseValide(String valeur) =>
    criteresMotDePasse(valeur).every((critere) => critere.$2);

/// Premier critère manquant sous forme de message, sinon null.
String? verifierMotDePasse(String valeur) {
  if (motDePasseValide(valeur)) return null;
  return 'Mot de passe refusé : au moins $longueurMinimaleMotDePasse '
      'caractères, une majuscule, une minuscule, un chiffre et un '
      'caractère spécial.';
}

/// Message d'erreur à l'affichage, dès que l'utilisateur a commencé à
/// saisir ; muet tant que le champ est vide.
String? erreurMotDePasse(String valeur) =>
    valeur.isEmpty ? null : verifierMotDePasse(valeur);

// ── Force affichée par la ligne animée ────────────────────────────────

/// Couleur de la ligne de force selon le score (0 à 4) :
/// rouge = faible, jaune = moyen, vert = bon puis excellent.
Color forceCouleur(int score) {
  if (score >= 4) return const Color(0xFF1B7F3B); // vert foncé
  if (score == 3) return const Color(0xFF4CAF50); // vert
  if (score == 2) return const Color(0xFFF9A825); // jaune
  return const Color(0xFFD32F2F); // rouge
}

/// Libellé sous la ligne de force.
String forceLibelle(int score) {
  if (score >= 4) return 'Excellent';
  if (score == 3) return 'Bon';
  if (score == 2) return 'Moyen';
  if (score == 1) return 'Faible';
  return 'Très faible';
}
