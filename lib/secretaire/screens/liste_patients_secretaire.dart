import 'package:flutter/material.dart';
import '../../models/patient.dart';
import '../../widgets/patient_card.dart';

/// Onglet "Patients" : liste de tous les patients de l'hôpital, avec
/// un bouton flottant pour en enregistrer un nouveau.
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
              return PatientCard(patient: patient);
            },
          ),

        // Positionné en bas à droite grâce à Positioned (utilisable
        // seulement à l'intérieur d'un Stack).
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: onNouveauPatient,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}
