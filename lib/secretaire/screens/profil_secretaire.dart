// ─────────────────────────────────────────────────────────────────────
// PROFIL SECRÉTAIRE — fiche complète du compte (mêmes blocs que le
// profil médecin pour une cohérence parfaite) :
//  · photo de profil (galerie → Firebase Storage → users/{uid}.photoUrl),
//  · identité (nom, fonction, hôpital),
//  · compte (e-mail, identifiant) et déconnexion.
// Parti pris visuel de l'application : AUCUNE icône, texte seul.
// ─────────────────────────────────────────────────────────────────────
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../../models/secretaire.dart';
import '../../theme/medigo_theme.dart';
import '../../widgets/ui_kit.dart';

class ProfilSecretaire extends StatefulWidget {
  final Secretaire secretaire;

  /// Photo à jour (peut changer après un envoi depuis CET écran).
  final String? photoUrl;

  /// Prévient l'espace parent quand la photo change.
  final ValueChanged<String?>? onPhotoChange;

  final VoidCallback? onDeconnexion;

  const ProfilSecretaire({
    super.key,
    required this.secretaire,
    this.photoUrl,
    this.onPhotoChange,
    this.onDeconnexion,
  });

  @override
  State<ProfilSecretaire> createState() => _ProfilSecretaireState();
}

class _ProfilSecretaireState extends State<ProfilSecretaire> {
  bool _envoiPhoto = false;

  String? get _photo => widget.photoUrl ?? widget.secretaire.photoUrl;

  /// Choisit une image dans la galerie, la redimensionne puis
  /// l'enregistre DANS Firestore (users/{uid}.photoUrl, format data
  /// base64) — sans Cloud Storage : 0 €, aucune carte bancaire.
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
      if (fichier == null) return; // l'utilisateur a annulé le choix

      setState(() => _envoiPhoto = true);

      final octets = await fichier.readAsBytes();

      // Décodage + redimensionnement (320 px de large) + compression
      // JPEG : sur le web, maxWidth/maxHeight de l'ImagePicker est
      // ignoré — on refait tout ici avec le package "image" (pur Dart).
      final image = img.decodeImage(octets);
      if (image == null) throw FormatException('image illisible');
      final jpeg = img.encodeJpg(
        img.copyResize(image, width: 320),
        quality: 82,
      );

      // URL « data » = image encodée en base64 stockée en chaîne : elle
      // tient dans un document Firestore (limite 1 Mo, on est à ~30 Ko).
      final chaine = 'data:image/jpeg;base64,${base64Encode(jpeg)}';
      if (chaine.length > 900000) throw Exception('image trop lourde');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(utilisateur.uid)
          .update({
        'photoUrl': chaine,
      });

      if (!mounted) return;
      setState(() => _envoiPhoto = false);
      widget.onPhotoChange?.call(chaine);
      messageFlash(context, 'Photo de profil mise à jour');
    } on FormatException {
      // Le fichier n'est pas un format que Flutter sait afficher
      // (HEIC d'iPhone, fichier vide, image corrompue...).
      if (!mounted) return;
      setState(() => _envoiPhoto = false);
      messageFlash(
        context,
        'Fichier illisible : choisissez une image JPEG ou PNG.',
        succes: false,
      );
    } catch (e) {
      // Toute autre erreur (règles de sécurité Firestore, hors ligne...) :
      // on l'affiche brute pour déboguer, et on la journalise dans la
      // console navigateur (F12) avec le préfixe ERREUR PHOTO.
      if (!mounted) return;
      setState(() => _envoiPhoto = false);
      debugPrint('ERREUR PHOTO : $e');
      messageFlash(context, 'Envoi impossible : $e', succes: false);
    }
  }

  // Affiche « Non renseigné » quand le champ est vide dans Firestore
  // (mieux qu'un blanc déroutant à l'écran).
  String _ouRenseigne(String valeur) =>
      valeur.trim().isEmpty ? 'Non renseigné' : valeur;

  @override
  Widget build(BuildContext context) {
    final utilisateur = FirebaseAuth.instance.currentUser;
    final email = utilisateur?.email ?? '—';
    final identifiant = utilisateur?.uid ?? widget.secretaire.id;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // ── Carte d'identité + photo ─────────────────────────────
        Apparition(
          delaiMs: 0,
          child: CarteMedigo(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundColor: AppColors.turquoise.withValues(alpha: 0.12),
                  backgroundImage: imageProfil(_photo),
                  child: _photo == null
                      ? Text(
                          initiales(
                            widget.secretaire.prenom,
                            widget.secretaire.nom,
                          ),
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppColors.turquoise,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 14),
                Text(
                  widget.secretaire.nomComplet,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.texte,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Secrétaire médicale',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.turquoise,
                  ),
                ),
                // Hôpital affiché UNIQUEMENT s'il est renseigné (certains
                // comptes n'ont pas ce champ dans Firestore).
                if (widget.secretaire.hopitalNom.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.secretaire.hopitalNom,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.texteFaible,
                    ),
                  ),
                ],
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
                          color: AppColors.turquoise,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Envoi de la photo…',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.texteFaible,
                        ),
                      ),
                    ],
                  )
                else
                  BoutonContour(
                    texte: _photo == null
                        ? 'Ajouter une photo'
                        : 'Changer de photo',
                    onPressed: _choisirPhoto,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Informations professionnelles ────────────────────────
        Apparition(
          delaiMs: 80,
          child: _carteInfos(
            titre: 'Informations professionnelles',
            infos: [
              ('Fonction', 'Secrétaire médicale'),
              ('Hôpital', _ouRenseigne(widget.secretaire.hopitalNom)),
              ('Rôle', 'Secrétaire'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Compte ───────────────────────────────────────────────
        Apparition(
          delaiMs: 140,
          child: _carteInfos(
            titre: 'Compte et sécurité',
            infos: [
              ('Adresse e-mail', email),
              ('Identifiant du compte', identifiant),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Déconnexion ──────────────────────────────────────────
        Apparition(
          delaiMs: 200,
          child: BoutonContour(
            texte: 'Se déconnecter',
            couleur: AppColors.rouge,
            hauteur: 48,
            pleineLargeur: true,
            onPressed: widget.onDeconnexion,
          ),
        ),
      ],
    );
  }

  // Carte « titre + lignes label/valeur » séparées par des filets.
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
          color: AppColors.texte,
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
                    color: AppColors.texteFaible,
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
                    color: AppColors.texte,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return CarteMedigo(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lignes,
      ),
    );
  }
}
