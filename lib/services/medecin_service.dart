// On importe le package officiel qui permet de parler à Firestore
// (la base de données de Firebase) depuis Flutter.
import 'package:cloud_firestore/cloud_firestore.dart';
// Ajouté pour pouvoir récupérer l'uid de l'utilisateur actuellement
// connecté (FirebaseAuth.instance.currentUser), comme le fait déjà
// l'Étudiant 3 dans medecin_dashboard.dart.
import 'package:firebase_auth/firebase_auth.dart';
// On importe nos propres modèles, définis dans d'autres fichiers.
// Le chemin "../models/..." veut dire "remonte d'un dossier, puis va dans models".
import '../models/medecin.dart';
import '../models/rendez_vous.dart';

/// Un "service" regroupe toute la logique qui va chercher/écrit des
/// données dans Firestore pour la partie Médecin. Les écrans (screens)
/// ne parlent jamais directement à Firestore : ils passent toujours
/// par ce service. Ça sépare "l'affichage" (screens) de "l'accès aux
/// données" (services), ce qui rend le code plus facile à maintenir.
class MedecinService {
  // On récupère l'instance unique de Firestore fournie par le SDK Firebase.
  // "_db" est privé (le underscore _ devant le nom) : utilisable seulement
  // à l'intérieur de cette classe, pas depuis l'extérieur.
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // "Future<Medecin>" veut dire : cette fonction est ASYNCHRONE, elle
  // ne retourne pas un Medecin immédiatement (interroger Firestore prend
  // du temps, c'est une requête réseau), mais une "promesse" de Medecin
  // qui sera prête plus tard. "async" active le mot-clé "await" en dessous.
  //
  // Choix d'architecture aligné avec l'Étudiant 3 (17/09) : une SEULE
  // collection Firestore "users" regroupe tous les rôles (patient,
  // médecin, secrétaire...), chaque document étant identifié par l'uid
  // Firebase Auth. On ne garde donc plus de collection "medecins" à part.
  // Ce choix est provisoire tant que l'équipe ne l'a pas confirmé, mais
  // on s'aligne dessus pour rester compatible avec ce qui est déjà poussé.
  Future<Medecin> getProfil(String medecinId) async {
    // .collection('users') = LA collection unique pour tous les comptes.
    // .doc(medecinId) = ici, medecinId est en fait l'uid Firebase Auth
    // du médecin connecté (ex: FirebaseAuth.instance.currentUser!.uid).
    final doc = await _db.collection('users').doc(medecinId).get();

    // ".exists" est vrai si un document avec cet id existe réellement
    // dans Firestore (l'id pourrait être invalide/périmé).
    if (!doc.exists) {
      // "throw" déclenche une erreur qui remonte à l'écran appelant,
      // pour qu'il puisse par exemple afficher un message à l'utilisateur.
      throw Exception('Médecin introuvable');
    }

    // doc.data()! récupère le contenu du document sous forme de Map.
    // Le "!" dit à Dart "je suis sûr que ce n'est pas null, fais-moi confiance"
    // (on peut se le permettre ici car on vient de vérifier doc.exists).
    // "{'id': doc.id, ...doc.data()!}" construit un nouveau Map qui contient
    // l'id du document PLUS tous les champs du document (le "..." étale
    // le contenu d'un Map dans un autre, comme un copier-coller).
    // On passe ce Map à notre constructeur Medecin.fromJson vu plus tôt.
    return Medecin.fromJson({'id': doc.id, ...doc.data()!});
  }

  /// Raccourci pratique : récupère directement le profil du médecin
  /// ACTUELLEMENT CONNECTÉ, sans avoir à connaître son id à l'avance.
  /// Utile au démarrage de l'app, juste après la connexion.
  Future<Medecin> getProfilConnecte() async {
    // FirebaseAuth.instance.currentUser donne l'utilisateur Firebase
    // actuellement connecté sur cet appareil, ou null si personne n'est
    // connecté.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Aucun utilisateur connecté');
    }
    // "user.uid" est l'identifiant unique de ce compte, qui correspond
    // exactement à l'id du document dans la collection "users".
    return getProfil(user.uid);
  }

  /// Récupère les rendez-vous du médecin pour la date d'aujourd'hui,
  /// triés par heure.
  Future<List<RendezVous>> getRendezVousDuJour(String medecinId) async {
    // DateTime.now() donne la date et l'heure actuelles exactes
    // (ex: 17 septembre 2026, 14h32min07s).
    final debutJour = DateTime.now();

    // On construit "minuit aujourd'hui" en ne gardant que année/mois/jour
    // (on ignore heure/minute/seconde, qui valent 0 par défaut si omis).
    final debut = DateTime(debutJour.year, debutJour.month, debutJour.day);

    // "minuit demain" = minuit aujourd'hui + 1 jour.
    // Ça nous donne un intervalle [debut, fin[ qui couvre toute la journée.
    final fin = debut.add(const Duration(days: 1));

    // On interroge Firestore avec plusieurs conditions enchaînées (une requête).
    final snapshot = await _db
        .collection('rendez_vous')
        // On ne garde que les documents où le champ medecinId correspond
        // au médecin demandé (chaque médecin ne voit que SES rendez-vous).
        .where('medecinId', isEqualTo: medecinId)
        // On ne garde que les rendez-vous dont la date est >= début de journée...
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(debut))
        // ...ET strictement < début du jour suivant (donc dans la journée).
        // Timestamp.fromDate() convertit un DateTime Dart au format que
        // Firestore comprend et stocke en base.
        .where('date', isLessThan: Timestamp.fromDate(fin))
        // On trie les résultats par date croissante (les plus tôt en premier).
        .orderBy('date')
        // .get() exécute réellement la requête et télécharge les résultats.
        .get();

    // snapshot.docs est la liste des documents trouvés.
    // .map(...) transforme CHAQUE document en un objet RendezVous,
    // un peu comme une "traduction" appliquée à toute la liste d'un coup.
    return snapshot.docs.map((doc) {
      // Pour chaque document, on récupère ses champs sous forme de Map.
      final data = doc.data();

      // On construit un RendezVous à partir de ces champs, en adaptant
      // les noms/formats Firestore vers ce qu'attend RendezVous.fromJson.
      return RendezVous.fromJson({
        'id': doc.id,
        'patient_nom': data['patientNom'],
        'patient_prenom': data['patientPrenom'],

        // Le champ "date" est stocké comme un Timestamp Firestore.
        // .toDate() le reconvertit en DateTime Dart, puis
        // .toIso8601String() le transforme en texte (ex: "2026-09-17T09:00:00"),
        // car c'est ce format texte que RendezVous.fromJson sait lire
        // (elle appelle DateTime.parse dessus, comme vu dans le modèle).
        'date': (data['date'] as Timestamp).toDate().toIso8601String(),

        'heure': data['heure'],
        'statut': data['statut'],
        'motif': data['motif'],
      });
      // .toList() transforme le résultat de .map() (une "Iterable" paresseuse)
      // en une vraie List<RendezVous> exploitable normalement.
    }).toList();
  }

  /// Calcule quelques statistiques simples pour le tableau de bord.
  Future<Map<String, int>> getStatistiques(String medecinId) async {
    // On réutilise la fonction déjà écrite au-dessus plutôt que de
    // dupliquer la requête : moins de code, moins de bugs possibles.
    final rdvAujourdhui = await getRendezVousDuJour(medecinId);

    // Deuxième requête Firestore : tous les rendez-vous "en_attente"
    // de ce médecin, peu importe la date (pas de filtre sur "date" ici).
    final enAttenteSnapshot = await _db
        .collection('rendez_vous')
        .where('medecinId', isEqualTo: medecinId)
        .where('statut', isEqualTo: 'en_attente')
        .get();

    // Troisième requête : TOUS les rendez-vous de ce médecin (toutes dates,
    // tous statuts confondus), pour ensuite compter les patients distincts.
    final patientsSnapshot = await _db
        .collection('rendez_vous')
        .where('medecinId', isEqualTo: medecinId)
        .get();

    // .map() extrait juste le champ patientId de chaque document.
    // .toSet() transforme la liste en un "ensemble" : les doublons sont
    // automatiquement supprimés (un Set ne peut pas contenir 2 fois la
    // même valeur). .length compte combien il en reste : le nombre de
    // patients DIFFÉRENTS suivis par ce médecin.
    final patientsUniques = patientsSnapshot.docs
        .map((d) => d.data()['patientId'])
        .toSet()
        .length;

    // On retourne un Map (dictionnaire clé → valeur) avec les 3 chiffres
    // dont le tableau de bord a besoin.
    return {
      'rdvAujourdhui': rdvAujourdhui.length,
      'enAttente': enAttenteSnapshot.docs.length,
      'patientsSuivis': patientsUniques,
    };
  }

  /// Accepte un rendez-vous (change son statut).
  // "Future<void>" = fonction asynchrone qui ne renvoie aucune valeur utile,
  // elle fait juste une action (ici : modifier un document).
  Future<void> accepterRendezVous(String rdvId) async {
    // .update() modifie SEULEMENT les champs indiqués dans le Map,
    // sans toucher au reste du document (contrairement à .set() qui
    // remplacerait tout le document).
    await _db.collection('rendez_vous').doc(rdvId).update({
      'statut': 'confirme',
    });
  }

  /// Refuse un rendez-vous (change son statut).
  // "{String? motif}" = paramètre nommé optionnel : on peut appeler
  // refuserRendezVous('abc') seul, ou refuserRendezVous('abc', motif: '...').
  Future<void> refuserRendezVous(String rdvId, {String? motif}) async {
    await _db.collection('rendez_vous').doc(rdvId).update({
      'statut': 'refuse',
      // "if (motif != null) 'motifRefus': motif," est une syntaxe Dart
      // spéciale : cette entrée n'est ajoutée au Map QUE SI motif n'est
      // pas null. Si aucun motif n'est fourni, le champ motifRefus
      // n'est simplement pas envoyé à Firestore.
      if (motif != null) 'motifRefus': motif,
    });
  }
}
