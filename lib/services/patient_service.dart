import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/patient.dart';
import '../models/medecin.dart';
import '../models/specialite.dart';
import '../models/rendez_vous.dart';
import '../shared/models/hopital_model.dart';
import 'creneau_service.dart';

/// Service qui regroupe tout l'accès à Firestore pour la partie PATIENT.
/// Même principe que MedecinService et SecretaireService : les écrans ne
/// parlent jamais directement à Firestore, ils passent toujours par ce
/// service. Ça sépare "l'affichage" (screens) de "l'accès aux données"
/// (services).
class PatientService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CreneauService _creneaux = CreneauService();

  // ---------------------------------------------------------------------
  // INSCRIPTION
  // ---------------------------------------------------------------------

  /// Crée un compte patient complet : un compte Firebase Auth, un
  /// document dans la collection unique "users" (avec role == 'patient',
  /// comme le veut le dispatch de login_screen.dart) ET un document dans
  /// la collection "patients" qui porte le champ "userId" de liaison.
  ///
  /// Ce double enregistrement est ce qui relie les deux collections :
  ///  - "users" sert à l'authentification et à la redirection post-login ;
  ///  - "patients" sert de dossier médical et reste la source pour la
  ///    secrétaire, qui lit cette collection.
  Future<void> inscrire({
    required String nom,
    required String prenom,
    required String email,
    required String motDePasse,
    required String telephone,
    DateTime? dateNaissance,
    String? groupeSanguin,
  }) async {
    final auth = FirebaseAuth.instance;

    // 1. Compte d'authentification. Firestore génère l'uid.
    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: motDePasse,
    );
    final uid = credential.user!.uid;

    try {
      // 2. Profil dans la collection "users", lu par login_screen.dart
      //    pour savoir vers quel espace renvoyer l'utilisateur.
      await _db.collection('users').doc(uid).set({
        'prenom': prenom,
        'nom': nom,
        'email': email,
        'role': 'patient',
        'telephone': telephone,
        if (dateNaissance != null)
          'dateNaissance': Timestamp.fromDate(dateNaissance),
        if (groupeSanguin != null) 'groupeSanguin': groupeSanguin,
      });

      // 3. Dossier dans la collection "patients", rattaché au compte via
      //    "userId". C'est ce document que la secrétaire verra dans sa
      //    liste, et que PatientService relira à la connexion.
      //
      //    Aucun "hopitalId" ici : un auto-inscrit n'est rattaché à aucun
      //    établissement. La secrétaire le retrouve via ses rendez-vous
      //    (SecretaireService.getPatientsPourHopital), et un dossier n'est
      //    rattaché à un hôpital que si c'est elle qui le saisit au guichet.
      await _db.collection('patients').add({
        'nom': nom,
        'prenom': prenom,
        'email': email,
        'telephone': telephone,
        'userId': uid,
        if (dateNaissance != null)
          'dateNaissance': Timestamp.fromDate(dateNaissance),
        if (groupeSanguin != null) 'groupeSanguin': groupeSanguin,
      });
    } catch (e) {
      // Si l'écriture Firestore échoue, on ANNULE tout ce qui vient d'être
      // créé : le compte Auth (sinon on laisserait un compte orphelin,
      // connecté mais sans profil, que personne ne pourrait utiliser) et le
      // document "users" éventuellement déjà écrit (sinon un profil
      // role: 'patient' pointerait vers un uid qui n'existe plus, et
      // l'écran de connexion afficherait "Aucun profil trouve").
      await auth.currentUser?.delete();
      await _db.collection('users').doc(uid).delete();
      rethrow;
    }
  }

  // ---------------------------------------------------------------------
  // PROFIL
  // ---------------------------------------------------------------------

  /// Récupère le profil du patient ACTUELLEMENT CONNECTÉ.
  ///
  /// L'identité vient de Firebase Auth (currentUser.uid), jamais d'un
  /// paramètre fourni par l'écran : un patient ne peut donc pas afficher
  /// le dossier d'un autre en changeant une valeur.
  ///
  /// Renvoie null si le compte connecté n'a pas de rôle patient dans la
  /// collection "users" (cas d'un compte secrétaire/médecin qui tenterait
  /// d'entrer ici), ce qui laisse l'appelant afficher un message clair
  /// plutôt qu'une erreur brute.
  Future<Patient?> getProfilConnecte() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Aucun utilisateur connecté');
    }

    final profilDoc = await _db.collection('users').doc(user.uid).get();
    if (!profilDoc.exists) {
      return null;
    }

    final profil = profilDoc.data()!;
    if (profil['role'] != 'patient') {
      return null;
    }

    // UN seul filtre d'égalité => aucun index composite requis, conformément
    // à la contrainte documentée dans MedecinService (sans index, Firestore
    // renvoie failed-precondition et bloque la connexion à l'espace).
    final snapshot = await _db
        .collection('patients')
        .where('userId', isEqualTo: user.uid)
        .limit(1)
        .get();

    // Dossier "patients" absent : le compte a été créé avant l'espace
    // Patient (ou via un autre outillage). On le crée à la volée à partir
    // du document "users", pour que le patient apparaisse immédiatement
    // dans la liste de la secrétaire au lieu d'être invisible.
    if (snapshot.docs.isEmpty) {
      // .add() retourne la référence du document créé, qui porte son id
      // Firestore : c'est CET id (et non l'uid du compte) qu'il faut
      // réutiliser ensuite pour retrouver les rendez-vous du patient.
      final ref = await _db.collection('patients').add({
        'nom': profil['nom'] ?? '',
        'prenom': profil['prenom'] ?? '',
        'email': user.email ?? '',
        'telephone': profil['telephone'] ?? '',
        'userId': user.uid,
        if (profil['dateNaissance'] != null)
          'dateNaissance': profil['dateNaissance'],
        if (profil['groupeSanguin'] != null)
          'groupeSanguin': profil['groupeSanguin'],
      });

      return _versPatient(await ref.get(), email: user.email ?? '');
    }

    return _versPatient(snapshot.docs.first, email: user.email ?? '');
  }

  // ---------------------------------------------------------------------
  // CATALOGUE (hôpitaux / spécialités / médecins)
  // ---------------------------------------------------------------------

  /// Liste tous les hôpitaux enregistrés. Utilisée par le formulaire de
  /// réservation, qui en fait son premier sélecteur : le catalogue affiché
  /// ensuite (médecins + spécialités) est celui de l'hôpital choisi.
  ///
  /// Aucun filtre ici : une requête sans "where" n'exige aucun index.
  Future<List<Hopital>> getHopitaux() async {
    final snapshot = await _db.collection('hopitaux').get();
    return snapshot.docs
        .map((doc) => Hopital.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Liste des spécialités d'un hôpital, pour le sélecteur du formulaire
  /// "Prendre rendez-vous".
  Future<List<Specialite>> getSpecialites(String hopitalId) async {
    final snapshot = await _db
        .collection('specialites')
        .where('hopitalId', isEqualTo: hopitalId)
        .get();

    final liste = snapshot.docs
        .map((doc) => Specialite.fromJson({'id': doc.id, ...doc.data()}))
        .toList();

    liste.sort(
      (a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()),
    );
    return liste;
  }

  /// Liste des médecins d'un hôpital.
  ///
  /// Les deux filtres d'égalité (role + hopitalId) sont VOLONTAIRES, alors
  /// qu'un seul suffirait à l'écran. Ce n'est pas une question de confort :
  /// c'est ce qui rend la requête acceptable par les règles de sécurité.
  ///
  /// En effet, la règle n'autorise un patient que sur les documents dont
  /// "resource.data.role == 'medecin'". Firestore ne raisonne que sur ce que
  /// la requête constraint : sans filtre sur "role", il ne peut pas prouver
  /// que TOUS les documents renvoyés sont des médecins, et il refuse la
  /// requête entière. Avec le filtre, il y arrive.
  ///
  /// Contrepartie : deux égalités exigent un index composite
  /// users(role, hopitalId). Il est déclaré dans firestore.indexes.json.
  /// Le même index sert à SecretaireService.getMedecinsHopital.
  Future<List<Medecin>> getMedecins(String hopitalId) async {
    final snapshot = await _db
        .collection('users')
        .where('role', isEqualTo: 'medecin')
        .where('hopitalId', isEqualTo: hopitalId)
        .get();

    return snapshot.docs
        .map((doc) => Medecin.fromJson({'id': doc.id, ...doc.data()}))
        .toList();
  }

  /// Les heures déjà réservées chez un médecin pour une date donnée.
  ///
  /// Version corrigée : lit dans une collection dédiée "creneaux_occupes",
  /// indexée sur (medecinId, date). Cela évite de lire TOUS les RDV d'un
  /// médecin (fuite d'informations) et rend la requête prouvable par les
  /// règles (avec index composite requis).
  Future<List<String>> getHeuresOccupees({
    required String medecinId,
    required DateTime date,
  }) async {
    final snapshot = await _db
        .collection('creneaux_occupes')
        .where('medecinId', isEqualTo: medecinId)
        .where('date', isEqualTo: CreneauService.cleJour(date))
        .get();

    return snapshot.docs
        .map((doc) => (doc.data()['heure'] ?? '').toString())
        .where((heure) => heure.isNotEmpty)
        .toList();
  }

  // ---------------------------------------------------------------------
  // RENDEZ-VOUS
  // ---------------------------------------------------------------------

  /// Tous les rendez-vous du patient, TOUTES dates et TOUS statuts
  /// confondus, triés du plus ancien au plus récent.
  ///
  /// On filtre sur "patientUid", l'uid du COMPTE, et non sur "patientId",
  /// l'id du document "patients". Ce n'est pas un détail : un document créé
  /// avec .add() reçoit un id tiré au sort, qui n'est jamais l'uid. Et les
  /// règles de sécurité ne peuvent pas suivre un .get() sur la collection
  /// "patients" depuis une requête : Firestore refuse alors la requête
  /// entière. En portant l'uid dans le rendez-vous, la règle
  /// "resource.data.patientUid == request.auth.uid" est vérifiable sur la
  /// requête, et un patient ne peut ainsi voir que les siens.
  Future<List<RendezVous>> getRendezVous(String patientUid) async {
    final snapshot = await _db
        .collection('rendez_vous')
        .where('patientUid', isEqualTo: patientUid)
        .get();

    final liste = snapshot.docs.map(_versRendezVous).toList();
    liste.sort((a, b) => a.date.compareTo(b.date));
    return liste;
  }

  /// Ne garde que les rendez-vous de la journée en cours.
  ///
  /// Fonction statique et synchrone à dessein : l'appelant (le loader)
  /// possède déjà la liste complètechargée par getRendezVous, inutile de
  /// la faire relire à Firestone pour la filtrer.
  static List<RendezVous> filtreDuJour(List<RendezVous> tous) {
    final maintenant = DateTime.now();
    final debut = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final fin = debut.add(const Duration(days: 1));

    return tous
        .where((rdv) => !rdv.date.isBefore(debut) && rdv.date.isBefore(fin))
        .toList();
  }

  /// Calcule les quelques chiffres affichés sur l'accueil du patient.
  ///
  /// Comme filtreDuJour, on travaille sur la liste déjà chargée plutôt
  /// que d'interroger Firestore trois fois de plus.
  static Map<String, int> calculerStatistiques(List<RendezVous> tous) {
    final maintenant = DateTime.now();

    // Un rendez-vous "à venir" est encore dans le futur ET n'a pas été
    // refusé/annulé : en attente compte, car le patient attend la réponse
    // du médecin.
    final actifs = tous.where(
      (r) =>
          r.statut == StatutRendezVous.enAttente ||
          r.statut == StatutRendezVous.confirme,
    );

    return {
      'rdvAujourdhui': filtreDuJour(tous).length,
      'enAttente': tous.where((r) => r.statut == StatutRendezVous.enAttente).length,
      'aVenir': actifs.where((r) => !r.date.isBefore(maintenant)).length,
    };
  }

  /// Demande un nouveau rendez-vous.
  ///
  /// Le rendez-vous naît toujours en "en_attente" : le patient ne peut pas
  /// s'auto-confirmer, c'est le médecin qui accepte ou refuse (voir
  /// MedecinService.accepterRendezVous / refuserRendezVous). C'est le
  /// pendant côté patient de la décision "choix direct, avec validation".
  ///
  /// Deux écritures au lieu d'une : le rendez-vous, puis son occupation de
  /// créneau dans "creneaux_occupes" (cf. getHeuresOccupees). Si la seconde
  /// échoue, on annule la première : un rendez-vous sans créneau réservé
  /// laisserait l'heure affichée comme libre alors qu'elle est prise.
  Future<void> demanderRendezVous({
    required Patient patient,
    required Medecin medecin,
    required DateTime date,
    required String heure,
    String? motif,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('Aucun utilisateur connecté');
    }

    final ref = await _db.collection('rendez_vous').add({
      // Identifiant du DOSSIER, celui du document "patients". Sert aux
      // secrétaires et aux médecins, qui naviguent par dossier.
      'patientId': patient.id,
      // Identifiant du COMPTE. C'est celui-ci que le patient filtre pour
      // relire ses rendez-vous, et celui que vérifient les règles.
      'patientUid': uid,
      'patientNom': patient.nom,
      'patientPrenom': patient.prenom,
      'medecinId': medecin.id,
      // On fige le nom du médecin dans le document : l'écran du patient
      // l'affiche sans avoir à refaire une requête sur "users".
      'medecinNom': medecin.nomComplet,
      // Le rendez-vous appartient à l'hôpital du MÉDECIN choisi. C'est le
      // seul endroit de l'application où un hôpital est rattaché à un
      // patient : le patient lui-même n'appartient à aucun établissement,
      // puisqu'il le choisit à chaque réservation.
      'hopitalId': medecin.hopitalId,
      'date': Timestamp.fromDate(date),
      'heure': heure,
      'statut': 'en_attente',
      if (motif != null) 'motif': motif,
    });

    try {
      await _creneaux.reserver(
        rdvId: ref.id,
        medecinId: medecin.id,
        date: date,
        heure: heure,
      );
    } catch (e) {
      await ref.delete();
      rethrow;
    }
  }

  /// Annule un rendez-vous (change son statut). Utilisé par le patient.
  ///
  /// La règle métier est vérifiée ici, pas seulement dans l'écran : le
  /// patient n'a le droit d'annuler que tant que le rendez-vous est en
  /// attente de confirmation (cf. RendezVous.modifiableParPatient). Une fois
  /// confirmé par la secrétaire ou le médecin, l'annulation doit passer par
  /// elle.
  Future<void> annulerRendezVous(String rdvId, {String? motif}) async {
    final ref = _db.collection('rendez_vous').doc(rdvId);
    final avant = await ref.get();
    final data = avant.data();
    if (data == null) {
      throw Exception('Ce rendez-vous n\'existe plus');
    }
    _verifierModifiable(data);

    await ref.update({
      'statut': 'annule',
      if (motif != null) 'motifAnnulation': motif,
    });

    // Un créneau libéré n'est plus occupé : sans ça, l'heure annulée
    // resterait masquée pour tout le monde.
    await _creneaux.liberer(rdvId);
  }

  /// Reprogramme un rendez-vous existant.
  ///
  /// Le statut repart à "en_attente" ETANT DONNÉ que le rendez-vous n'était
  /// de toute façon pas encore confirmé (sinon l'appel est refusé, cf.
  /// RendezVous.modifiableParPatient) : la secrétaire aura à nouveau à
  /// confirmer. On conserve l'historique dans 'datePrecendente' et
  /// 'heurePrecedente' pour qu'elle voie ce qui a changé.
  Future<void> modifierRendezVous(
    String rdvId, {
    required DateTime date,
    required String heure,
    String? motif,
  }) async {
    final ref = _db.collection('rendez_vous').doc(rdvId);
    final avant = await ref.get();
    final data = avant.data();
    if (data == null) {
      throw Exception('Ce rendez-vous n\'existe plus');
    }

    _verifierModifiable(data);

    final ancienneDate = data['date'];
    await ref.update({
      'date': Timestamp.fromDate(date),
      'heure': heure,
      // Le RDV n'ayant pas encore été accepté, il redevient "en_attente"
      // pour repasser dans la file de validation de la secrétaire.
      'statut': 'en_attente',
      if (motif != null) 'motif': motif,
      'datePrecendente':
          ancienneDate is Timestamp ? ancienneDate : FieldValue.delete(),
      'heurePrecedente': data['heure'] ?? FieldValue.delete(),
      // Horodatage de la reprogrammation : permet d'afficher "reprogrammé
      // le ..." dans le détail côté secrétaire.
      'modifieLe': Timestamp.fromDate(DateTime.now()),
    });

    // L'occupation suit la reprogrammation : on déplace la réservation du
    // créneau dans "creneaux_occupes", sinon l'ancien reste bloqué et le
    // nouveau reste affiché comme libre.
    await _creneaux.deplacer(
      rdvId: rdvId,
      medecinId: (data['medecinId'] ?? '').toString(),
      date: date,
      heure: heure,
    );
  }

  /// Refuse l'annulation ou la reprogrammation si le rendez-vous n'est plus
  /// dans l'état où le patient en a le droit.
  ///
  /// On s'appuie sur le statut stocké plutôt que sur le modèle : c'est la
  /// donnée fraîche de Firestore qui fait foi, le modèle reçu par l'écran
  /// pouvant dater d'avant une confirmation.
  void _verifierModifiable(Map<String, dynamic> data) {
    final statut = (data['statut'] ?? '').toString();
    if (statut == 'confirme') {
      throw Exception(
        'Ce rendez-vous a été accepté : demandez à la secrétaire de '
        'l\'annuler ou de le reporter.',
      );
    }
    if (statut == 'annule' || statut == 'refuse' || statut == 'termine') {
      throw Exception('Ce rendez-vous ne peut plus être modifié');
    }
    final horodatage = data['date'];
    if (horodatage is Timestamp &&
        _instantReel(horodatage.toDate(), data['heure'])
            .isBefore(DateTime.now())) {
      throw Exception('Un rendez-vous passé ne peut plus être modifié');
    }
  }

  /// Réunit le jour (minuit) et l'heure stockée à part, comme le fait
  /// RendezVous.dateHeure. Dupliqué ici parce qu'on raisonne sur le document
  /// Firestore brut, pas sur un modèle déjà construit.
  static DateTime _instantReel(DateTime jour, Object? heure) {
    final morceaux = (heure ?? '').toString().split(':');
    final h = morceaux.isNotEmpty ? (int.tryParse(morceaux[0]) ?? 0) : 0;
    final m = morceaux.length > 1 ? (int.tryParse(morceaux[1]) ?? 0) : 0;
    return DateTime(jour.year, jour.month, jour.day, h, m);
  }

  // ---------------------------------------------------------------------
  // Méthodes privées : traduction document Firestore → modèle Dart
  // ---------------------------------------------------------------------

  /// Traduit un document de la collection "patients" en objet Patient.
  ///
  /// Aucun aller-retour supplémentaire ici : le patient n'étant rattaché à
  /// aucun hôpital, il n'y a plus de nom d'hôpital à résoudre (l'ancien code
  /// faisait une lecture ciblée de "hopitaux" à chaque connexion, pour rien).
  Future<Patient> _versPatient(DocumentSnapshot doc, {String? email}) async {
    final data = doc.data() as Map<String, dynamic>;

    return Patient.fromJson({
      'id': doc.id,
      'nom': data['nom'],
      'prenom': data['prenom'],
      'telephone': data['telephone'],
      // Absent pour une auto-inscription : reste null (cf. Patient.hopitalId).
      'hopital_id': data['hopitalId'],
      // L'email est prioritairement celui du compte Auth (toujours à jour,
      // et non modifiable par le patient), celui du document en repli.
      'email': email ?? data['email'] ?? '',
      'user_id': data['userId'],
      // On ne convertit le Timestamp en texte ISO QUE s'il existe, sinon
      // Patient.fromJson recevrait un texte "null" invalide.
      'date_naissance': data['dateNaissance'] != null
          ? (data['dateNaissance'] as Timestamp).toDate().toIso8601String()
          : null,
      'groupe_sanguin': data['groupeSanguin'],
    });
  }

  /// Traduit un document de la collection "rendez_vous" en objet
  /// RendezVous. Même traduction camelCase (Firestore) → snake_case
  /// (modèle) que dans MedecinService et SecretaireService.
  RendezVous _versRendezVous(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RendezVous.fromJson({
      'id': doc.id,
      'patient_nom': data['patientNom'],
      'patient_prenom': data['patientPrenom'],
      // Timestamp → DateTime → texte ISO, format lu par fromJson.
      'date': (data['date'] as Timestamp).toDate().toIso8601String(),
      'heure': data['heure'],
      'statut': data['statut'],
      'motif': data['motif'],
      'medecin_id': data['medecinId'],
      'medecin_nom': data['medecinNom'],
      'hopital_id': data['hopitalId'],
    });
  }
}
