import 'package:flutter/material.dart';
import '../../models/rendez_vous.dart';
import '../../widgets/rendez_vous_card.dart';

/// Onglet "Mes rendez-vous" : liste complète des rendez-vous du patient,
/// avec filtre par statut. Même construction que ListeRendezVousMedecin,
/// mais la carte affiche le MÉDECIN (le patient connaît déjà son nom).
class ListeRendezVousPatient extends StatefulWidget {
  final List<RendezVous> rendezVous;
  final ValueChanged<RendezVous> onTapRendezVous;

  // Appelé quand on tape le bouton flottant en bas à droite : bascule
  // vers l'onglet "Prendre rendez-vous" (voir EspacePatient).
  final VoidCallback onNouveauRendezVous;

  const ListeRendezVousPatient({
    super.key,
    required this.rendezVous,
    required this.onTapRendezVous,
    required this.onNouveauRendezVous,
  });

  @override
  State<ListeRendezVousPatient> createState() =>
      _ListeRendezVousPatientState();
}

class _ListeRendezVousPatientState extends State<ListeRendezVousPatient> {
  // Filtre actuellement sélectionné. null = pas de filtre = tous statuts.
  StatutRendezVous? _filtre;

  @override
  Widget build(BuildContext context) {
    final rdvFiltres = _filtre == null
        ? widget.rendezVous
        : widget.rendezVous.where((r) => r.statut == _filtre).toList();

    return Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: [
              _ChipFiltre(
                label: 'Tous',
                selectionne: _filtre == null,
                onTap: () => setState(() => _filtre = null),
              ),
              ...StatutRendezVous.values.map(
                (s) => _ChipFiltre(
                  label: libelleStatutRdv(s),
                  selectionne: _filtre == s,
                  onTap: () => setState(() => _filtre = s),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: rdvFiltres.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun rendez-vous dans cette catégorie',
                    style: TextStyle(color: Colors.black45),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rdvFiltres.length,
                  itemBuilder: (context, index) {
                    final rdv = rdvFiltres[index];
                    return RendezVousCard(
                      rdv: rdv,
                      // Le titre de la carte devient le nom du médecin.
                      afficherPatient: false,
                      onTap: () => widget.onTapRendezVous(rdv),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// Bouton de filtre (ex: "Confirmé", "En attente", "Annulé"...).
class _ChipFiltre extends StatelessWidget {
  final String label;
  final bool selectionne;
  final VoidCallback onTap;

  const _ChipFiltre({
    required this.label,
    required this.selectionne,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selectionne,
        onSelected: (_) => onTap(),
        // Vert : couleur de l'espace patient (cf. PatientCard, AccueilPatient).
        selectedColor: const Color(0xFF2E7D32),
        labelStyle: TextStyle(
          color: selectionne ? Colors.white : Colors.black87,
          fontSize: 12,
        ),
        backgroundColor: Colors.white,
      ),
    );
  }
}
