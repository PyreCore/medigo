import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/hopital_model.dart';
import '../../models/specialite.dart';
import '../services/firestore_service.dart';
import 'login_screen.dart';
import 'inscription_patient_loader.dart';
import 'routage_role.dart';

/// Page d'accueil PUBLIQUE de Medigo : c'est le premier écran vu au
/// lancement, avant toute connexion.
///
/// Le principe retenu : on laisse EXPLORER l'application sans compte
/// (hôpitaux, spécialités, fonctionnement), et on ne demande les
/// identifiants qu'au moment précis où l'utilisateur veut agir — prendre un
/// rendez-vous. Afficher le formulaire de connexion en premier imposait un
/// compte avant même de découvrir l'application.
///
/// La lecture du catalogue Firestore est tolérante à l'échec : si les règles
/// de sécurité de la base refusent la lecture anonyme, l'accueil reste
/// fully affichable (héros + CTA + « comment ça marche ») et seules les
/// listes se remplissent pas, avec un message explicite.
class AccueilPublicScreen extends StatefulWidget {
  const AccueilPublicScreen({super.key});

  @override
  State<AccueilPublicScreen> createState() => _AccueilPublicScreenState();
}

class _AccueilPublicScreenState extends State<AccueilPublicScreen> {
  final _service = FirestoreService();

  List<Hopital> _hopitaux = [];
  List<Specialite> _specialites = [];
  bool _chargement = true;
  String? _erreurCatalogue;

  // Recherche d'hôpital (exigence « Recherche d'hôpital »). Le filtrage
  // se fait sur la liste déjà chargée, pas dans Firestore : la liste des
  // hôpitaux est courte et le filtrage local est instantané, sans index ni
  // aller-retour réseau à chaque frappe.
  final _controllerRechercheHopital = TextEditingController();
  String _rechercheHopital = '';

  @override
  void dispose() {
    _controllerRechercheHopital.dispose();
    super.dispose();
  }

  /// Hôpitaux dont le nom, la ville/adresse ou le téléphone correspondent à
  /// la saisie. On ne cherche pas que dans le nom : un patient cherche
  /// souvent « Saint-Pierre » en tapant l'adresse.
  List<Hopital> get _hopitauxFiltres {
    final texte = _rechercheHopital.trim().toLowerCase();
    if (texte.isEmpty) return _hopitaux;
    return _hopitaux
        .where(
          (h) =>
              h.nom.toLowerCase().contains(texte) ||
              h.adresse.toLowerCase().contains(texte) ||
              h.telephone.contains(texte),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _chargerCatalogue();
  }

  Future<void> _chargerCatalogue() async {
    try {
      // Les deux lectures en parallèle : elles sont indépendantes et le
      // visitor attend les deux listes pour les afficher.
      final resultats = await Future.wait([
        _service.getHopitaux(),
        _service.getSpecialites(),
      ]);
      if (!mounted) return;
      setState(() {
        _hopitaux = resultats[0] as List<Hopital>;
        _specialites = resultats[1] as List<Specialite>;
        _chargement = false;
        _erreurCatalogue = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreurCatalogue =
            'Catalogue indisponible pour le moment. Vous pouvez tout de '
            'même parcourir la présentation et créer votre compte.';
      });
    }
  }

  // ---------------------------------------------------------------------
  // Naviguer
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

  /// Point de contrôle unique de l'accès : c'est ICI que se décide si
  /// l'utilisateur peut réserver ou doit d'abord s'identifier.
  ///
  /// La vérification est faite au moment du clic plutôt qu'à l'arrivée sur
  /// l'écran : l'utilisateur non connecté doit pouvoir lire l'accueil, les
  /// hôpitaux et les spécialités sans être bloqué.
  Future<void> _prendreRendezVous() async {
    if (FirebaseAuth.instance.currentUser == null) {
      // Non connecté : on explique pourquoi on demande les identifiants,
      // puis on ouvre la connexion (push, pas pushReplacement : on doit
      // pouvoir revenir à l'accueil public après s'être connecté).
      //
      // Le dialogue renvoie une intention ('connexion' / 'inscription' /
      // null pour "Plus tard") plutôt qu'un booléen : les deux boutons
      // positifs mènent à des écrans différents, un simple true/false les
      // confondrait.
      final intention = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.lock_outline, color: Color(0xFF2E7D32), size: 40),
          title: const Text('Connexion requise'),
          content: const Text(
            'La prise de rendez-vous est réservée aux comptes Medigo. '
            'Connectez-vous, ou créez votre compte patient, pour continuer.',
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
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
              ),
              onPressed: () => Navigator.pop(context, 'connexion'),
              child: const Text('Se connecter'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (intention == 'connexion') {
        _ouvrirConnexion();
      } else if (intention == 'inscription') {
        _ouvrirInscription();
      }
      return;
    }

    // Déjà connecté : on le renvoie vers son propre espace (le patient vers
    // PatientHomeLoader, qui contient l'onglet « Prendre rendez-vous »).
    final ok = await RoutageRole.ouvrirEspaceConnecte(context);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun espace ne correspond à ce compte.'),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------
  // Interface
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connecte = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      // Verrou vert : c'est la couleur d'identité de l'accueil public. Elle
      // se distingue du bleu de l'espace patient pour qu'on sache
      // immédiatement qu'on est dans la partie publique.
      appBar: AppBar(
        title: const Text('Medigo'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (connecte)
            IconButton(
              tooltip: 'Mon espace',
              icon: const Icon(Icons.account_circle),
              onPressed: () async {
                final ok = await RoutageRole.ouvrirEspaceConnecte(context);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Aucun espace ne correspond à ce compte.'),
                    ),
                  );
                }
              },
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
      body: RefreshIndicator(
        onRefresh: _chargerCatalogue,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _Heros(onPrendreRendezVous: _prendreRendezVous),
            const SizedBox(height: 28),
            _SectionTitre(
              icone: Icons.local_hospital,
              titre: 'Nos hôpitaux',
              sousTitre: 'Établissements partenaires Medigo',
            ),
            if (_chargement)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_erreurCatalogue != null)
              _MessageInfo(texte: _erreurCatalogue!)
            else if (_hopitaux.isEmpty)
              const _MessageInfo(texte: 'Aucun hôpital enregistré pour le moment.')
            else ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _controllerRechercheHopital,
                  onChanged: (valeur) =>
                      setState(() => _rechercheHopital = valeur),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un hôpital',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(),
                    suffixIcon: _rechercheHopital.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _controllerRechercheHopital.clear();
                              setState(() => _rechercheHopital = '');
                            },
                          ),
                  ),
                ),
              ),
              if (_hopitauxFiltres.isEmpty)
                const _MessageInfo(
                  texte: 'Aucun hôpital ne correspond à cette recherche.',
                )
              else
                ..._hopitauxFiltres.map(
                  (h) => _CarteHopital(
                    hopital: h,
                    // Le catalogue est informatif : on n'exige aucun compte
                    // pour le lire, c'est la RÉSERVATION qui est gardée.
                    onReserver: _prendreRendezVous,
                  ),
                ),
            ],
            const SizedBox(height: 20),
            _SectionTitre(
              icone: Icons.medical_services,
              titre: 'Nos spécialités',
              sousTitre: '${_specialites.length} spécialité(s) disponible(s)',
            ),
            if (_chargement)
              const SizedBox(height: 24)
            else if (_erreurCatalogue != null)
              const SizedBox(height: 8)
            else if (_specialites.isEmpty)
              const _MessageInfo(texte: 'Aucune spécialité publiée pour le moment.')
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _specialites
                      .map((s) => _PuceSpecialite(specialite: s))
                      .toList(),
                ),
              ),
            const SizedBox(height: 28),
            _SectionTitre(
              icone: Icons.help_outline,
              titre: 'Comment ça marche ?',
              sousTitre: 'Trois étapes, sans complication',
            ),
            const _Etape(
              numero: 1,
              icone: Icons.search,
              titre: 'Parcourez',
              texte:
                  'Consultez les hôpitaux et les spécialités Medigo. '
                  'Aucune inscription n\'est nécessaire pour cette étape.',
            ),
            const _Etape(
              numero: 2,
              icone: Icons.badge_outlined,
              titre: 'Identifiez-vous',
              texte:
                  'Créez votre compte patient ou connectez-vous avec vos '
                  'identifiants existants.',
            ),
            const _Etape(
              numero: 3,
              icone: Icons.event_available,
              titre: 'Réservez',
              texte:
                  'Choisissez votre médecin, la date et l\'heure. Le médecin '
                  'confirme ensuite votre demande.',
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.event_available),
                  label: Text(
                    connecte ? 'Accéder à mes rendez-vous' : 'Prendre rendez-vous',
                  ),
                  onPressed: _prendreRendezVous,
                ),
              ),
            ),
            if (!connecte) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2E7D32),
                      side: const BorderSide(color: Color(0xFF2E7D32)),
                    ),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Créer un compte patient'),
                    onPressed: _ouvrirInscription,
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.only(top: 24, left: 24, right: 24),
              child: Text(
                'Medigo — application de gestion des rendez-vous médicaux.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.black45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bandeau d'accueil : nom, promesse et appel à l'action principal.
class _Heros extends StatelessWidget {
  final VoidCallback onPrendreRendezVous;

  const _Heros({required this.onPrendreRendezVous});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 38,
            backgroundColor: Colors.white,
            child: Icon(Icons.medical_services, size: 40, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Bienvenue sur Medigo',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Parcourez nos hôpitaux et nos spécialités librement. '
            'Connectez-vous uniquement au moment de réserver.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              // Fond blanc / texte vert : le bouton d'action tranche
              // nettement sur le bandeau vert, contrairement à un bouton
              // vert sur vert qui disparaîtrait.
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1B5E20),
              ),
              icon: const Icon(Icons.event_available),
              label: const Text('Prendre rendez-vous'),
              onPressed: onPrendreRendezVous,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitre extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String sousTitre;

  const _SectionTitre({
    required this.icone,
    required this.titre,
    required this.sousTitre,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Icon(icone, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  sousTitre,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CarteHopital extends StatelessWidget {
  final Hopital hopital;
  final VoidCallback onReserver;

  const _CarteHopital({required this.hopital, required this.onReserver});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFC8E6C9)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_hospital, color: Color(0xFF2E7D32)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hopital.nom.isEmpty ? 'Hôpital sans nom' : hopital.nom,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (hopital.adresse.isNotEmpty) ...[
              const SizedBox(height: 8),
              _Ligne(Icons.place_outlined, hopital.adresse),
            ],
            if (hopital.telephone.isNotEmpty) ...[
              const SizedBox(height: 4),
              _Ligne(Icons.phone_outlined, hopital.telephone),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF2E7D32)),
                icon: const Icon(Icons.event_available, size: 18),
                label: const Text('Réserver'),
                onPressed: onReserver,
              ),
            ),
          ],
        ),
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
        Icon(icone, size: 15, color: Colors.black45),
        const SizedBox(width: 6),
        Expanded(
          child: Text(texte, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ),
      ],
    );
  }
}

class _PuceSpecialite extends StatelessWidget {
  final Specialite specialite;

  const _PuceSpecialite({required this.specialite});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Text(
        specialite.nom,
        style: const TextStyle(
          color: Color(0xFF1B5E20),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Etape extends StatelessWidget {
  final int numero;
  final IconData icone;
  final String titre;
  final String texte;

  const _Etape({
    required this.numero,
    required this.icone,
    required this.titre,
    required this.texte,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE8F5E9),
            child: Icon(icone, size: 20, color: const Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$numero. $titre',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(texte, style: const TextStyle(fontSize: 13, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageInfo extends StatelessWidget {
  final String texte;

  const _MessageInfo({required this.texte});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Text(texte, style: const TextStyle(fontSize: 13, color: Colors.black87)),
    );
  }
}
