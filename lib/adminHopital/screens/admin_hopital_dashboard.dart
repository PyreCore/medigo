import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/admin_theme.dart';
import '../../theme/maquette_tokens.dart';
import '../../widgets/champ_mot_de_passe.dart';
import '../../widgets/maquette_widgets.dart';
import '../../widgets/profil_admin.dart';
import '../../widgets/regle_mot_de_passe.dart';
import '../../widgets/structure_espace.dart';
import '../../widgets/ui_kit.dart';

class AdminHopitalDashboard extends StatefulWidget {
  final String hopitalId;

  const AdminHopitalDashboard({super.key, required this.hopitalId});

  @override
  State<AdminHopitalDashboard> createState() => _AdminHopitalDashboardState();
}

class _AdminHopitalDashboardState extends State<AdminHopitalDashboard> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 0 = Tableau de bord, 1 = Spécialités, 2 = Médecins,
  // 3 = Personnel, 4 = Patients, 5 = Profil.
  int _ongletActif = 0;

  String _hopitalNom = '';
  Map<String, dynamic>? _profil;
  Future<Map<String, int>>? _stats;

  @override
  void initState() {
    super.initState();
    _chargerHopital();
    _chargerProfil();
    _stats = _chargerStats();
  }

  // ── Données ────────────────────────────────────────────────────────

  Future<void> _chargerHopital() async {
    final doc =
        await _db.collection('hopitaux').doc(widget.hopitalId).get();
    if (!mounted || !doc.exists) return;
    setState(() {
      _hopitalNom = ((doc.data() as Map<String, dynamic>)['nom'] ?? '').toString();
    });
  }

  Future<void> _chargerProfil() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!mounted) return;
    setState(() => _profil = doc.data() ?? const <String, dynamic>{});
  }

  Future<Map<String, int>> _chargerStats() async {
    final specialites = await _db
        .collection('specialites')
        .where('hopitalId', isEqualTo: widget.hopitalId)
        .get();
    final medecins = await _db
        .collection('medecins')
        .where('hopitalId', isEqualTo: widget.hopitalId)
        .get();
    final users = await _db
        .collection('users')
        .where('hopitalId', isEqualTo: widget.hopitalId)
        .get();

    var personnel = 0;
    var patients = 0;
    for (final doc in users.docs) {
      final role = (doc.data()['role'] ?? '').toString();
      if (role == 'secretaire' || role == 'adminHopital') personnel++;
      if (role == 'patient') patients++;
    }

    return {
      'specialites': specialites.docs.length,
      'medecins': medecins.docs.length,
      'personnel': personnel,
      'patients': patients,
    };
  }

  void _rafraichirStats() {
    if (!mounted) return;
    setState(() => _stats = _chargerStats());
  }

  // ── Identité ───────────────────────────────────────────────────────

  String get _prenom => (_profil?['prenom'] ?? '').toString();
  String get _nom => (_profil?['nom'] ?? '').toString();

  String get _nomComplet {
    final complet = '$_prenom $_nom'.trim();
    return complet.isEmpty ? 'Administrateur' : complet;
  }

  String get _initiales {
    final valeur = initiales(_prenom, _nom);
    return valeur.isEmpty ? 'AH' : valeur;
  }

  String? get _photo {
    final valeur = (_profil?['photoUrl'] ?? '').toString();
    return valeur.isEmpty ? null : valeur;
  }

  // ── Interface ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final onglets = [
      _buildTableauDeBord(),
      _buildSpecialites(),
      _buildMedecins(),
      _buildPersonnel(),
      _buildPatients(),
      ProfilAdmin(
        sousTitre: 'Administrateur hôpital',
        onProfilModifie: _chargerProfil,
      ),
    ];

    return StructureEspace(
      titreEspace: _hopitalNom.isEmpty ? 'Espace Hôpital' : _hopitalNom,
      nomUtilisateur: _nomComplet,
      initialesUser: _initiales,
      photoUser: _photo,
      degradeNavigation: AdminCouleurs.degrade,
      indexActif: _ongletActif,
      onChoisirOnglet: (index) => setState(() => _ongletActif = index),
      libelles: const [
        'Tableau de bord',
        'Spécialités',
        'Médecins',
        'Personnel',
        'Patients',
        'Profil',
      ],
      onglets: onglets,
    );
  }

  // ── Tableau de bord ────────────────────────────────────────────────

  Widget _buildTableauDeBord() {
    return FutureBuilder<Map<String, int>>(
      future: _stats,
      builder: (context, snapshot) {
        final stats = snapshot.data ?? const <String, int>{};
        final chargement = snapshot.connectionState == ConnectionState.waiting;
        String valeur(String cle) =>
            chargement ? '…' : (stats[cle] ?? 0).toString();

        final tuiles = [
          TuileStatSpec(
            icone: Icons.star_outline,
            couleurIcone: AdminCouleurs.violet,
            fondPastel: AdminCouleurs.violetClair,
            valeur: valeur('specialites'),
            libelle: 'Spécialités',
          ),
          TuileStatSpec(
            icone: Icons.medical_services_outlined,
            couleurIcone: AdminCouleurs.indigo,
            fondPastel: AdminCouleurs.violetClair,
            valeur: valeur('medecins'),
            libelle: 'Médecins',
          ),
          TuileStatSpec(
            icone: Icons.badge_outlined,
            couleurIcone: AdminCouleurs.violetMoyen,
            fondPastel: AdminCouleurs.violetClair,
            valeur: valeur('personnel'),
            libelle: 'Personnel',
          ),
          TuileStatSpec(
            icone: Icons.people_outline,
            couleurIcone: AdminCouleurs.pourpre,
            fondPastel: AdminCouleurs.violetClair,
            valeur: valeur('patients'),
            libelle: 'Patients',
          ),
        ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              dateDuJour(),
              style: const TextStyle(
                fontSize: 13,
                color: MaquetteCouleurs.texteSecondaire,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Bonjour, $_nomComplet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: MaquetteTypo.titreEcran,
                fontWeight: FontWeight.w800,
                color: MaquetteCouleurs.texte,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _hopitalNom.isEmpty ? 'Gestion de votre établissement' : _hopitalNom,
              style: const TextStyle(
                fontSize: MaquetteTypo.secondaire,
                color: MaquetteCouleurs.texteSecondaire,
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, contraintes) {
                if (contraintes.maxWidth >= 640) {
                  return _ligneTuiles(tuiles);
                }
                return Column(
                  children: [
                    _ligneTuiles(tuiles.sublist(0, 2)),
                    const SizedBox(height: 10),
                    _ligneTuiles(tuiles.sublist(2)),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const EnTeteSectionSpec(titre: 'Actions rapides'),
            const SizedBox(height: 10),
            BoutonPleinSpec(
              texte: 'Ajouter une spécialité',
              onPressed: _ajouterSpecialite,
              couleurActive: AdminCouleurs.violet,
              hauteur: 48,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: BoutonContourSpec(
                    texte: 'Un médecin',
                    onPressed: _ajouterMedecin,
                    couleur: AdminCouleurs.violet,
                    hauteur: 48,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BoutonContourSpec(
                    texte: 'Une secrétaire',
                    onPressed: _ajouterSecretaire,
                    couleur: AdminCouleurs.violet,
                    hauteur: 48,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _ligneTuiles(List<Widget> tuiles) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tuiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: tuiles[i]),
          ],
        ],
      ),
    );
  }

  // ── Spécialités ────────────────────────────────────────────────────

  Widget _buildSpecialites() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('specialites')
          .where('hopitalId', isEqualTo: widget.hopitalId)
          .snapshots(),
      builder: (context, snapshot) {
        final docs =
            snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[];

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            BoutonPleinSpec(
              texte: 'Ajouter une spécialité',
              onPressed: _ajouterSpecialite,
              couleurActive: AdminCouleurs.violet,
              hauteur: 48,
            ),
            const SizedBox(height: 18),
            if (!snapshot.hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (docs.isEmpty)
              const CarteSpec(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Aucune spécialité')),
                ),
              )
            else
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final nom = (data['nom'] ?? '').toString();
                final description = (data['description'] ?? '').toString();
                return CarteSpec(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: AdminCouleurs.violetClair,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.star_outline,
                          size: 20,
                          color: AdminCouleurs.violet,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nom,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: MaquetteCouleurs.texte,
                              ),
                            ),
                            if (description.isNotEmpty)
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: MaquetteCouleurs.texteSecondaire,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: MaquetteCouleurs.refuseTexte,
                        ),
                        onPressed: () async {
                          await _db
                              .collection('specialites')
                              .doc(doc.id)
                              .delete();
                          _rafraichirStats();
                        },
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  // ── Médecins ───────────────────────────────────────────────────────

  Widget _buildMedecins() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('medecins')
          .where('hopitalId', isEqualTo: widget.hopitalId)
          .snapshots(),
      builder: (context, snapshot) {
        final docs =
            snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[];

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            BoutonPleinSpec(
              texte: 'Ajouter un médecin',
              onPressed: _ajouterMedecin,
              couleurActive: AdminCouleurs.violet,
              hauteur: 48,
            ),
            const SizedBox(height: 18),
            if (!snapshot.hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (docs.isEmpty)
              const CarteSpec(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Aucun médecin')),
                ),
              )
            else
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final nomComplet =
                    '${data['prenom'] ?? ''} ${data['nom'] ?? ''}'.trim();
                final email = (data['email'] ?? '').toString();
                return CarteSpec(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: AdminCouleurs.violetClair,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.medical_services,
                          size: 20,
                          color: AdminCouleurs.indigo,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nomComplet.isEmpty ? '—' : nomComplet,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: MaquetteCouleurs.texte,
                              ),
                            ),
                            if (email.isNotEmpty)
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: MaquetteCouleurs.texteSecondaire,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: MaquetteCouleurs.refuseTexte,
                        ),
                        onPressed: () async {
                          await _db.collection('medecins').doc(doc.id).delete();
                          _rafraichirStats();
                        },
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  // ── Personnel ──────────────────────────────────────────────────────

  Widget _buildPersonnel() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('users')
          .where('hopitalId', isEqualTo: widget.hopitalId)
          .snapshots(),
      builder: (context, snapshot) {
        final docs =
            snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[];
        final personnel = docs.where((doc) {
          final role = (doc.data() as Map<String, dynamic>)['role'] ?? '';
          return role == 'secretaire' || role == 'adminHopital';
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            BoutonPleinSpec(
              texte: 'Ajouter une secrétaire',
              onPressed: _ajouterSecretaire,
              couleurActive: AdminCouleurs.violet,
              hauteur: 48,
            ),
            const SizedBox(height: 18),
            if (!snapshot.hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (personnel.isEmpty)
              const CarteSpec(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Aucun personnel affecté')),
                ),
              )
            else
              ...personnel.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final role = (data['role'] ?? '').toString();
                final nomComplet =
                    '${data['prenom'] ?? ''} ${data['nom'] ?? ''}'.trim();
                final email = (data['email'] ?? '').toString();
                final estAdmin = role == 'adminHopital';

                return CarteSpec(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AdminCouleurs.violetClair,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          estAdmin ? Icons.shield_outlined : Icons.badge_outlined,
                          size: 20,
                          color: estAdmin
                              ? AdminCouleurs.pourpre
                              : AdminCouleurs.violetMoyen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nomComplet.isEmpty ? '—' : nomComplet,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: MaquetteCouleurs.texte,
                              ),
                            ),
                            Text(
                              estAdmin
                                  ? 'Admin hôpital${email.isEmpty ? '' : ' · $email'}'
                                  : 'Secrétaire${email.isEmpty ? '' : ' · $email'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: MaquetteCouleurs.texteSecondaire,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: MaquetteCouleurs.refuseTexte,
                        ),
                        onPressed: () =>
                            _supprimerUtilisateur(doc.id, nomComplet, role),
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  // ── Patients ───────────────────────────────────────────────────────

  Widget _buildPatients() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('users')
          .where('hopitalId', isEqualTo: widget.hopitalId)
          .snapshots(),
      builder: (context, snapshot) {
        final docs =
            snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[];
        final patients = docs.where((doc) {
          return ((doc.data() as Map<String, dynamic>)['role'] ?? '') ==
              'patient';
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (!snapshot.hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (patients.isEmpty)
              const CarteSpec(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Aucun patient rattaché')),
                ),
              )
            else
              ...patients.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final nomComplet =
                    '${data['prenom'] ?? ''} ${data['nom'] ?? ''}'.trim();
                final email = (data['email'] ?? '').toString();
                return CarteSpec(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: AdminCouleurs.violetClair,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          size: 20,
                          color: AdminCouleurs.pourpre,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nomComplet.isEmpty ? '—' : nomComplet,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: MaquetteCouleurs.texte,
                              ),
                            ),
                            if (email.isNotEmpty)
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: MaquetteCouleurs.texteSecondaire,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  // ── Actions Firestore ──────────────────────────────────────────────

  void _supprimerUtilisateur(String userId, String nom, String role) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cet utilisateur ?'),
        content: Text(
          'Voulez-vous supprimer $nom ($role) ?\n\nCette action est définitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: MaquetteCouleurs.refuseTexte,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _db.collection('users').doc(userId).delete();
      _rafraichirStats();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Utilisateur $nom supprimé')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  void _ajouterSpecialite() {
    final nomController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter une spécialité'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomController,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _db.collection('specialites').add({
                'nom': nomController.text,
                'description': descriptionController.text,
                'hopitalId': widget.hopitalId,
              });
              _rafraichirStats();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _ajouterSecretaire() {
    final nomController = TextEditingController();
    final prenomController = TextEditingController();
    final emailController = TextEditingController();
    final telephoneController = TextEditingController();
    final passwordController = TextEditingController();
    // Le bouton reste inactif tant que le mot de passe n'a pas ses 8
    // caractères, ses chiffres, sa casse et son caractère spécial.
    bool mdpValide = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajouter une secrétaire'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: prenomController,
                  decoration: const InputDecoration(labelText: 'Prénom'),
                ),
                TextField(
                  controller: nomController,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                TextField(
                  controller: telephoneController,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 4),
                ChampMotDePasse(
                  controller: passwordController,
                  onValideChange: (valide) =>
                      setDialogState(() => mdpValide = valide),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: !mdpValide
                  ? null
                  : () async {
                final erreur = verifierMotDePasse(passwordController.text);
                if (erreur != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(erreur)),
                  );
                  return;
                }
                try {
                  final result =
                      await FirebaseAuth.instance.createUserWithEmailAndPassword(
                    email: emailController.text.trim(),
                    password: passwordController.text,
                  );

                  await _db.collection('users').doc(result.user!.uid).set({
                    'prenom': prenomController.text,
                    'nom': nomController.text,
                    'email': emailController.text.trim(),
                    'telephone': telephoneController.text,
                    'role': 'secretaire',
                    'hopitalId': widget.hopitalId,
                    'hopitalNom': _hopitalNom,
                  });

                  _rafraichirStats();
                  if (mounted) Navigator.pop(context);
                } on FirebaseAuthException catch (e) {
                  if (!context.mounted) return;
                  final message = e.code == 'email-already-in-use'
                      ? 'Email déjà utilisé, veuillez choisir un autre'
                      : 'Erreur: ${e.message}';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')),
                  );
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  void _ajouterMedecin() {
    final nomController = TextEditingController();
    final prenomController = TextEditingController();
    final emailController = TextEditingController();
    final telephoneController = TextEditingController();
    final passwordController = TextEditingController();
    String? selectedSpecId;
    // Le bouton reste inactif tant que le mot de passe n'a pas ses 8
    // caractères, ses chiffres, sa casse et son caractère spécial.
    bool mdpValide = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajouter un médecin'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: prenomController,
                  decoration: const InputDecoration(labelText: 'Prénom'),
                ),
                TextField(
                  controller: nomController,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: telephoneController,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                ),
                const SizedBox(height: 4),
                ChampMotDePasse(
                  controller: passwordController,
                  onValideChange: (valide) =>
                      setDialogState(() => mdpValide = valide),
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: _db
                      .collection('specialites')
                      .where('hopitalId', isEqualTo: widget.hopitalId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }
                    final specs = snapshot.data!.docs;
                    return DropdownButtonFormField<String>(
                      value: selectedSpecId,
                      hint: const Text('Spécialité'),
                      items: specs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text((data['nom'] ?? '').toString()),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedSpecId = value),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: !mdpValide
                  ? null
                  : () async {
                final erreur = verifierMotDePasse(passwordController.text);
                if (erreur != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(erreur)),
                  );
                  return;
                }
                try {
                  final result =
                      await FirebaseAuth.instance.createUserWithEmailAndPassword(
                    email: emailController.text.trim(),
                    password: passwordController.text,
                  );

                  await _db.collection('users').doc(result.user!.uid).set({
                    'prenom': prenomController.text,
                    'nom': nomController.text,
                    'email': emailController.text.trim(),
                    'telephone': telephoneController.text,
                    'role': 'medecin',
                    'hopitalId': widget.hopitalId,
                    'specialiteId': selectedSpecId ?? '',
                  });

                  await _db.collection('medecins').add({
                    'prenom': prenomController.text,
                    'nom': nomController.text,
                    'email': emailController.text.trim(),
                    'telephone': telephoneController.text,
                    'specialiteId': selectedSpecId ?? '',
                    'hopitalId': widget.hopitalId,
                    'userId': result.user!.uid,
                  });

                  _rafraichirStats();
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  debugPrint('Erreur: $e');
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}
