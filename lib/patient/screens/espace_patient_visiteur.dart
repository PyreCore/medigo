import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/medecin.dart';
import '../../models/specialite.dart';
import '../../services/patient_service.dart';
import '../../shared/models/hopital_model.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/screens/inscription_patient_loader.dart';
import '../../shared/screens/login_screen.dart';
import '../../shared/screens/routage_role.dart';
import 'prendre_rendez_vous_patient.dart';

/// Espace Patient en mode VISITEUR : c'est le premier écran de
/// l'application, affiché sans connexion.
///
/// Le visiteur utilise l'application comme un patient — même barre de
/// navigation, mêmes couleurs que EspacePatient. Il peut tout CONSULTER :
/// hôpitaux, spécialités, médecins, et même le formulaire de réservation
/// complet avec les créneaux libres. Seul l'ENVOI de la demande exige un
/// compte : le bouton « Envoyer ma demande » passe par [_exigerConnexion],
/// seul point de contrôle de l'accès.
///
/// Les lectures se limitent aux collections ouvertes en lecture anonyme par
/// firestore.rules : `hopitaux`, `specialites`, `medecins` (au lieu de
/// `users`, réservée aux comptes connectés), `disponibilites` et
/// `creneaux_occupes`.
class EspacePatientVisiteur extends StatefulWidget {
  // Sources de données injectables, pour les tests : par défaut, Firestore
  // et FirebaseAuth. Un test widget n'initialise pas Firebase.
  final Future<List<Hopital>> Function()? chargerHopitaux;
  final Future<List<Specialite>> Function()? chargerSpecialites;
  final Future<List<Medecin>> Function(String hopitalId)? chargerMedecins;
  final bool Function()? estConnecte;

  const EspacePatientVisiteur({
    super.key,
    this.chargerHopitaux,
    this.chargerSpecialites,
    this.chargerMedecins,
    this.estConnecte,
  });

  @override
  State<EspacePatientVisiteur> createState() => _EspacePatientVisiteurState();
}

const _vert = Color(0xFF2E7D32);
const _vertFonce = Color(0xFF1B5E20);
const _vertClair = Color(0xFFE8F5E9);
const _bordureVerte = Color(0xFFC8E6C9);

class _EspacePatientVisiteurState extends State<EspacePatientVisiteur> {
  // 0 = Accueil, 1 = Hôpitaux, 2 = Prendre RDV, 3 = Profil.
  int _ongletActif = 0;

  // Hôpital pré-sélectionné dans le formulaire (« Réserver » d'un hôpital).
  Hopital? _hopitalReservation;

  // Créé au premier appel seulement : un test widget n'initialise pas
  // Firebase.
  late final _patientService = PatientService();

  List<Hopital> _hopitaux = [];
  List<Specialite> _specialites = [];
  bool _chargement = true;
  String? _erreurCatalogue;

  // Filtres de l'onglet Hôpitaux. Le filtrage est local : la liste des
  // hôpitaux est courte, le résultat est instantané et sans index Firestore.
  final _controllerRecherche = TextEditingController();
  String _recherche = '';
  String? _specialiteFiltre; // nom de spécialité, insensible à la casse

  static const _titres = ['Medigo', 'Hôpitaux', 'Prendre rendez-vous', 'Profil'];

  bool get _connecte =>
      (widget.estConnecte ?? () => FirebaseAuth.instance.currentUser != null)();

  @override
  void initState() {
    super.initState();
    _chargerCatalogue();
  }

  @override
  void dispose() {
    _controllerRecherche.dispose();
    super.dispose();
  }

  Future<void> _chargerCatalogue() async {
    final service = (widget.chargerHopitaux == null ||
            widget.chargerSpecialites == null)
        ? FirestoreService()
        : null;
    try {
      // Les deux lectures sont indépendantes : on les lance en parallèle.
      final resultats = await Future.wait([
        (widget.chargerHopitaux ?? service!.getHopitaux)(),
        (widget.chargerSpecialites ?? service!.getSpecialites)(),
      ]);
      if (!mounted) return;
      setState(() {
        _hopitaux = resultats[0] as List<Hopital>;
        _specialites = resultats[1] as List<Specialite>;
        _chargement = false;
        _erreurCatalogue = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreurCatalogue =
            'Catalogue indisponible pour le moment. Vérifiez votre connexion '
            'internet puis tirez vers le bas pour réessayer.';
      });
    }
  }

  // ---------------------------------------------------------------------
  // Filtres
  // ---------------------------------------------------------------------

  List<Specialite> _specialitesDe(Hopital h) =>
      _specialites.where((s) => s.hopitalId == h.id).toList();

  /// Noms de spécialités distincts, triés : une même spécialité peut être
  /// proposée par plusieurs hôpitaux, on ne l'affiche qu'une fois.
  List<String> get _nomsSpecialites {
    final vus = <String, String>{};
    for (final s in _specialites) {
      final nom = s.nom.trim();
      if (nom.isNotEmpty) vus.putIfAbsent(nom.toLowerCase(), () => nom);
    }
    final noms = vus.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return noms;
  }

  List<Hopital> get _hopitauxFiltres {
    final texte = _recherche.trim().toLowerCase();
    final filtre = _specialiteFiltre?.toLowerCase();
    return _hopitaux.where((h) {
      final correspondTexte = texte.isEmpty ||
          h.nom.toLowerCase().contains(texte) ||
          h.adresse.toLowerCase().contains(texte) ||
          h.telephone.contains(texte);
      final correspondSpecialite = filtre == null ||
          _specialitesDe(h).any((s) => s.nom.trim().toLowerCase() == filtre);
      return correspondTexte && correspondSpecialite;
    }).toList();
  }

  Future<List<Medecin>> _medecinsDe(String hopitalId) =>
      (widget.chargerMedecins ?? _patientService.getMedecinsPublics)(hopitalId);

  /// Ouvre l'onglet Prendre RDV, avec un hôpital déjà choisi ou non.
  void _ouvrirReservation([Hopital? hopital]) {
    setState(() {
      _hopitalReservation = hopital;
      _ongletActif = 2;
    });
  }

  void _voirHopitauxPour(String specialite) {
    setState(() {
      _specialiteFiltre = specialite;
      _ongletActif = 1;
    });
  }

  // ---------------------------------------------------------------------
  // Navigation et contrôle d'accès
  // ---------------------------------------------------------------------

  void _ouvrirConnexion() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _ouvrirInscription() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InscriptionPatientLoader()),
    );
  }

  Future<void> _ouvrirMonEspace() async {
    final ok = await RoutageRole.ouvrirEspaceConnecte(context);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun espace ne correspond à ce compte.')),
      );
    }
  }

  /// Point de contrôle UNIQUE de l'envoi d'une demande. Connecté : on ouvre
  /// son espace, qui contient le formulaire de rendez-vous. Visiteur : on
  /// explique pourquoi un compte est demandé, puis connexion ou inscription.
  Future<void> _exigerConnexion() async {
    if (_connecte) {
      await _ouvrirMonEspace();
      return;
    }
    // Le dialogue renvoie une intention plutôt qu'un booléen : les deux
    // boutons positifs mènent à deux écrans différents.
    final intention = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.lock_outline, color: _vert, size: 40),
        title: const Text('Connexion requise'),
        content: const Text(
          'Pour envoyer votre demande de rendez-vous, connectez-vous ou '
          'créez votre compte patient. C\'est gratuit et ne prend qu\'une '
          'minute.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'inscription'),
            child: const Text('Créer un compte'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _vert),
            onPressed: () => Navigator.pop(context, 'connexion'),
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (intention == 'connexion') _ouvrirConnexion();
    if (intention == 'inscription') _ouvrirInscription();
  }

  void _ouvrirDetailHopital(Hopital hopital) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _DetailHopital(
        hopital: hopital,
        specialites: _specialitesDe(hopital),
        medecins: _medecinsDe(hopital.id),
        onReserver: () {
          Navigator.pop(context);
          _ouvrirReservation(hopital);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Interface
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final connecte = _connecte;
    final onglets = [
      _ongletAccueil(connecte),
      _ongletHopitaux(),
      _ongletReservation(connecte),
      _OngletProfilVisiteur(
        connecte: connecte,
        onConnexion: _ouvrirConnexion,
        onInscription: _ouvrirInscription,
        onMonEspace: _ouvrirMonEspace,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: Text(_titres[_ongletActif]),
        backgroundColor: _vert,
        foregroundColor: Colors.white,
        actions: [
          if (connecte)
            IconButton(
              tooltip: 'Mon espace',
              icon: const Icon(Icons.account_circle),
              onPressed: _ouvrirMonEspace,
            )
          else
            TextButton(
              onPressed: _ouvrirConnexion,
              child: const Text(
                'Se connecter',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: IndexedStack(index: _ongletActif, children: onglets),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _ongletActif,
        onDestinationSelected: (index) => setState(() => _ongletActif = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_hospital_outlined),
            selectedIcon: Icon(Icons.local_hospital),
            label: 'Hôpitaux',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Prendre RDV',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _ongletAccueil(bool connecte) {
    final apercu = _hopitaux.take(3).toList();
    return RefreshIndicator(
      onRefresh: _chargerCatalogue,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BandeauBienvenue(
            connecte: connecte,
            onPrendreRendezVous:
                connecte ? _ouvrirMonEspace : () => _ouvrirReservation(),
            onConnexion: _ouvrirConnexion,
            onInscription: _ouvrirInscription,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CarteChiffre(
                  icone: Icons.local_hospital,
                  valeur: _chargement ? '…' : '${_hopitaux.length}',
                  libelle: 'Hôpitaux',
                  onTap: () => setState(() => _ongletActif = 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CarteChiffre(
                  icone: Icons.medical_services,
                  valeur: _chargement ? '…' : '${_nomsSpecialites.length}',
                  libelle: 'Spécialités',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _TitreSection('Spécialités', 'Touchez une spécialité pour voir les hôpitaux'),
          if (_chargement)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_erreurCatalogue != null)
            _MessageInfo(_erreurCatalogue!)
          else if (_nomsSpecialites.isEmpty)
            const _MessageInfo('Aucune spécialité publiée pour le moment.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _nomsSpecialites
                  .map(
                    (nom) => ActionChip(
                      label: Text(nom),
                      labelStyle: const TextStyle(
                        color: _vertFonce,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: _vertClair,
                      side: const BorderSide(color: Color(0xFFA5D6A7)),
                      onPressed: () => _voirHopitauxPour(nom),
                    ),
                  )
                  .toList(),
            ),
          if (apercu.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: _TitreSection('Hôpitaux partenaires', 'Établissements Medigo'),
                ),
                TextButton(
                  onPressed: () => setState(() => _ongletActif = 1),
                  child: const Text('Voir tout'),
                ),
              ],
            ),
            ...apercu.map(
              (h) => _CarteHopital(
                hopital: h,
                nbSpecialites: _specialitesDe(h).length,
                onTap: () => _ouvrirDetailHopital(h),
                onReserver: () => _ouvrirReservation(h),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Onglet Prendre RDV : le VRAI formulaire, consultable sans compte.
  /// Seul l'envoi de la demande demande une connexion.
  Widget _ongletReservation(bool connecte) {
    if (connecte) {
      return _OngletReservationConnecte(onMonEspace: _ouvrirMonEspace);
    }
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erreurCatalogue != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [_MessageInfo(_erreurCatalogue!)],
      );
    }
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: _vertClair,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: const Row(
            children: [
              Icon(Icons.visibility_outlined, size: 18, color: _vertFonce),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mode visiteur : consultez librement les médecins et les '
                  'créneaux. La connexion est demandée à l\'envoi.',
                  style: TextStyle(fontSize: 12, color: _vertFonce),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: PrendreRendezVousPatient(
            // Nouvelle clé à chaque hôpital pré-sélectionné : le formulaire
            // repart de zéro avec cet hôpital.
            key: ValueKey('visiteur-${_hopitalReservation?.id}'),
            hopitaux: _hopitaux,
            hopitalInitial: _hopitalReservation,
            chargerMedecins: _medecinsDe,
            chargerSpecialites: (id) async =>
                _specialites.where((s) => s.hopitalId == id).toList(),
            onValider: ({required medecin, required date, required heure, motif}) {
              _exigerConnexion();
            },
          ),
        ),
      ],
    );
  }

  Widget _ongletHopitaux() {
    final liste = _hopitauxFiltres;
    return RefreshIndicator(
      onRefresh: _chargerCatalogue,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controllerRecherche,
            onChanged: (v) => setState(() => _recherche = v),
            decoration: InputDecoration(
              hintText: 'Nom, ville ou téléphone',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: _recherche.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controllerRecherche.clear();
                        setState(() => _recherche = '');
                      },
                    ),
            ),
          ),
          if (_specialiteFiltre != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                avatar: const Icon(Icons.medical_services, size: 18, color: _vert),
                label: Text(_specialiteFiltre!),
                onDeleted: () => setState(() => _specialiteFiltre = null),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_chargement)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_erreurCatalogue != null)
            _MessageInfo(_erreurCatalogue!)
          else if (_hopitaux.isEmpty)
            const _MessageInfo('Aucun hôpital enregistré pour le moment.')
          else if (liste.isEmpty)
            const _MessageInfo('Aucun hôpital ne correspond à cette recherche.')
          else
            ...liste.map(
              (h) => _CarteHopital(
                hopital: h,
                nbSpecialites: _specialitesDe(h).length,
                onTap: () => _ouvrirDetailHopital(h),
                onReserver: () => _ouvrirReservation(h),
              ),
            ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------------
// Composants
// -------------------------------------------------------------------------

class _BandeauBienvenue extends StatelessWidget {
  final bool connecte;
  final VoidCallback onPrendreRendezVous;
  final VoidCallback onConnexion;
  final VoidCallback onInscription;

  const _BandeauBienvenue({
    required this.connecte,
    required this.onPrendreRendezVous,
    required this.onConnexion,
    required this.onInscription,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_vert, _vertFonce],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bienvenue sur Medigo',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            connecte
                ? 'Vous êtes connecté. Ouvrez votre espace pour gérer vos rendez-vous.'
                : 'Trouvez un hôpital et une spécialité. Un compte vous sera '
                    'demandé uniquement pour réserver.',
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _vertFonce,
              ),
              icon: const Icon(Icons.event_available),
              label: Text(connecte ? 'Accéder à mes rendez-vous' : 'Prendre rendez-vous'),
              onPressed: onPrendreRendezVous,
            ),
          ),
          if (!connecte) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: onConnexion,
                  child: const Text('J\'ai déjà un compte'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: onInscription,
                  child: const Text('Créer un compte'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CarteChiffre extends StatelessWidget {
  final IconData icone;
  final String valeur;
  final String libelle;
  final VoidCallback? onTap;

  const _CarteChiffre({
    required this.icone,
    required this.valeur,
    required this.libelle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _bordureVerte),
          ),
          child: Row(
            children: [
              Icon(icone, color: _vert),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      valeur,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      libelle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitreSection extends StatelessWidget {
  final String titre;
  final String sousTitre;

  const _TitreSection(this.titre, this.sousTitre);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          Text(sousTitre, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}

class _CarteHopital extends StatelessWidget {
  final Hopital hopital;
  final int nbSpecialites;
  final VoidCallback onTap;
  final VoidCallback onReserver;

  const _CarteHopital({
    required this.hopital,
    required this.nbSpecialites,
    required this.onTap,
    required this.onReserver,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _bordureVerte),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: _vertClair,
                    child: Icon(Icons.local_hospital, color: _vert),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hopital.nom.isEmpty ? 'Hôpital sans nom' : hopital.nom,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.black38),
                ],
              ),
              if (hopital.adresse.isNotEmpty) ...[
                const SizedBox(height: 8),
                _Ligne(Icons.place_outlined, hopital.adresse),
              ],
              const SizedBox(height: 4),
              _Ligne(
                Icons.medical_services_outlined,
                nbSpecialites == 0
                    ? 'Spécialités bientôt disponibles'
                    : '$nbSpecialites spécialité(s)',
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: _vert),
                  icon: const Icon(Icons.event_available, size: 18),
                  label: const Text('Réserver'),
                  onPressed: onReserver,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailHopital extends StatelessWidget {
  final Hopital hopital;
  final List<Specialite> specialites;
  final Future<List<Medecin>> medecins;
  final VoidCallback onReserver;

  const _DetailHopital({
    required this.hopital,
    required this.specialites,
    required this.medecins,
    required this.onReserver,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(
              hopital.nom.isEmpty ? 'Hôpital sans nom' : hopital.nom,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (hopital.adresse.isNotEmpty) _Ligne(Icons.place_outlined, hopital.adresse),
            if (hopital.telephone.isNotEmpty) ...[
              const SizedBox(height: 6),
              _Ligne(Icons.phone_outlined, hopital.telephone),
            ],
            if (hopital.email.isNotEmpty) ...[
              const SizedBox(height: 6),
              _Ligne(Icons.email_outlined, hopital.email),
            ],
            const SizedBox(height: 20),
            const Text(
              'Spécialités proposées',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (specialites.isEmpty)
              const Text(
                'Cet hôpital n\'a pas encore publié ses spécialités.',
                style: TextStyle(color: Colors.black54),
              )
            else
              ...specialites.map(
                (s) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.medical_services_outlined, color: _vert),
                  title: Text(s.nom),
                  subtitle: s.description.isEmpty ? null : Text(s.description),
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'Médecins',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Medecin>>(
              future: medecins,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return const Text(
                    'Liste des médecins indisponible pour le moment.',
                    style: TextStyle(color: Colors.black54),
                  );
                }
                final liste = snapshot.data ?? const <Medecin>[];
                if (liste.isEmpty) {
                  return const Text(
                    'Aucun médecin n\'est encore enregistré dans cet hôpital.',
                    style: TextStyle(color: Colors.black54),
                  );
                }
                final noms = {for (final s in specialites) s.id: s.nom};
                return Column(
                  children: liste
                      .map(
                        (m) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: _vertClair,
                            child: Icon(Icons.person, color: _vert),
                          ),
                          title: Text(m.nomComplet),
                          subtitle: noms[m.specialiteId] == null
                              ? null
                              : Text(noms[m.specialiteId]!),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _vert),
                icon: const Icon(Icons.event_available),
                label: const Text('Réserver dans cet hôpital'),
                onPressed: onReserver,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Onglet « Prendre RDV » quand un compte est déjà connecté sur cet écran :
/// la réservation se fait depuis son espace.
class _OngletReservationConnecte extends StatelessWidget {
  final VoidCallback onMonEspace;

  const _OngletReservationConnecte({required this.onMonEspace});

  @override
  Widget build(BuildContext context) {
    return _PanneauCentre(
      icone: Icons.event_available,
      titre: 'Vous êtes connecté',
      texte: 'La prise de rendez-vous se fait depuis votre espace patient.',
      actions: [_BoutonPlein('Ouvrir mon espace', Icons.arrow_forward, onMonEspace)],
    );
  }
}

class _OngletProfilVisiteur extends StatelessWidget {
  final bool connecte;
  final VoidCallback onConnexion;
  final VoidCallback onInscription;
  final VoidCallback onMonEspace;

  const _OngletProfilVisiteur({
    required this.connecte,
    required this.onConnexion,
    required this.onInscription,
    required this.onMonEspace,
  });

  @override
  Widget build(BuildContext context) {
    if (connecte) {
      return _PanneauCentre(
        icone: Icons.account_circle,
        titre: 'Vous êtes connecté',
        texte: 'Votre profil se trouve dans votre espace.',
        actions: [_BoutonPlein('Ouvrir mon espace', Icons.arrow_forward, onMonEspace)],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 12),
        const Center(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: _vertClair,
            child: Icon(Icons.person_outline, size: 48, color: _vert),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Visiteur',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text(
            'Vous n\'êtes pas connecté',
            style: TextStyle(color: Colors.black54),
          ),
        ),
        const SizedBox(height: 24),
        _BoutonPlein('Se connecter', Icons.login, onConnexion),
        const SizedBox(height: 10),
        _BoutonContour('Créer un compte patient', Icons.person_add_alt, onInscription),
        const SizedBox(height: 28),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.badge_outlined, color: _vert),
          title: const Text('Professionnel de santé ?'),
          subtitle: const Text(
            'Médecin, secrétaire ou administrateur : connectez-vous avec le '
            'compte fourni par votre hôpital.',
          ),
          onTap: onConnexion,
        ),
      ],
    );
  }
}

class _PanneauCentre extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String texte;
  final List<Widget> actions;

  const _PanneauCentre({
    required this.icone,
    required this.titre,
    required this.texte,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: _vertClair,
                child: Icon(icone, size: 40, color: _vert),
              ),
              const SizedBox(height: 16),
              Text(
                titre,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                texte,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 24),
              for (final action in actions) ...[action, const SizedBox(height: 10)],
            ],
          ),
        ),
      ),
    );
  }
}

class _BoutonPlein extends StatelessWidget {
  final String texte;
  final IconData icone;
  final VoidCallback onPressed;

  const _BoutonPlein(this.texte, this.icone, this.onPressed);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: _vert),
        icon: Icon(icone),
        label: Text(texte),
        onPressed: onPressed,
      ),
    );
  }
}

class _BoutonContour extends StatelessWidget {
  final String texte;
  final IconData icone;
  final VoidCallback onPressed;

  const _BoutonContour(this.texte, this.icone, this.onPressed);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: _vert,
          side: const BorderSide(color: _vert),
        ),
        icon: Icon(icone),
        label: Text(texte),
        onPressed: onPressed,
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  final IconData icone;
  final String texte;

  const _Ligne(this.icone, this.texte);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 16, color: Colors.black45),
        const SizedBox(width: 6),
        Expanded(
          child: Text(texte, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ),
      ],
    );
  }
}

class _MessageInfo extends StatelessWidget {
  final String texte;

  const _MessageInfo(this.texte);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _bordureVerte),
      ),
      child: Text(texte, style: const TextStyle(fontSize: 13, color: Colors.black87)),
    );
  }
}
