import 'package:flutter/material.dart';
import '../../services/secretaire_service.dart';
import '../../theme/medigo_theme.dart';
import '../../widgets/ui_kit.dart';

/// Écran de refus d'un rendez-vous : la secrétaire choisit un motif
/// parmi une liste prédéfinie (ou saisit un motif personnalisé),
/// puis confirme le refus.
///
/// Le refus est définitif : le rendez-vous passe au statut "refusé"
/// et le créneau est libéré (l'heure redevient disponible en ligne).
class RefuserRendezVousSecretaire extends StatefulWidget {
  final String rdvId;
  final Future<void> Function(String rdvId, {String? motif}) onRefuser;

  const RefuserRendezVousSecretaire({
    super.key,
    required this.rdvId,
    required this.onRefuser,
  });

  @override
  State<RefuserRendezVousSecretaire> createState() =>
      _RefuserRendezVousSecretaireState();
}

class _RefuserRendezVousSecretaireState
    extends State<RefuserRendezVousSecretaire> {
  // Index du motif sélectionné dans la liste prédéfinie.
  // null = rien encore sélectionné.
  int? _motifSelectionne;

  // Contrôleur pour le champ "Autre motif" (saisie libre).
  final _controleurMotif = TextEditingController();

  // Vrai pendant l'appel à Firestore (évite le double-clic).
  bool _envoiEnCours = false;

  @override
  void dispose() {
    _controleurMotif.dispose();
    super.dispose();
  }

  /// Le bouton "Refuser" n'est actif que si un motif est choisi
  /// (et, pour "Autre motif", si le champ n'est pas vide).
  bool get _peutRefuser {
    if (_motifSelectionne == null) return false;
    // Dernier élément = "Autre motif" : exige une saisie.
    if (_motifSelectionne == SecretaireService.motifsRefus.length - 1) {
      return _controleurMotif.text.trim().isNotEmpty;
    }
    return true;
  }

  Future<void> _confirmerRefus() async {
    if (!_peutRefuser || _envoiEnCours) return;

    setState(() => _envoiEnCours = true);

    // Si "Autre motif" est sélectionné, on utilise la saisie libre.
    // Sinon, on utilise le texte du motif prédéfini choisi.
    final motif = _motifSelectionne ==
            SecretaireService.motifsRefus.length - 1
        ? _controleurMotif.text.trim()
        : SecretaireService.motifsRefus[_motifSelectionne!];

    await widget.onRefuser(widget.rdvId, motif: motif);

    if (mounted) {
      // Retour à l'écran précédent (détail du RDV) après le refus.
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Refuser le rendez-vous')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // En-tête explicatif : pourquoi cet écran existe.
          const Text(
            'Choisissez le motif du refus. Il sera visible par le patient '
            'et le médecin concerné.',
            style: TextStyle(fontSize: 14, color: AppColors.texteFaible),
          ),
          const SizedBox(height: 20),

          // Liste des motifs prédéfinis : chaque élément est une ligne
          // cliquable avec une case à cocher circulaire (Radio).
          for (var i = 0; i < SecretaireService.motifsRefus.length; i++)
            _ligneMotif(i),

          const SizedBox(height: 24),

          // Bouton de confirmation : rouge (action destructive).
          BoutonPrincipal(
            texte: 'Confirmer le refus',
            couleur: AppColors.rouge,
            onPressed: _peutRefuser ? _confirmerRefus : null,
          ),
        ],
      ),
    );
  }

  /// Une ligne de la liste : radio + texte du motif.
  /// Si c'est "Autre motif", ajoute un champ de saisie en dessous.
  Widget _ligneMotif(int index) {
    final estSelectionne = _motifSelectionne == index;
    final estAutre = index == SecretaireService.motifsRefus.length - 1;

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _motifSelectionne = index),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Radio : cercle vide ou plein selon la sélection.
                Icon(
                  estSelectionne
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: estSelectionne
                      ? AppColors.rouge
                      : AppColors.texteFaible,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    SecretaireService.motifsRefus[index],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: estSelectionne
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: AppColors.texte,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Champ de saisie visible uniquement pour "Autre motif".
        if (estAutre && estSelectionne)
          Padding(
            padding: const EdgeInsets.only(left: 36, bottom: 8),
            child: TextField(
              controller: _controleurMotif,
              decoration: const InputDecoration(
                labelText: 'Précisez le motif',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (_) => setState(() {}),
            ),
          ),
      ],
    );
  }
}
