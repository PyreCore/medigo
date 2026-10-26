import 'package:flutter/material.dart';

import '../../widgets/profil_admin.dart';

/// Ancien onglet Profil de l'admin hôpital, conservé pour compatibilité.
/// L'interface complète (photo, modification des coordonnées, déconnexion)
/// vit désormais dans le widget partagé [ProfilAdmin], commun aux deux
/// espaces administrateur.
class ProfilAdminHopital extends StatelessWidget {
  const ProfilAdminHopital({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfilAdmin(sousTitre: 'Administrateur hôpital');
  }
}
