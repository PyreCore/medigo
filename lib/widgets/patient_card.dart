import 'package:flutter/material.dart';
import '../models/patient.dart';

/// Carte cliquable représentant un patient dans une liste.
/// Même structure visuelle que RendezVousCard, pour rester cohérent
/// avec le reste de l'application.
class PatientCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback? onTap;

  const PatientCard({super.key, required this.patient, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            // Petit avatar circulaire avec l'initiale du prénom, en
            // attendant d'avoir de vraies photos de patients.
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF1E88E5).withOpacity(0.12),
              child: Text(
                // "[0]" prend le premier caractère du prénom.
                // ".toUpperCase()" le met en majuscule, ex: "s" -> "S".
                patient.prenom.isNotEmpty
                    ? patient.prenom[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Color(0xFF1E88E5),
                  fontWeight: FontWeight.bold,
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
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    patient.telephone,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26, size: 20),
          ],
        ),
      ),
    );
  }
}
