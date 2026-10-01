import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../theme/medigo_theme.dart';
import 'ui_kit.dart';

/// Carte cliquable représentant un patient dans une liste.
/// Même vocabulaire visuel que RendezVousCard (CarteMedigo : blanc,
/// coins arrondis, ombre douce, survol sur web) — et, comme le reste
/// de l'application, AUCUNE icône ni chevron.
class PatientCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback? onTap;

  const PatientCard({super.key, required this.patient, this.onTap});

  @override
  Widget build(BuildContext context) {
    return CarteMedigo(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          // Avatar à initiales (turquoise dilué à 12 % — pas de photo).
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.turquoise.withValues(alpha: 0.12),
            child: Text(
              // "[0]" prend le premier caractère du prénom,
              // ".toUpperCase()" le met en majuscule, ex: "s" → "S".
              patient.prenom.isNotEmpty
                  ? patient.prenom[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: AppColors.turquoise,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.nomComplet,
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
                  patient.telephone,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.texteFaible,
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
