import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../theme/admin_theme.dart';
import '../theme/maquette_tokens.dart';
import 'bouton_deconnexion.dart';
import 'maquette_widgets.dart';
import 'ui_kit.dart';

/// Onglet « Profil » commun aux espaces Admin système et Admin hôpital.
///
/// Permet à l'administrateur connecté de :
///  · ajouter / changer sa photo de profil (stockée en base64 dans
///    users/{uid}.photoUrl, sans Cloud Storage) ;
///  · modifier ses coordonnées (prénom, nom, téléphone, adresse) via le
///    bouton « Modifier » ;
///  · consulter les informations du compte ;
///  · se déconnecter (bouton violet qui devient rouge au survol).
class ProfilAdmin extends StatefulWidget {
  /// Sous-titre affiché sous le nom (ex. « Administrateur système »).
  final String sousTitre;

  /// Prévient l'espace parent quand le profil change, pour rafraîchir
  /// le nom / la photo affichés dans la barre de navigation.
  final VoidCallback? onProfilModifie;

  /// Déconnexion personnalisée ; si null, on déconnecte et on renvoie
  /// vers l'écran de connexion.
  final VoidCallback? onDeconnexion;

  const ProfilAdmin({
    super.key,
    this.sousTitre = 'Administrateur',
    this.onProfilModifie,
    this.onDeconnexion,
  });

  @override
  State<ProfilAdmin> createState() => _ProfilAdminState();
}

class _ProfilAdminState extends State<ProfilAdmin> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Map<String, dynamic>? _profil;
  bool _envoiPhoto = false;

  @override
  void initState() {
    super.initState();
    _chargerProfil();
  }

  Future<void> _chargerProfil() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!mounted) return;
    setState(() => _profil = doc.data() ?? const <String, dynamic>{});
  }

  String get _prenom => (_profil?['prenom'] ?? '').toString();
  String get _nom => (_profil?['nom'] ?? '').toString();
  String get _telephone => (_profil?['telephone'] ?? '').toString();
  String get _adresse => (_profil?['adresse'] ?? '').toString();

  String get _nomComplet {
    final complet = '$_prenom $_nom'.trim();
    return complet.isEmpty ? 'Administrateur' : complet;
  }

  String? get _photo {
    final valeur = (_profil?['photoUrl'] ?? '').toString();
    return valeur.isEmpty ? null : valeur;
  }

  // ── Photo ──────────────────────────────────────────────────────────

  Future<void> _choisirPhoto() async {
    if (_envoiPhoto) return;
    final utilisateur = FirebaseAuth.instance.currentUser;
    if (utilisateur == null) return;

    try {
      final fichier = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (fichier == null) return;

      setState(() => _envoiPhoto = true);

      final octets = await fichier.readAsBytes();
      final image = img.decodeImage(octets);
      if (image == null) throw const FormatException('image illisible');

      final jpeg = img.encodeJpg(
        img.copyResize(image, width: 320),
        quality: 82,
      );
      final chaine = 'data:image/jpeg;base64,${base64Encode(jpeg)}';
      if (chaine.length > 900000) throw Exception('image trop lourde');

      await _db.collection('users').doc(utilisateur.uid).update({
        'photoUrl': chaine,
      });

      if (!mounted) return;
      setState(() {
        _profil = {...?_profil, 'photoUrl': chaine};
        _envoiPhoto = false;
      });
      widget.onProfilModifie?.call();
      messageFlash(context, 'Photo de profil mise à jour');
    } on FormatException {
      if (!mounted) return;
      setState(() => _envoiPhoto = false);
      messageFlash(
        context,
        'Fichier illisible : choisissez une image JPEG ou PNG.',
        succes: false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _envoiPhoto = false);
      messageFlash(context, 'Envoi impossible : $e', succes: false);
    }
  }

  // ── Modification des coordonnées ───────────────────────────────────

  Future<void> _modifier() async {
    final prenomCtrl = TextEditingController(text: _prenom);
    final nomCtrl = TextEditingController(text: _nom);
    final telCtrl = TextEditingController(text: _telephone);
    final adresseCtrl = TextEditingController(text: _adresse);
    final formKey = GlobalKey<FormState>();

    final valide = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier mes informations'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: prenomCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Prénom',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Renseignez le prénom'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nomCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Renseignez le nom' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: telCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: adresseCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Adresse',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminCouleurs.violet,
              foregroundColor: Colors.white,
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (valide != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _db.collection('users').doc(user.uid).update({
        'prenom': prenomCtrl.text.trim(),
        'nom': nomCtrl.text.trim(),
        'telephone': telCtrl.text.trim(),
        'adresse': adresseCtrl.text.trim(),
      });
      await _chargerProfil();
      widget.onProfilModifie?.call();
      if (!mounted) return;
      messageFlash(context, 'Informations mises à jour');
    } catch (e) {
      if (!mounted) return;
      messageFlash(context, 'Mise à jour impossible : $e', succes: false);
    }
  }

  Future<void> _seDeconnecter() async {
    if (widget.onDeconnexion != null) {
      widget.onDeconnexion!();
      return;
    }

    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Voulez-vous vraiment quitter votre espace ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oui'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  // ── Rendu ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_profil == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final email = (FirebaseAuth.instance.currentUser?.email ??
            (_profil!['email'] ?? ''))
        .toString();
    final identifiant = FirebaseAuth.instance.currentUser?.uid ?? '—';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        CarteSpec(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: AdminCouleurs.violetClair,
                backgroundImage: imageProfil(_photo),
                child: _photo == null
                    ? Text(
                        initiales(_prenom, _nom),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: AdminCouleurs.violet,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 14),
              Text(
                _nomComplet,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: MaquetteCouleurs.texte,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.sousTitre,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AdminCouleurs.violet,
                ),
              ),
              const SizedBox(height: 16),
              if (_envoiPhoto)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AdminCouleurs.violet,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Envoi de la photo…',
                      style: TextStyle(
                        fontSize: 13,
                        color: MaquetteCouleurs.texteSecondaire,
                      ),
                    ),
                  ],
                )
              else
                BoutonContourSpec(
                  texte: _photo == null
                      ? 'Ajouter une photo'
                      : 'Changer la photo',
                  couleur: AdminCouleurs.violet,
                  onPressed: _choisirPhoto,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _carteInfos(
          titre: 'Coordonnées',
          infos: [
            ('Prénom', _ouRenseigne(_prenom)),
            ('Nom', _ouRenseigne(_nom)),
            ('Téléphone', _ouRenseigne(_telephone)),
            ('Adresse', _ouRenseigne(_adresse)),
          ],
        ),
        const SizedBox(height: 16),
        BoutonPleinSpec(
          texte: 'Modifier',
          onPressed: _modifier,
          couleurActive: AdminCouleurs.violet,
          hauteur: 48,
        ),
        const SizedBox(height: 16),
        _carteInfos(
          titre: 'Compte',
          infos: [
            ('Adresse e-mail', _ouRenseigne(email)),
            ('Identifiant', identifiant),
          ],
        ),
        const SizedBox(height: 24),
        BoutonDeconnexion(onPressed: _seDeconnecter),
      ],
    );
  }

  String _ouRenseigne(String valeur) =>
      valeur.trim().isEmpty ? 'Non renseigné' : valeur;

  Widget _carteInfos({
    required String titre,
    required List<(String, String)> infos,
  }) {
    final lignes = <Widget>[
      Text(
        titre,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: MaquetteCouleurs.texte,
        ),
      ),
      const SizedBox(height: 4),
    ];
    for (var i = 0; i < infos.length; i++) {
      if (i > 0) lignes.add(const Divider(height: 1));
      lignes.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  infos[i].$1,
                  style: const TextStyle(
                    fontSize: 13,
                    color: MaquetteCouleurs.texteSecondaire,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  infos[i].$2,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MaquetteCouleurs.texte,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return CarteSpec(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lignes,
      ),
    );
  }
}
