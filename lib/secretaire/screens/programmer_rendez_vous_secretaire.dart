import 'package:flutter/material.dart';
import '../../models/patient.dart';
import '../../models/medecin.dart';
import '../../theme/maquette_tokens.dart';
import '../../widgets/maquette_widgets.dart'; // BoutonDegradeSpec (chargement)

// ─────────────────────────────────────────────────────────────────────
// FORMULAIRE « NOUVEAU RENDEZ-VOUS » (SECRÉTAIRE) — maquette § formulaires.
//
//  · validation EN DIRECT : message rouge sous chaque choix manquant
//    (patient, médecin, date, heure) dès qu'il a été touché ; motif
//    optionnel sans obligation ;
//  · bouton DÉSACTIVÉ (gris) tant que le formulaire est incomplet,
//    puis spinner pendant l'envoi (sélecteurs verrouillés) ;
//  · bordure de focus bleu maquette #2458D3 (1,6 px) sur les listes
//    déroulantes et le champ motif ;
//  · claviers adaptés : motif multi-lignes, « Terminé » lance la
//    validation ;
//  · entrée des champs en fondu + glissement (stagger 650 ms) ;
//  · succès ANIMÉ (« Rendez-vous programmé ») puis retour auto.
//
// LOGIQUE INCHANGÉE : mêmes sélecteurs natifs (date/heure), même règle
// d'obligation, même formatage « HH:mm » (padLeft 2), même chemin
// d'enregistrement (onValider → EspaceSecretaire → chargeur →
// SecretaireService). onValider est désormais Future<void> : le
// formulaire attend l'écriture Firestore avant son succès, et se
// ferme lui-même (l'ancien pop immédiat du parent supprimé).
// ─────────────────────────────────────────────────────────────────────
class ProgrammerRendezVousSecretaire extends StatefulWidget {
  final List<Patient> patients; // patients parmi lesquels choisir
  final List<Medecin> medecins; // médecins de l'hôpital parmi lesquels choisir

  // Fonction appelée à la validation, avec toutes les infos saisies.
  // ASYNCHRONE : le formulaire attend la fin de l'enregistrement.
  final Future<void> Function({
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
    extends State<ProgrammerRendezVousSecretaire>
    with SingleTickerProviderStateMixin {
  // Ces variables retiennent les choix de l'utilisateur au fur et à
  // mesure. Elles sont nullable car au départ, rien n'est encore choisi.
  Patient? _patientChoisi;
  Medecin? _medecinChoisi;
  DateTime? _dateChoisie;
  TimeOfDay? _heureChoisie; // TimeOfDay = heure/minute, sans date associée

  final _controllerMotif = TextEditingController();

  // Animation d'ENTRÉE (fondu + glissement, décalage par champ).
  late final AnimationController _entree = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  // Choix déjà « touchés » par l'utilisateur (le sélecteur a été
  // ouvert au moins une fois) : la validation live n'affiche l'erreur
  // QUE sur un choix touché, pas au premier rendu.
  final _touche = <String>{};

  bool _envoiEnCours = false; // état de chargement (écriture Firestore)
  bool _succes = false; // animation de succès affichée

  @override
  void dispose() {
    _controllerMotif.dispose();
    _entree.dispose();
    super.dispose();
  }

  /// Le formulaire est complet ? (identique à l'ancienne règle :
  /// patient + médecin + date + heure obligatoires, motif optionnel).
  bool get _formulaireValide =>
      _patientChoisi != null &&
      _medecinChoisi != null &&
      _dateChoisie != null &&
      _heureChoisie != null;

  /// Message d'erreur live : seulement si le choix a été touché ET
  /// qu'il est encore vide.
  String? _erreurCase(String champ) {
    bool choisi;
    switch (champ) {
      case 'patient':
        choisi = _patientChoisi != null;
        break;
      case 'medecin':
        choisi = _medecinChoisi != null;
        break;
      case 'date':
        choisi = _dateChoisie != null;
        break;
      default:
        choisi = _heureChoisie != null;
    }
    if (choisi || !_touche.contains(champ)) return null;
    switch (champ) {
      case 'patient':
        return 'Patient obligatoire';
      case 'medecin':
        return 'Médecin obligatoire';
      case 'date':
        return 'Date obligatoire';
      default:
        return 'Heure obligatoire';
    }
  }

  // Ouvre le sélecteur de date natif de Flutter/du téléphone.
  Future<void> _choisirDate() async {
    setState(() => _touche.add('date'));
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
    if (resultat != null && mounted) {
      setState(() {
        _dateChoisie = resultat;
      });
    }
  }

  // Ouvre le sélecteur d'heure natif.
  Future<void> _choisirHeure() async {
    setState(() => _touche.add('heure'));
    final resultat = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (resultat != null && mounted) {
      setState(() {
        _heureChoisie = resultat;
      });
    }
  }

  Future<void> _valider() async {
    // Garde anti-double-tap pendant l'envoi / après le succès.
    if (_envoiEnCours || _succes) return;

    // Le bouton est désactivé si le formulaire est incomplet, mais
    // « Terminé » sur le champ motif peut contourner ce parcours :
    // on affiche alors toutes les erreurs.
    setState(() {
      _touche.addAll(const ['patient', 'medecin', 'date', 'heure']);
    });
    if (!_formulaireValide) return;

    setState(() => _envoiEnCours = true);
    try {
      // ".padLeft(2, '0')" ajoute un zéro devant si besoin, ex: 9 -> "09",
      // pour afficher "09:05" plutôt que "9:5".
      final heureTexte =
          '${_heureChoisie!.hour.toString().padLeft(2, '0')}:'
          '${_heureChoisie!.minute.toString().padLeft(2, '0')}';

      // On ATTEND réellement l'écriture Firestore (chaîne onValider →
      // chargeur → SecretaireService).
      await widget.onValider(
        patient: _patientChoisi!,
        medecin: _medecinChoisi!,
        date: _dateChoisie!,
        heure: heureTexte,
        motif: _controllerMotif.text.trim().isEmpty
            ? null
            : _controllerMotif.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _envoiEnCours = false;
        _succes = true;
      });
      // Succès animé visible, puis retour automatique à la liste.
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // Échec (règles Firestore, créneau déjà pris…) : on rouvre le
      // formulaire.
      if (!mounted) return;
      setState(() => _envoiEnCours = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Programmation impossible : $e')),
      );
    }
  }

  // Enveloppe animée : fondu + glissement vers le haut, avec un
  // décalage progressif par champ (stagger).
  Widget _anime(int index, Widget enfant) {
    final interval = Interval(
      0.11 * index,
      // Borné à 1 : Interval exige end <= 1 (index max du formulaire).
      (0.11 * index + 0.5).clamp(0.0, 1.0).toDouble(),
      curve: Curves.easeOutCubic,
    );
    final anim = _entree.drive(CurveTween(curve: interval));
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(anim),
        child: enfant,
      ),
    );
  }

  InputDecoration _decoration(String label, {String? erreur}) {
    const rayon = BorderRadius.all(Radius.circular(12));
    return InputDecoration(
      labelText: label,
      errorText: erreur,
      errorStyle: const TextStyle(
        fontSize: 12,
        color: MaquetteCouleurs.refuseTexte,
      ),
      labelStyle: const TextStyle(
        fontSize: 14,
        color: MaquetteCouleurs.texteSecondaire,
      ),
      filled: true,
      fillColor: MaquetteCouleurs.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: const OutlineInputBorder(
        borderRadius: rayon,
        borderSide: BorderSide(color: MaquetteCouleurs.bordure),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: rayon,
        borderSide: BorderSide(color: MaquetteCouleurs.bordure),
      ),
      // Focus maquette : bleu #2458D3, 1,6 px (MaquetteCouleurs.bleu).
      focusedBorder: const OutlineInputBorder(
        borderRadius: rayon,
        borderSide: BorderSide(color: MaquetteCouleurs.bleu, width: 1.6),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: rayon,
        borderSide: BorderSide(color: MaquetteCouleurs.refuseTexte),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: rayon,
        borderSide: BorderSide(color: MaquetteCouleurs.refuseTexte, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MaquetteCouleurs.fond,
      appBar: AppBar(title: const Text('Nouveau rendez-vous')),
      // Après succès : l'écran de confirmation animé remplace le formulaire.
      body: _succes ? _vueSucces() : _formulaire(),
    );
  }

  Widget _formulaire() {
    // Champs verrouillés pendant l'envoi (pas de modification en cours
    // d'écriture Firestore).
    final verrouille = _envoiEnCours;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _anime(
          0,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // DropdownButtonFormField : liste déroulante avec le style
              // d'un champ de formulaire classique.
              DropdownButtonFormField<Patient>(
                // initialValue remplace l'ancien value (déprécié) : c'est la
                // valeur affichée QUAND LE CHAMP EST CRÉÉ.
                initialValue: _patientChoisi,
                // Verrouillage pendant l'envoi : onChanged null = champ
                // désactivé nativement (DropdownButtonFormField n'a pas
                // de paramètre enabled).
                onChanged: verrouille
                    ? null
                    : (valeur) => setState(() => _patientChoisi = valeur),
                // Le simple fait d'ouvrir la liste "touche" le champ :
                // son message d'erreur live peut s'afficher ensuite.
                onTap: () => setState(() => _touche.add('patient')),
                decoration: _decoration(
                  'Patient',
                  erreur: _erreurCase('patient'),
                ),
                // .map() transforme chaque Patient en une "option" affichable
                // dans la liste déroulante (DropdownMenuItem).
                items: widget.patients
                    .map(
                      (p) =>
                          DropdownMenuItem(value: p, child: Text(p.nomComplet)),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _anime(
          1,
          DropdownButtonFormField<Medecin>(
            // Même principe que le champ Patient ci-dessus.
            initialValue: _medecinChoisi,
            // Verrouillage pendant l'envoi (onChanged null = désactivé).
            onChanged: verrouille
                ? null
                : (valeur) => setState(() => _medecinChoisi = valeur),
            onTap: () => setState(() => _touche.add('medecin')),
            decoration: _decoration(
              'Médecin',
              erreur: _erreurCase('medecin'),
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
          ),
        ),
        const SizedBox(height: 12),

        // Case « cliquable » qui ouvre une boîte de dialogue (sélecteur
        // de date) — style champ maquette, erreur live sous la case.
        _champChoix(
          2,
          code: 'date',
          titre: 'Date',
          valeur: _dateChoisie == null
              ? null
              : '${_dateChoisie!.day}/${_dateChoisie!.month}/${_dateChoisie!.year}',
          verrouille: verrouille,
          onTap: _choisirDate,
        ),
        const SizedBox(height: 12),
        _champChoix(
          3,
          code: 'heure',
          titre: 'Heure',
          valeur: _heureChoisie?.format(context),
          verrouille: verrouille,
          onTap: _choisirHeure,
        ),
        const SizedBox(height: 12),

        _anime(
          4,
          TextField(
            controller: _controllerMotif,
            enabled: !verrouille,
            keyboardType: TextInputType.multiline,
            maxLines: 2,
            decoration: _decoration('Motif (optionnel)'),
            onSubmitted: (_) => _valider(),
          ),
        ),
        const SizedBox(height: 24),

        _anime(
          5,
          // Désactivé (gris) tant que le formulaire est incomplet ;
          // indicateur de progression pendant l'envoi.
          BoutonDegradeSpec(
            texte: 'Programmer le rendez-vous',
            chargement: _envoiEnCours,
            onPressed: (!_formulaireValide && !_envoiEnCours)
                ? null
                : _valider,
          ),
        ),
      ],
    );
  }

  // Case de choix (date / heure) : même habillage que les champs de
  // formulaire (bordure 1 px, focus implicite au tap), avec le message
  // d'erreur live en dessous.
  Widget _champChoix(
    int index, {
    required String code,
    required String titre,
    required String? valeur,
    required bool verrouille,
    required VoidCallback onTap,
  }) {
    final erreur = _erreurCase(code);
    return _anime(
      index,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: verrouille ? null : onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: MaquetteCouleurs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: erreur == null
                      ? MaquetteCouleurs.bordure
                      : MaquetteCouleurs.refuseTexte,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    style: const TextStyle(
                      fontSize: 12,
                      color: MaquetteCouleurs.texteSecondaire,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    valeur ?? 'Appuyer pour choisir',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: valeur == null
                          ? FontWeight.w500
                          : FontWeight.w700,
                      color: valeur == null
                          ? MaquetteCouleurs.texteSecondaire
                          : MaquetteCouleurs.texte,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (erreur != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Text(
                erreur,
                style: const TextStyle(
                  fontSize: 12,
                  color: MaquetteCouleurs.refuseTexte,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Succès animé ──────────────────────────────────────────────────
  Widget _vueSucces() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutBack,
        builder: (context, valeur, enfant) => Opacity(
          // easeOutBack dépasse légèrement 1 : on borne pour l'opacité.
          opacity: valeur.clamp(0.0, 1.0).toDouble(),
          child: Transform.scale(scale: valeur, child: enfant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                gradient: MaquetteDegrades.principal,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 44,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Rendez-vous programmé',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: MaquetteCouleurs.texte,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Retour à la liste…',
              style: TextStyle(
                fontSize: 13,
                color: MaquetteCouleurs.texteSecondaire,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
