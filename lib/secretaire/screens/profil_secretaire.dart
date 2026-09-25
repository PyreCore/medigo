import 'package:flutter/material.dart';
import '../../models/secretaire.dart';

/// Onglet "Profil" : infos de la secrétaire connectée + déconnexion.
/// Même structure que ProfilMedecin, pour rester cohérent visuellement.
class ProfilSecretaire extends StatelessWidget {
  final Secretaire secretaire;
  final VoidCallback? onDeconnexion;

  const ProfilSecretaire({
    super.key,
    required this.secretaire,
    this.onDeconnexion,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: const Color(0xFF1E88E5),
            backgroundImage: secretaire.photoUrl != null
                ? NetworkImage(secretaire.photoUrl!)
                : null,
            child: secretaire.photoUrl == null
                ? Text(
                    secretaire.prenom.isNotEmpty ? secretaire.prenom[0] : '?',
                    style: const TextStyle(fontSize: 32, color: Colors.white),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            secretaire.nomComplet,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Center(
          child: Text(
            'Secrétaire médicale',
            style: const TextStyle(color: Colors.black54),
          ),
        ),
        const SizedBox(height: 24),
        _LigneProfil(icone: Icons.local_hospital, texte: secretaire.hopitalNom),
        const Divider(height: 1),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFC62828),
            side: const BorderSide(color: Color(0xFFC62828)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.logout),
          label: const Text('Se déconnecter'),
          onPressed: onDeconnexion,
        ),
      ],
    );
  }
}

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
