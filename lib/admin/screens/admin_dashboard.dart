import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'hopital_detail_screen.dart';
import '../../shared/constants/provinces.dart';
import '../../theme/admin_theme.dart';
import '../../theme/maquette_tokens.dart';
import '../../widgets/champ_mot_de_passe.dart';
import '../../widgets/maquette_widgets.dart';
import '../../widgets/profil_admin.dart';
import '../../widgets/regle_mot_de_passe.dart';
import '../../widgets/structure_espace.dart';
import '../../widgets/ui_kit.dart';

class AdminSystemeDashboard extends StatefulWidget {
  const AdminSystemeDashboard({super.key});

  @override
  State<AdminSystemeDashboard> createState() => _AdminSystemeDashboardState();
}

class _AdminSystemeDashboardState extends State<AdminSystemeDashboard> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 0 = Tableau de bord, 1 = Hôpitaux, 2 = Utilisateurs, 3 = Profil.
  int _ongletActif = 0;

  Map<String, dynamic>? _profil;
  Future<Map<String, int>>? _stats;

  @override
  void initState() {
    super.initState();
    _chargerProfil();
    _stats = _chargerStats();
  }

  // ── Données ────────────────────────────────────────────────────────

  Future<void> _chargerProfil() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!mounted) return;
    setState(() => _profil = doc.data() ?? const <String, dynamic>{});
  }

  Future<Map<String, int>> _chargerStats() async {
    final hopitaux = await _db.collection('hopitaux').get();
    final users = await _db.collection('users').get();
    final medecins = await _db.collection('medecins').get();

    var adminsHopitaux = 0;
    for (final doc in users.docs) {
      if ((doc.data()['role'] ?? '').toString() == 'adminHopital') {
        adminsHopitaux++;
      }
    }

    return {
      'hopitaux': hopitaux.docs.length,
      'utilisateurs': users.docs.length,
      'adminsHopitaux': adminsHopitaux,
      'medecins': medecins.docs.length,
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
    return valeur.isEmpty ? '?' : valeur;
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
      _buildHopitaux(),
      _buildUtilisateurs(),
      _buildProfil(),
    ];

    return StructureEspace(
      titreEspace: 'Espace Administrateur',
      nomUtilisateur: _nomComplet,
      initialesUser: _initiales,
      photoUser: _photo,
      degradeNavigation: AdminCouleurs.degrade,
      indexActif: _ongletActif,
      onChoisirOnglet: (index) => setState(() => _ongletActif = index),
      libelles: const [
        'Tableau de bord',
        'Hôpitaux',
        'Utilisateurs',
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
            icone: Icons.local_hospital_outlined,
            couleurIcone: AdminCouleurs.violet,
            fondPastel: AdminCouleurs.violetClair,
            valeur: valeur('hopitaux'),
            libelle: 'Hôpitaux',
          ),
          TuileStatSpec(
            icone: Icons.people_outline,
            couleurIcone: AdminCouleurs.indigo,
            fondPastel: AdminCouleurs.violetClair,
            valeur: valeur('utilisateurs'),
            libelle: 'Utilisateurs',
          ),
          TuileStatSpec(
            icone: Icons.shield_outlined,
            couleurIcone: AdminCouleurs.violetMoyen,
            fondPastel: AdminCouleurs.violetClair,
            valeur: valeur('adminsHopitaux'),
            libelle: 'Admins hôpital',
          ),
          TuileStatSpec(
            icone: Icons.medical_services_outlined,
            couleurIcone: AdminCouleurs.pourpre,
            fondPastel: AdminCouleurs.violetClair,
            valeur: valeur('medecins'),
            libelle: 'Médecins',
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
            const Text(
              'Vue d\'ensemble de la plateforme Medigo',
              style: TextStyle(
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
              texte: 'Ajouter un hôpital',
              onPressed: _ajouterHopital,
              couleurActive: AdminCouleurs.violet,
              hauteur: 48,
            ),
            const SizedBox(height: 10),
            BoutonContourSpec(
              texte: 'Ajouter un admin d\'hôpital',
              onPressed: _ajouterAdminHopital,
              couleur: AdminCouleurs.violet,
              hauteur: 48,
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

  // ── Hôpitaux ───────────────────────────────────────────────────────

  Widget _buildHopitaux() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('hopitaux').snapshots(),
      builder: (context, snapshot) {
        final docs =
            snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[];

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            BoutonPleinSpec(
              texte: 'Ajouter un hôpital',
              onPressed: _ajouterHopital,
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
                  child: Center(child: Text('Aucun hôpital')),
                ),
              )
            else
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final nom = (data['nom'] ?? '').toString();
                final adresse = (data['adresse'] ?? '').toString();
                return CarteSpec(
                  margin: const EdgeInsets.only(bottom: 10),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HopitalDetailScreen(
                          hopitalId: doc.id,
                          hopitalNom: nom,
                        ),
                      ),
                    );
                  },
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
                          Icons.local_hospital,
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
                            if (adresse.isNotEmpty)
                              Text(
                                adresse,
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
                        onPressed: () => _supprimerHopital(doc.id, nom),
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

  // ── Utilisateurs ───────────────────────────────────────────────────

  Widget _buildUtilisateurs() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('users').snapshots(),
      builder: (context, snapshot) {
        final docs =
            snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[];

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            BoutonPleinSpec(
              texte: 'Ajouter un admin d\'hôpital',
              onPressed: _ajouterAdminHopital,
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
                  child: Center(child: Text('Aucun utilisateur')),
                ),
              )
            else
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final role = (data['role'] ?? '').toString();
                final nomComplet =
                    '${data['prenom'] ?? ''} ${data['nom'] ?? ''}'.trim();
                final email = (data['email'] ?? '').toString();

                IconData icone;
                Color couleur;
                Color fond;
                String libelleRole;
                if (role == 'adminSysteme') {
                  icone = Icons.shield;
                  couleur = AdminCouleurs.pourpre;
                  fond = AdminCouleurs.violetClair;
                  libelleRole = 'Admin système';
                } else if (role == 'adminHopital') {
                  icone = Icons.local_hospital;
                  couleur = AdminCouleurs.violet;
                  fond = AdminCouleurs.violetClair;
                  libelleRole = 'Admin hôpital';
                } else if (role == 'medecin') {
                  icone = Icons.medical_services;
                  couleur = AdminCouleurs.indigo;
                  fond = AdminCouleurs.violetClair;
                  libelleRole = 'Médecin';
                } else if (role == 'secretaire') {
                  icone = Icons.badge_outlined;
                  couleur = AdminCouleurs.violetMoyen;
                  fond = AdminCouleurs.violetClair;
                  libelleRole = 'Secrétaire';
                } else {
                  icone = Icons.person_outline;
                  couleur = MaquetteCouleurs.texteSecondaire;
                  fond = AdminCouleurs.violetClair;
                  libelleRole = role.isEmpty ? 'Utilisateur' : role;
                }

                return CarteSpec(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: fond, shape: BoxShape.circle),
                        child: Icon(icone, size: 20, color: couleur),
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
                              email.isEmpty ? libelleRole : '$libelleRole · $email',
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

  // ── Profil ─────────────────────────────────────────────────────────

  Widget _buildProfil() {
    return ProfilAdmin(
      sousTitre: 'Administrateur système',
      onProfilModifie: _chargerProfil,
      onDeconnexion: _seDeconnecter,
    );
  }

  Future<void> _seDeconnecter() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
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

  void _ajouterHopital() {
    final nomController = TextEditingController();
    final adresseController = TextEditingController();
    final telephoneController = TextEditingController();
    final emailController = TextEditingController();
    String? selectedProvince;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajouter un hôpital'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomController,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                TextField(
                  controller: adresseController,
                  decoration: const InputDecoration(labelText: 'Adresse'),
                ),
                TextField(
                  controller: telephoneController,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedProvince,
                  hint: const Text('Province (obligatoire)'),
                  items: provincesGabon
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => selectedProvince = value),
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
                if (selectedProvince == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Veuillez choisir une province'),
                    ),
                  );
                  return;
                }
                await _db.collection('hopitaux').add({
                  'nom': nomController.text,
                  'adresse': adresseController.text,
                  'telephone': telephoneController.text,
                  'email': emailController.text,
                  'province': selectedProvince,
                });
                _rafraichirStats();
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  void _ajouterAdminHopital() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nomController = TextEditingController();
    final prenomController = TextEditingController();
    String? selectedHopitalId;
    // Désactive le bouton « Créer » tant que le mot de passe ne remplit
    // pas tous les critères (8+ chiffre + casse + caractère spécial).
    bool mdpValide = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajouter un admin d\'hôpital'),
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
                const SizedBox(height: 8),
                ChampMotDePasse(
                  controller: passwordController,
                  onValideChange: (valide) =>
                      setDialogState(() => mdpValide = valide),
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: _db.collection('hopitaux').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }
                    final hopitaux = snapshot.data!.docs;
                    return DropdownButtonFormField<String>(
                      value: selectedHopitalId,
                      hint: const Text('Choisir un hôpital'),
                      items: hopitaux.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text((data['nom'] ?? '').toString()),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedHopitalId = value),
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
                if (selectedHopitalId == null) return;
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
                    'role': 'adminHopital',
                    'hopitalId': selectedHopitalId,
                  });
                  _rafraichirStats();
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  debugPrint('Erreur: $e');
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  void _supprimerHopital(String id, String nom) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cet hôpital ?'),
        content: Text('Voulez-vous supprimer $nom ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _db.collection('hopitaux').doc(id).delete();
              _rafraichirStats();
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MaquetteCouleurs.refuseTexte,
            ),
            child: const Text('Oui'),
          ),
        ],
      ),
    );
  }
}
