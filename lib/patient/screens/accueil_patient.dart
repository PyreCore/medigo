import 'package:flutter/material.dart';
import '../../models/patient.dart';
import '../../models/rendez_vous.dart';
import '../../widgets/rendez_vous_card.dart';

/// Contenu de l'onglet "Accueil" de l'espace Patient.
/// Affiche un résumé (statistiques) + les rendez-vous du jour.
/// Même construction que AccueilMedecin, les chiffres portant sur le
/// patient plutôt que sur sa patientèle.
class AccueilPatient extends StatelessWidget {
  final Patient patient;
  final List<RendezVous> rendezVousDuJour;
  final Map<String, int> statistiques;

  // Callbacks : cet écran ne navigue pas tout seul, il appelle ces
  // fonctions et laisse le parent (EspacePatient) décider quoi faire.
  final VoidCallback onVoirTout; // bouton "Voir tout" → onglet 1
  final VoidCallback onPrendreRendezVous; // bouton d'appel à l'action → onglet 2
  final ValueChanged<RendezVous> onTapRendezVous;
  final Future<void> Function()? onRafraichir;

  const AccueilPatient({
    super.key,
    required this.patient,
    required this.rendezVousDuJour,
    required this.onVoirTout,
    required this.onPrendreRendezVous,
    required this.onTapRendezVous,
    this.statistiques = const {},
    this.onRafraichir,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Le prochain rendez-vous utile est le plus proche encore à venir
    // (en attente ou confirmé). On le met en avant : c'est l'info que le
    // patient cherche en ouvrant l'application.
    final maintenant = DateTime.now();
    final prochains = rendezVousDuJour
        .where(
          (r) =>
              !r.date.isBefore(maintenant) &&
              r.statut != StatutRendezVous.annule &&
              r.statut != StatutRendezVous.refuse,
        )
        .toList();

    return RefreshIndicator(
      onRefresh: onRafraichir ?? () async {},
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _EnTetePatient(patient: patient),
          const SizedBox(height: 20),
          _StatistiquesRow(
            rdvAujourdhui: statistiques['rdvAujourdhui'] ?? 0,
            enAttente: statistiques['enAttente'] ?? 0,
            aVenir: statistiques['aVenir'] ?? 0,
          ),
          const SizedBox(height: 16),
          // Appel à l'action : c'est la fonction première de l'espace
          // patient, on lui laisse donc une carte entière plutôt qu'un
          // bouton discret.
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Prendre rendez-vous'),
              onPressed: onPrendreRendezVous,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Aujourd\'hui',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(onPressed: onVoirTout, child: const Text('Voir tout')),
            ],
          ),
          const SizedBox(height: 8),
          if (prochains.isEmpty)
            const _AucunRendezVous()
          else
            ...prochains.map(
              (rdv) => RendezVousCard(
                rdv: rdv,
                // Côté patient, c'est le médecin qui intéresse (pas son
                // propre nom), d'où afficherPatient: false.
                afficherPatient: false,
                onTap: () => onTapRendezVous(rdv),
              ),
            ),
        ],
      ),
    );
  }
}

// En-tête coloré avec initiales + nom + hôpital du patient.
class _EnTetePatient extends StatelessWidget {
  final Patient patient;
  const _EnTetePatient({required this.patient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32), // vert, couleur du PatientCard
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            // Getter du modèle : première lettre du prénom (ou du nom).
            child: Text(
              patient.initiale,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pas d'hôpital sous le nom : le patient en choisit un à
                // chaque rendez-vous, l'en-tête reste donc au seul nom.
                Text(
                  patient.nomComplet,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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

// Les 3 cartes de statistiques du patient.
class _StatistiquesRow extends StatelessWidget {
  final int rdvAujourdhui;
  final int enAttente;
  final int aVenir;

  const _StatistiquesRow({
    required this.rdvAujourdhui,
    required this.enAttente,
    required this.aVenir,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Chaque carte est enveloppée dans "Expanded" pour que les 3
        // cartes se partagent équitablement la largeur disponible.
        Expanded(
          child: _StatCard(
            label: 'RDV aujourd\'hui',
            valeur: rdvAujourdhui.toString(),
            couleur: const Color(0xFF2E6F6E),
            icone: Icons.calendar_today,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'En attente',
            valeur: enAttente.toString(),
            couleur: const Color(0xFFD98E04),
            icone: Icons.hourglass_bottom,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'À venir',
            valeur: aVenir.toString(),
            couleur: const Color(0xFF2E7D32),
            icone: Icons.event_available,
          ),
        ),
      ],
    );
  }
}

// Une carte de statistique individuelle (réutilisée 3 fois ci-dessus).
class _StatCard extends StatelessWidget {
  final String label;
  final String valeur;
  final Color couleur;
  final IconData icone;

  const _StatCard({
    required this.label,
    required this.valeur,
    required this.couleur,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: couleur.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: couleur, size: 20),
          const SizedBox(height: 8),
          Text(
            valeur,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: couleur,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

// Message affiché quand aucun rendez-vous à venir aujourd'hui.
class _AucunRendezVous extends StatelessWidget {
  const _AucunRendezVous();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.event_available, size: 40, color: Colors.black26),
          SizedBox(height: 8),
          Text(
            'Aucun rendez-vous aujourd\'hui',
            style: TextStyle(color: Colors.black45),
          ),
        ],
      ),
    );
  }
}
