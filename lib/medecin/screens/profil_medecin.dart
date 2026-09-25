import 'package:flutter/material.dart';
import '../../models/medecin.dart';

/// Onglet "Profil" : infos du médecin connecté + déconnexion.
class ProfilMedecin extends StatelessWidget {
  final Medecin medecin;
  // Callback optionnel appelé quand on appuie sur "Se déconnecter".
  // Optionnel pour l'instant car Firebase Auth n'est pas encore branché.
  final VoidCallback? onDeconnexion;

  const ProfilMedecin({super.key, required this.medecin, this.onDeconnexion});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // "Center" force son enfant à se placer au centre horizontalement,
        // utile ici car CircleAvatar seul s'alignerait à gauche dans une
        // ListView (qui empile normalement les widgets sans les centrer).
        Center(
          child: CircleAvatar(
            radius: 44, // avatar plus grand que sur les autres écrans
            backgroundColor: const Color(0xFF2E6F6E),
            backgroundImage:
                medecin.photoUrl != null ? NetworkImage(medecin.photoUrl!) : null,
            child: medecin.photoUrl == null
                ? Text(
                    medecin.prenom.isNotEmpty ? medecin.prenom[0] : '?',
                    style: const TextStyle(fontSize: 32, color: Colors.white),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            medecin.nomComplet,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Center(
          child: Text(
            medecin.specialite,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
        const SizedBox(height: 24),
        // Ligne "icône hôpital + nom de l'hôpital" (widget privé plus bas).
        _LigneProfil(icone: Icons.local_hospital, texte: medecin.hopitalNom),
        // Divider = simple ligne horizontale de séparation.
        const Divider(height: 1),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFC62828), // rouge, pour signaler une action "de sortie"
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

// Widget privé pour une ligne "icône + texte" du profil (réutilisable
// si on ajoute d'autres infos plus tard : téléphone, email...).
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
