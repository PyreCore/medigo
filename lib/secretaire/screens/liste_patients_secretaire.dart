import 'package:flutter/material.dart';
import '../../models/patient.dart';
import '../../theme/medigo_theme.dart';
import '../../widgets/maquette_widgets.dart'; // LigneFiletSpec (filet)

/// Onglet "Patients" : liste de tous les patients de l'hôpital, avec
/// un bouton flottant pour en enregistrer un nouveau.
///
/// Style « filet » (point 4) : les lignes sont collées les unes aux
/// autres et séparées par un trait 1 px (LigneFiletSpec) au lieu d'une
/// carte individuelle par patient — contenu identique à PatientCard
/// (avatar à initiale, nom, téléphone).
class ListePatientsSecretaire extends StatelessWidget {
  final List<Patient> patients;

  // Fonction appelée quand on appuie sur le bouton "+" pour enregistrer
  // un nouveau patient.
  final VoidCallback onNouveauPatient;

  const ListePatientsSecretaire({
    super.key,
    required this.patients,
    required this.onNouveauPatient,
  });

  /// Ligne de patient en style « filet » : avatar à initiale (vert,
  /// comme l'espace patient), nom complet, téléphone.
  static Widget _lignePatient(
    Patient patient, {
    required bool premiere,
    required bool derniere,
  }) {
    return LigneFiletSpec(
      padding: const EdgeInsets.all(14),
      premiere: premiere,
      derniere: derniere,
      child: Row(
        children: [
          // Petit avatar circulaire avec l'initiale du prénom, en
          // attendant d'avoir de vraies photos de patients.
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.12),
            child: Text(
              // "[0]" prend le premier caractère du prénom.
              // ".toUpperCase()" le met en majuscule, ex: "s" -> "S".
              patient.prenom.isNotEmpty
                  ? patient.prenom[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Color(0xFF2E7D32),
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

  @override
  Widget build(BuildContext context) {
    // "Stack" superpose des widgets les uns sur les autres (contrairement
    // à Row/Column qui les alignent côte à côte). Ici, ça nous sert à
    // poser le bouton "+" par-dessus la liste, en bas à droite.
    return Stack(
      children: [
        if (patients.isEmpty)
          const Center(
            child: Text(
              'Aucun patient enregistré pour le moment.',
              style: TextStyle(color: Colors.black45),
            ),
          )
        else
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            // itemCount indique à Flutter combien d'éléments afficher.
            itemCount: patients.length,
            // itemBuilder est appelé pour CHAQUE élément de la liste,
            // avec son index (0, 1, 2...), et doit retourner le widget
            // correspondant. Contrairement à ListView(children: [...]),
            // ListView.builder ne construit que les éléments visibles
            // à l'écran, ce qui est plus performant sur de longues listes.
            itemBuilder: (context, index) {
              final patient = patients[index];
              // Lignes réglées : rayons sur la 1ʳᵉ / dernière ligne.
              return _lignePatient(
                patient,
                premiere: index == 0,
                derniere: index == patients.length - 1,
              );
            },
          ),

        // Positionné en bas à droite grâce à Positioned (utilisable
        // seulement à l'intérieur d'un Stack).
        Positioned(
          bottom: 16,
          right: 16,
          // Bouton étendu : libellé texte seul (pas d'icône "+").
          child: FloatingActionButton.extended(
            onPressed: onNouveauPatient,
            backgroundColor: const Color(0xFF0B57D0), // bleuMedical
            foregroundColor: Colors.white,
            label: const Text('Nouveau patient'),
          ),
        ),
      ],
    );
  }
}
