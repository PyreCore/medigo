import 'package:flutter/material.dart';
import '../../models/patient.dart';

/// Onglet "Profil" : infos du patient connecté + déconnexion.
/// Même construction que ProfilMedecin, enrichie des données que le
/// patient seul connaît (email, date de naissance, groupe sanguin).
class ProfilPatient extends StatelessWidget {
  final Patient patient;

  // Callback optionnel appelé quand on appuie sur "Se déconnecter".
  // Optionnel car Firebase Auth n'est pas toujours branché en maquette.
  final VoidCallback? onDeconnexion;

  const ProfilPatient({super.key, required this.patient, this.onDeconnexion});

  @override
  Widget build(BuildContext context) {
    final initiales = patient.initiale;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: const Color(0xFF2E7D32),
            child: Text(
              initiales,
              style: const TextStyle(fontSize: 32, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            patient.nomComplet,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 24),
        const Divider(height: 1),
        const SizedBox(height: 8),
        // Pas de ligne « Hôpital » : le patient n'est rattaché à aucun
        // établissement, il en choisit un à chaque rendez-vous.
        if (patient.email.isNotEmpty) ...[
          _LigneProfil(icone: Icons.email, texte: patient.email),
          const Divider(height: 1),
        ],
        if (patient.telephone.isNotEmpty) ...[
          _LigneProfil(icone: Icons.phone, texte: patient.telephone),
          const Divider(height: 1),
        ],
        if (patient.dateNaissance != null) ...[
          _LigneProfil(
            icone: Icons.cake_outlined,
            texte:
                'Né(e) le ${patient.dateNaissance!.day}/${patient.dateNaissance!.month}/${patient.dateNaissance!.year}',
          ),
          const Divider(height: 1),
        ],
        if (patient.groupeSanguin != null) ...[
          _LigneProfil(
            icone: Icons.bloodtype_outlined,
            texte: 'Groupe sanguin : ${patient.groupeSanguin}',
          ),
          const Divider(height: 1),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFC62828),
            side: const BorderSide(color: Color(0xFFC62828)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.logout),
          label: const Text('Se déconnecter'),
          // Si onDeconnexion est null, le bouton est automatiquement
          // désactivé (grisé) car Flutter désactive tout bouton dont
          // onPressed vaut null.
          onPressed: onDeconnexion,
        ),
      ],
    );
  }
}

// Ligne "icône + texte" du profil.
class _LigneProfil extends StatelessWidget {
  final IconData icone;
  final String texte;
  const _LigneProfil({required this.icone, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icone, color: Colors.black45, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(texte)),
        ],
      ),
    );
  }
}
