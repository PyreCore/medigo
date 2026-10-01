import 'package:flutter/material.dart';
import '../../models/medecin.dart';
import '../../models/specialite.dart';
import '../../models/disponibilite.dart';
import '../../models/rendez_vous.dart';
import '../../shared/models/hopital_model.dart';
import '../../services/disponibilite_service.dart';
import '../../services/patient_service.dart';

/// Onglet "Prendre rendez-vous" : formulaire de demande.
///
/// Le patient choisit d'abord un HÔPITAL, puis une spécialité (facultative),
/// un médecin, une date, puis un CRÉNEAU parmi ceux que le médecin a
/// réellement déclarés. On ne propose plus une heure libre : un patient qui
/// choisirait 03:00 verrait sa demande partir en attente d'un créneau que le
/// médecin n'a jamais ouvert.
///
/// L'hôpital est le PREMIER sélecteur parce qu'il commande tout le reste :
/// médecins et spécialités sont chargés à la sélection, pas avant. Un
/// patient n'est rattaché à aucun établissement (il en choisit un à chaque
/// réservation), il n'y a donc pas de catalogue « de son hôpital » à charger
/// au démarrage.
///
/// Les disponibilités sont rechargées à chaque changement de médecin ou de
/// date, via DisponibiliteService et PatientService. Cet écran consulte donc
/// Firestore lui-même (toujours par l'intermédiaire d'un service, jamais
/// directement) : les données dépendent des choix en cours, que le
/// PatientHomeLoader ne peut pas connaître à l'avance.
class PrendreRendezVousPatient extends StatefulWidget {
  // Catalogue des hôpitaux partenaires, fourni par EspacePatient.
  final List<Hopital> hopitaux;

  // Rendez-vous à reprogrammer. Non null = l'écran passe en mode édition :
  // le médecin est verrouillé (on change de médecin, c'est une nouvelle
  // demande), le formulaire est pré-rempli et onValider est ignoré au profit
  // de onValiderModification.
  final RendezVous? rendezVousAModifier;

  // Appelée à la validation d'une NOUVELLE demande.
  final void Function({
    required Medecin medecin,
    required DateTime date,
    required String heure,
    String? motif,
  })? onValider;

  // Appelée à la validation d'une REPROGRAMMATION. Le rendez-vous n'est pas
  // passé en paramètre : le parent connaît déjà lequel il a ouvert.
  final void Function({required DateTime date, required String heure, String? motif})?
  onValiderModification;

  const PrendreRendezVousPatient({
    super.key,
    required this.hopitaux,
    this.rendezVousAModifier,
    this.onValider,
    this.onValiderModification,
  });

  @override
  State<PrendreRendezVousPatient> createState() =>
      _PrendreRendezVousPatientState();
}

class _PrendreRendezVousPatientState extends State<PrendreRendezVousPatient> {
  final _dispoService = DisponibiliteService();
  final _patientService = PatientService();

  // "widget" n'existe pas encore quand les champs d'un State sont
  // initialisés (le framework l'affecte après createState) : on initialise
  // donc ce drapeau à false et on le calcule dans initState.
  bool _modeEdition = false;

  Specialite? _specialiteChoisie;
  Medecin? _medecinChoisi;
  DateTime? _dateChoisie;

  // Hôpital choisi, puis le catalogue (médecins + spécialités) de cet
  // hôpital. Les deux sont chargés ici et non dans PatientHomeLoader,
  // parce qu'ils dépendent du choix en cours.
  Hopital? _hopitalChoisi;
  List<Medecin> _medecins = [];
  List<Specialite> _specialites = [];
  bool _chargementCatalogue = false;

  // Heure choisie : ce n'est plus une TimeOfDay libre mais un CRÉNEAU texte
  // ("09:30") issu de la liste réelle des disponibilités.
  String? _creneauChoisi;

  // Recherche par nom de médecin (exigence "rechercher un médecin").
  final _controllerRecherche = TextEditingController();
  String _recherche = '';

  final _controllerMotif = TextEditingController();

  // Disponibilités du médecin sélectionné, et créneaux du jour sélectionné.
  List<Disponibilite> _disponibilites = [];
  List<String> _creneaux = [];
  bool _chargementCreneaux = false;

  /// Rendez-vous en attente de reprogrammation quand le patient change de
  /// créneau : Firestore ne doit être appelé qu'au bouton de validation, pas
  /// à chaque changement de filtre.
  List<String> _heuresOccupees = [];

  @override
  void initState() {
    super.initState();
    final rdv = widget.rendezVousAModifier;
    _modeEdition = rdv != null;
    if (rdv != null) {
      _dateChoisie = rdv.date;
      _creneauChoisi = rdv.heure;
      _controllerMotif.text = rdv.motif ?? '';
      // En reprogrammation le médecin n'est PAS sélectionnable : c'est celui
      // du rendez-vous d'origine, on ne touche donc ni à l'hôpital ni au
      // catalogue. Seul le créneau est à refaire. Le patient garde ainsi son
      // médecin même s'il ne fait plus partie du catalogue affiché.
      //
      // On doit TOUT DE MÊME le charger : _chargerCreneaux() s'en sert pour
      // lire les disponibilités et les heures déjà prises. Sans lui, il sort
      // immédiatement et l'écran affiche « pas de disponibilité ce jour-là ».
      _chargerMedecinEdition(rdv);
    }
  }

  /// Reconstitue le médecin du rendez-vous reprogrammé depuis le rendez-vous
  /// lui-même, puis charge ses créneaux.
  ///
  /// On ne repasse pas par le catalogue `users` de l'hôpital : le médecin
  /// reste valide même s'il a quitté l'établissement, et le rendez-vous
  /// porte déjà son id et son nom. `hopitalId` peut être absent sur un
  /// rendez-vous ancien : Medecin le réclame, on chaîne donc sur une valeur
  /// vide, sans effet car rien n'est rendu dans ce mode.
  Future<void> _chargerMedecinEdition(RendezVous rdv) async {
    final id = rdv.medecinId;
    if (id == null || id.isEmpty) {
      _signaler('Ce rendez-vous ne précise pas son médecin');
      return;
    }
    setState(() {
      _medecinChoisi = Medecin(
        id: id,
        // Le rendez-vous mémorise déjà « Dr Moulekissi christiana », et
        // Medecin.nomComplet préfixe « Dr ». Le prénom est donc laissé vide,
        // sinon l'écran afficherait « Dr  Dr Moulekissi christiana ».
        nom: rdv.medecinNom ?? '',
        prenom: '',
        specialite: '',
        hopitalId: rdv.hopitalId ?? '',
        hopitalNom: '',
      );
    });
    await _chargerCreneaux();
  }

  @override
  void dispose() {
    _controllerMotif.dispose();
    _controllerRecherche.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Choix de l'hôpital et chargement du catalogue
  // ---------------------------------------------------------------------

  /// Charge les médecins et les spécialités de l'hôpital choisi.
  ///
  /// Les deux requêtes partent en parallèle : elles sont indépendantes et le
  /// patient attend les deux listes avant de choisir.
  ///
  /// Tous les choix aval sont invalués : la spécialité retenue peut ne pas
  /// exister dans le nouvel hôpital, et le médecin choisi peut ne plus y
  /// travailler. Le créneau part avec, puisqu'il dépendait de ce médecin.
  Future<void> _chargerCatalogueHopital(Hopital hopital) async {
    setState(() {
      _hopitalChoisi = hopital;
      _specialiteChoisie = null;
      _medecinChoisi = null;
      _creneauChoisi = null;
      _chargementCatalogue = true;
      _medecins = [];
      _specialites = [];
      _creneaux = [];
    });

    try {
      final resultats = await Future.wait([
        _patientService.getMedecins(hopital.id),
        _patientService.getSpecialites(hopital.id),
      ]);
      if (!mounted) return;
      setState(() {
        _medecins = resultats[0] as List<Medecin>;
        _specialites = resultats[1] as List<Specialite>;
        _chargementCatalogue = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _chargementCatalogue = false);
      _signaler('Catalogue de cet hôpital indisponible');
    }
  }

  // ---------------------------------------------------------------------
  // Filtrage du catalogue
  // ---------------------------------------------------------------------

  /// Médecins correspondant à la spécialité choisie ET à la recherche texte.
  ///
  /// La liste déjà filtrée par hôpital est `_medecins` : un médecin d'un
  /// autre établissement ne peut pas apparaître, même si son nom correspond
  /// à la recherche.
  List<Medecin> get _medecinsFiltres {
    final texte = _recherche.trim().toLowerCase();
    return _medecins.where((m) {
      if (_specialiteChoisie != null && m.specialiteId != _specialiteChoisie!.id) {
        return false;
      }
      if (texte.isEmpty) return true;
      return m.nomComplet.toLowerCase().contains(texte) ||
          m.specialite.toLowerCase().contains(texte);
    }).toList();
  }

  // ---------------------------------------------------------------------
  // Disponibilités
  // ---------------------------------------------------------------------

  /// Recharge les créneaux du jour sélectionné pour le médecin choisi.
  ///
  /// Les créneaux déjà pris sont retirés côté service, pas masqués ici : on
  /// veut une seule règle de calcul, réutilisée par l'écran de consultation
  /// des disponibilités.
  Future<void> _chargerCreneaux() async {
    final medecin = _medecinChoisi;
    final date = _dateChoisie;

    if (medecin == null || date == null) {
      setState(() {
        _disponibilites = [];
        _creneaux = [];
        _heuresOccupees = [];
      });
      return;
    }

    setState(() => _chargementCreneaux = true);

    try {
      final dispos = await _dispoService.getDisponibilites(medecin.id);
      final jour = Disponibilite.jourDeLaSemaine(date);
      final duJour = DisponibiliteService.pourJour(dispos, jour);

      // En mode édition on ignore l'occupation du rendez-vous qu'on est en
      // train de reprogrammer : sinon son propre créneau apparaîtrait pris et
      // le patient ne pourrait pas le conserver.
      var occupees = await _patientService.getHeuresOccupees(
        medecinId: medecin.id,
        date: date,
      );
      final rdv = widget.rendezVousAModifier;
      if (rdv != null &&
          rdv.medecinId == medecin.id &&
          _estMemeJour(rdv.date, date)) {
        occupees = occupees.where((h) => h != rdv.heure).toList();
      }

      final creneaux = DisponibiliteService.creneauxDisponibles(
        disponibilites: duJour,
        date: _formatDate(date),
        heuresOccupees: occupees,
      );

      if (!mounted) return;
      setState(() {
        _disponibilites = dispos;
        _heuresOccupees = occupees;
        _creneaux = creneaux;
        _chargementCreneaux = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creneaux = [];
        _chargementCreneaux = false;
      });
      _signaler('Disponibilités impossibles à charger pour le moment');
    }
  }

  /// Changer de médecin recharge ses disponibilités ET invalide le créneau
  /// retenu, qui n'existe peut-être plus chez le nouveau médecin.
  Future<void> _choisirMedecin(Medecin? medecin) async {
    setState(() {
      _medecinChoisi = medecin;
      _creneauChoisi = null;
    });
    await _chargerCreneaux();
  }

  Future<void> _choisirDate() async {
    final maintenant = DateTime.now();
    final resultat = await showDatePicker(
      context: context,
      initialDate: _dateChoisie ?? maintenant,
      firstDate: maintenant, // pas de rendez-vous dans le passé
      lastDate: maintenant.add(const Duration(days: 365)),
    );
    if (resultat != null) {
      setState(() {
        _dateChoisie = resultat;
        _creneauChoisi = null;
      });
      await _chargerCreneaux();
    }
  }

  // ---------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------

  void _valider() {
    // En reprogrammation, ni l'hôpital ni le médecin ne se choisissent :
    // c'est ceux du rendez-vous d'origine, seul le créneau change.
    if (_modeEdition) {
      if (_creneauChoisi == null) {
        _signaler('Merci de choisir un créneau disponible');
        return;
      }
      widget.onValiderModification?.call(
        date: _dateChoisie!,
        heure: _creneauChoisi!,
        motif: _motif,
      );
      return;
    }

    if (_hopitalChoisi == null) {
      _signaler('Merci de choisir un hôpital');
      return;
    }
    if (_creneauChoisi == null) {
      _signaler('Merci de choisir un créneau disponible');
      return;
    }
    if (_medecinChoisi == null) {
      _signaler('Merci de choisir un médecin');
      return;
    }
    if (_dateChoisie == null) {
      _signaler('Merci de choisir une date');
      return;
    }

    widget.onValider?.call(
      medecin: _medecinChoisi!,
      date: _dateChoisie!,
      heure: _creneauChoisi!,
      motif: _motif,
    );
  }

  String? get _motif => _controllerMotif.text.trim().isEmpty
      ? null
      : _controllerMotif.text.trim();

  void _signaler(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  static bool _estMemeJour(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------------
  // Interface
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Aucun hôpital partenaire du tout : aucun formulaire ne peut aboutir.
    if (widget.hopitaux.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aucun hôpital n\'est encore enregistré sur Medigo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black45),
          ),
        ),
      );
    }

    final medecins = _medecinsFiltres;
    final rdv = widget.rendezVousAModifier;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (rdv != null) _BandeauEdition(rdv: rdv),
        if (rdv != null) const SizedBox(height: 16),
        Text(
          _modeEdition
              ? 'Choisissez une nouvelle date et un nouveau créneau.'
              : 'Choisissez l\'hôpital, puis votre médecin.',
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 16),
        // En reprogrammation on n'affiche pas ce sélecteur : l'hôpital est
        // celui du rendez-vous d'origine, le patient ne peut pas le changer.
        if (!_modeEdition) ...[
          DropdownButtonFormField<Hopital>(
            initialValue: _hopitalChoisi,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Hôpital',
              prefixIcon: Icon(Icons.local_hospital),
              border: OutlineInputBorder(),
            ),
            items: widget.hopitaux
                .map(
                  (h) => DropdownMenuItem(
                    value: h,
                    child: Text(
                      h.nom,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (hopital) {
              if (hopital != null) _chargerCatalogueHopital(hopital);
            },
          ),
          const SizedBox(height: 12),
          // Tant qu'aucun hôpital n'est choisi, specialty / recherche /
          // médecin n'ont rien à filtrer : on n'affiche que ce qui sert à
          // faire le premier choix, sinon le patient verrait des listes
          // vides sans comprendre pourquoi.
          if (_hopitalChoisi == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Choisissez un hôpital pour voir ses médecins et ses '
                'spécialités.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black45),
              ),
            ),
        ],
        if (_chargementCatalogue)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_hopitalChoisi != null && _medecins.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Aucun médecin n\'est encore enregistré dans cet hôpital.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45),
            ),
          )
        else if (_hopitalChoisi != null) ...[
          DropdownButtonFormField<Specialite>(
            initialValue: _specialiteChoisie,
            decoration: const InputDecoration(
              labelText: 'Spécialité (optionnel)',
              prefixIcon: Icon(Icons.medical_services),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<Specialite>(
                value: null,
                child: Text('Toutes les spécialités'),
              ),
              ..._specialites.map(
                (s) => DropdownMenuItem(value: s, child: Text(s.nom)),
              ),
            ],
            // Changer de spécialité change la liste des médecins : on
            // invalide donc le médecin choisi, qui n'appartient peut-être plus
            // à la nouvelle liste.
            onChanged: (valeur) => setState(() {
              _specialiteChoisie = valeur;
              _medecinChoisi = null;
              _creneauChoisi = null;
            }),
          ),
          const SizedBox(height: 12),
          // Recherche par nom : exigence "rechercher un médecin selon sa
          // spécialité". Le filtre spécialité ci-dessus et ce champ se
          // cumulent.
          TextField(
            controller: _controllerRecherche,
            onChanged: (valeur) => setState(() => _recherche = valeur),
            decoration: const InputDecoration(
              labelText: 'Rechercher un médecin',
              hintText: 'Nom du médecin ou spécialité',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Medecin>(
            initialValue: _medecinChoisi,
            decoration: const InputDecoration(
              labelText: 'Médecin',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            items: medecins
                .map(
                  (m) => DropdownMenuItem(
                    value: m,
                    child: Text(
                      '${m.nomComplet}${m.specialite.isEmpty ? '' : ' — ${m.specialite}'}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _choisirMedecin,
          ),
          // Aucun médecin après application des filtres : le patient n'est
          // pas bloqué, il lui reste à reformuler sa recherche.
          if (medecins.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Aucun médecin ne correspond à cette recherche dans cet '
              'hôpital. Modifiez la spécialité ou le nom saisi.',
              style: TextStyle(
                color: Colors.black.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ],
        // À partir d'ici, la mise en page est commune à la création et à
        // la reprogrammation : en édition, l'hôpital et le médecin sont
        // ceux du rendez-vous d'origine, seul le créneau se reprogramme.
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today),
          title: Text(
            _dateChoisie == null
                ? 'Choisir une date'
                : '${_dateChoisie!.day}/${_dateChoisie!.month}/${_dateChoisie!.year}'
                      ' — ${Disponibilite.nomJour(Disponibilite.jourDeLaSemaine(_dateChoisie!))}',
          ),
          onTap: _choisirDate,
        ),
        const SizedBox(height: 8),
        _SelecteurCreneaux(
          medecin: _medecinChoisi,
          date: _dateChoisie,
          disponibilites: _disponibilites,
          creneaux: _creneaux,
          heuresOccupees: _heuresOccupees,
          chargement: _chargementCreneaux,
          creneauChoisi: _creneauChoisi,
          onChoisir: (creneau) => setState(() => _creneauChoisi = creneau),
          onChoisirDate: _choisirDate,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controllerMotif,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motif (optionnel)',
            prefixIcon: Icon(Icons.notes),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        // Rappel du circuit : le rendez-vous créé sera en attente de
        // validation par le médecin.
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.black45),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Votre demande sera transmise au médecin, qui pourra la '
                'confirmer ou la refuser.',
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
            onPressed:
                (_modeEdition ? widget.onValiderModification : widget.onValider) ==
                    null
                ? null
                : _valider,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _modeEdition
                    ? 'Enregistrer la reprogrammation'
                    : 'Envoyer ma demande',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bandeau affiché en tête du formulaire quand on reprogramme un rendez-vous.
class _BandeauEdition extends StatelessWidget {
  final RendezVous rdv;

  const _BandeauEdition({required this.rdv});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_calendar, color: Color(0xFF2E7D32)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Reprogrammation — ${rdv.medecinNom ?? 'votre rendez-vous'} '
              'du ${rdv.date.day}/${rdv.date.month}/${rdv.date.year} à ${rdv.heure}. '
              'Le médecin devra à nouveau confirmer.',
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sélecteur de créneau : planning hebdomadaire du médecin + créneaux libres
/// du jour choisi.
///
/// C'est le morceau qui satisfait « Consulter les disponibilités des médecins »
/// ET « Prendre un rendez-vous » : on y voit d'abord la semaine du médecin,
/// puis les heures réellement réservables.
class _SelecteurCreneaux extends StatelessWidget {
  final Medecin? medecin;
  final DateTime? date;
  final List<Disponibilite> disponibilites;
  final List<String> creneaux;
  final List<String> heuresOccupees;
  final bool chargement;
  final String? creneauChoisi;
  final ValueChanged<String> onChoisir;
  final VoidCallback onChoisirDate;

  const _SelecteurCreneaux({
    required this.medecin,
    required this.date,
    required this.disponibilites,
    required this.creneaux,
    required this.heuresOccupees,
    required this.chargement,
    required this.creneauChoisi,
    required this.onChoisir,
    required this.onChoisirDate,
  });

  @override
  Widget build(BuildContext context) {
    // Sans médecin choisi, il n'y a rien à afficher : les disponibilités sont
    // celles d'un médecin, pas de l'hôpital.
    if (medecin == null && date == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Choisissez un médecin et une date pour voir ses créneaux.',
          style: TextStyle(fontSize: 12, color: Colors.black45),
        ),
      );
    }

    if (chargement) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final joursOuverts = DisponibiliteService.joursOuverts(disponibilites);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Planning hebdomadaire du médecin, visible même avant d'avoir choisi
        // une date précise : c'est la réponse à « je veux voir quand il
        // travaille » avant de s'engager sur un jour.
        if (disponibilites.isNotEmpty) ...[
          Text(
            'Disponibilités de ${medecin?.nomComplet ?? 'ce médecin'}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: joursOuverts.map((jour) {
              final plages = DisponibiliteService.pourJour(disponibilites, jour);
              final resume = plages
                  .map((p) => p.heureDebut)
                  .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
              final fin = plages
                  .map((p) => p.heureFin)
                  .reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: Text(
                  '${Disponibilite.nomJourCourt(jour)} $resume-$fin',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF1B5E20),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
        ],
        if (date == null)
          OutlinedButton.icon(
            onPressed: onChoisirDate,
            icon: const Icon(Icons.event),
            label: const Text('Choisir une date pour voir les créneaux'),
          )
        else ...[
          Text(
            'Créneaux le ${date!.day}/${date!.month}/${date!.year}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (creneaux.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Text(
                disponibilites.isEmpty
                    ? 'Ce médecin n\'a pas déclaré de disponibilité ce '
                          'jour-là. Choisissez une autre date.'
                    : 'Plus aucun créneau disponible ce jour-là '
                          '(${heuresOccupees.length} déjà pris). Choisissez une '
                          'autre date.',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: creneaux.map((creneau) {
                final selectionne = creneau == creneauChoisi;
                return ChoiceChip(
                  label: Text(creneau),
                  selected: selectionne,
                  onSelected: (_) => onChoisir(creneau),
                  selectedColor: const Color(0xFF2E7D32),
                  labelStyle: TextStyle(
                    color: selectionne ? Colors.white : Colors.black87,
                    fontSize: 12,
                  ),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFA5D6A7)),
                );
              }).toList(),
            ),
        ],
      ],
    );
  }
}
