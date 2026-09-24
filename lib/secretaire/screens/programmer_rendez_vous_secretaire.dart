import 'package:flutter/material.dart';
import '../../models/patient.dart';
import '../../models/medecin.dart';

/// Écran formulaire pour programmer un rendez-vous : la secrétaire
/// choisit un patient déjà enregistré, un médecin de l'hôpital, une
/// date/heure, et un motif optionnel.
class ProgrammerRendezVousSecretaire extends StatefulWidget {
  final List<Patient> patients; // patients parmi lesquels choisir
  final List<Medecin> medecins; // médecins de l'hôpital parmi lesquels choisir

  // Fonction appelée à la validation, avec toutes les infos saisies.
  final void Function({
    required Patient patient,
    required Medecin medecin,
    required DateTime date,
    required String heure,
    String? motif,
  }) onValider;

  const ProgrammerRendezVousSecretaire({
    super.key,
    required this.patients,
    required this.medecins,
    required this.onValider,
  });

  @override
  State<ProgrammerRendezVousSecretaire> createState() =>
      _ProgrammerRendezVousSecretaireState();
}

class _ProgrammerRendezVousSecretaireState
    extends State<ProgrammerRendezVousSecretaire> {
  // Ces variables retiennent les choix de l'utilisateur au fur et à
  // mesure. Elles sont nullable car au départ, rien n'est encore choisi.
  Patient? _patientChoisi;
  Medecin? _medecinChoisi;
  DateTime? _dateChoisie;
  TimeOfDay? _heureChoisie; // TimeOfDay = heure/minute, sans date associée

  final _controllerMotif = TextEditingController();

  @override
  void dispose() {
    _controllerMotif.dispose();
    super.dispose();
  }

  // Ouvre le sélecteur de date natif de Flutter/du téléphone.
  Future<void> _choisirDate() async {
    // showDatePicker() est une fonction ASYNCHRONE fournie par Flutter :
    // elle affiche un calendrier et attend que l'utilisateur choisisse
    // une date (ou "await" reçoit "null" si l'utilisateur annule).
    final resultat = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(), // pas de RDV dans le passé
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    // "resultat != null" : on ne met à jour l'état que si l'utilisateur
    // a vraiment choisi une date (pas annulé la boîte de dialogue).
    if (resultat != null) {
      setState(() {
        _dateChoisie = resultat;
      });
    }
  }

  // Ouvre le sélecteur d'heure natif.
  Future<void> _choisirHeure() async {
    final resultat = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (resultat != null) {
      setState(() {
        _heureChoisie = resultat;
      });
    }
  }

  void _valider() {
    // On vérifie que tous les champs obligatoires ont bien une valeur
    // avant de continuer.
    if (_patientChoisi == null ||
        _medecinChoisi == null ||
        _dateChoisie == null ||
        _heureChoisie == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merci de compléter tous les champs')),
      );
      return;
    }

    // ".padLeft(2, '0')" ajoute un zéro devant si besoin, ex: 9 -> "09",
    // pour afficher "09:05" plutôt que "9:5".
    final heureTexte =
        '${_heureChoisie!.hour.toString().padLeft(2, '0')}:${_heureChoisie!.minute.toString().padLeft(2, '0')}';

    widget.onValider(
      patient: _patientChoisi!,
      medecin: _medecinChoisi!,
      date: _dateChoisie!,
      heure: heureTexte,
      motif: _controllerMotif.text.trim().isEmpty
          ? null
          : _controllerMotif.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau rendez-vous')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // DropdownButtonFormField : liste déroulante avec le style
          // d'un champ de formulaire classique.
          DropdownButtonFormField<Patient>(
            value: _patientChoisi,
            decoration: const InputDecoration(
              labelText: 'Patient',
              border: OutlineInputBorder(),
            ),
            // .map() transforme chaque Patient en une "option" affichable
            // dans la liste déroulante (DropdownMenuItem).
            items: widget.patients
                .map(
                  (p) => DropdownMenuItem(value: p, child: Text(p.nomComplet)),
                )
                .toList(),
            // Appelé quand l'utilisateur choisit une option.
            onChanged: (valeur) => setState(() => _patientChoisi = valeur),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Medecin>(
            value: _medecinChoisi,
            decoration: const InputDecoration(
              labelText: 'Médecin',
              border: OutlineInputBorder(),
            ),
            items: widget.medecins
                .map(
                  (m) => DropdownMenuItem(
                    value: m,
                    // nomComplet + specialite pour aider la secrétaire à
                    // distinguer deux médecins du même nom rapidement.
                    child: Text('${m.nomComplet} — ${m.specialite}'),
                  ),
                )
                .toList(),
            onChanged: (valeur) => setState(() => _medecinChoisi = valeur),
          ),
          const SizedBox(height: 12),

          // ListTile pratique pour un champ "cliquable" qui ouvre une
          // boîte de dialogue (ici, le sélecteur de date).
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: Text(
              _dateChoisie == null
                  ? 'Choisir une date'
                  : '${_dateChoisie!.day}/${_dateChoisie!.month}/${_dateChoisie!.year}',
            ),
            onTap: _choisirDate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time),
            title: Text(
              _heureChoisie == null
                  ? 'Choisir une heure'
                  : _heureChoisie!.format(context),
            ),
            onTap: _choisirHeure,
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _controllerMotif,
            decoration: const InputDecoration(
              labelText: 'Motif (optionnel)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _valider,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Programmer le rendez-vous'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
