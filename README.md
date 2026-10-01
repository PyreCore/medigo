# Medigo — Application mobile de gestion hospitalière

Application mobile **Flutter** pour la gestion hospitalière : prise de rendez-vous en ligne pour les patients, gestion des créneaux par les médecins, accueil et administration par les secrétaires et les administrateurs. Construite avec **Firebase** pour l'authentification et les données.

> Projet en cours de développement (v1).

## Fonctionnalités

| Module | Rôle |
| --- | --- |
| `lib/shared/screens/accueil_public_screen.dart` | Accueil public : présentation, hôpitaux et catalogue des spécialités, sans compte |
| `lib/shared/screens/inscription_patient_screen.dart` | Inscription d'un patient (création du compte puis du dossier) |
| `lib/patient/` | Espace patient : mes rendez-vous, demander / annuler / modifier un rendez-vous, profil |
| `lib/secretaire/` | Espace secrétaire : dossier patients, confirmation et programmation des rendez-vous |
| `lib/medecin/screens/disponibilites_medecin.dart` | Déclaration des disponibilités, converties en créneaux réservables |
| `lib/medecin/` | Espace médecin : rendez-vous du jour, acceptation / refus |
| `lib/admin/` | Tableau de bord administrateur : gestion des hôpitaux et des spécialités |
| `lib/adminHopital/` | Tableau de bord de l'administrateur d'un hôpital |
| `lib/models/`, `lib/services/` | Modèles Firestore et accès aux données par espace |
| `lib/widgets/` | Cartes d'affichage partagées (patient, rendez-vous) |
| `lib/shared/screens/routage_role.dart` | Dispatch centralisé « rôle Firestore → écran d'accueil » |
| `lib/main.dart` | Point d'entrée + routes (`/`, `/login`) |

## Technologies

- **Flutter** (Dart) — application multi-plateforme (Android, iOS, web, desktop)
- **Firebase** — initialisation (`firebase_options.dart`), authentification et base de données (`firebase.json`)
- **cloud_firestore** — données ; **flutter_local_notifications** + **timezone** — rappels de rendez-vous locaux

## Rôles et comptes

Le rôle est stocké dans le champ `role` du document `users/<uid>`, et dispatché par `RoutageRole.ecranPourRole` :

| Rôle | Comment le compte est obtenu |
| --- | --- |
| `patient` | Inscription depuis l'écran de connexion |
| `medecin`, `secretaire`, `adminHopital`, `adminSysteme` | Créés par un administrateur |

Seul le patient s'inscrit seul : les autres comptes supposent qu'un administrateur a renseigné l'`hopitalId` du médecin ou du secrétaire.

## Structure

```
lib/
├── main.dart                    # Démarrage + routes
├── firebase_options.dart        # Configuration Firebase
├── models/                      # Disponibilite, Medecin, Patient, RendezVous, Specialite
├── services/                    # Accès Firestore par espace + notifications
│   ├── creneau_service.dart     # Créneaux et heures déjà réservées
│   ├── disponibilite_service.dart
│   ├── notification_service.dart
│   └── …
├── patient/screens/             # Espace patient
├── secretaire/screens/          # Espace secrétaire
├── medecin/screens/             # Espace médecin
├── admin/screens/               # Administration globale
├── adminHopital/screens/        # Administration d'un hôpital
├── widgets/                     # PatientCard, RendezVousCard
└── shared/                      # Écrans, modèles et services communs
    ├── screens/                 # Accueil public, connexion, inscription, routage
    └── models/hopital_model.dart
```

## Démarrage

```bash
# Récupérer les dépendances
flutter pub get

# Déployer les règles de sécurité et les index (voir ci-dessous)
firebase deploy --only firestore:rules,firestore:indexes

# Lancer l'application
flutter run
```

## Firestore

Collections utilisées : `users`, `hopitaux`, `specialites`, `medecins`, `patients`, `disponibilites`, `rendez_vous`, `creneaux_occupes`.

- **`firestore.rules`** — un patient ne lit que les documents `role == 'medecin'` de `users`, et n'accède qu'au dossier `patients` dont le champ `userId` vaut son `uid`. Les rendez-vous sont rattachés au compte via `patientUid` : vérifier l'appartenance par un `get()` sur `patients` ne fonctionne pas depuis une requête, Firestore refusant alors la requête entière.
- **`firestore.indexes.json`** — index composites sur `users(role, hopitalId)`, `rendez_vous(hopitalId|medecinId, statut)` et `creneaux_occupes(medecinId, date)`.
- **`creneaux_occupes`** — collection dédiée aux heures réservées, sans donnée personnelle. Elle remplace la lecture de tous les rendez-vous d'un médecin pour calculer les heures prises, ce qui exposait le patient au nom et au motif de consultation des autres.

> Les règles et les index **ne sont pas versionnés à leur déploiement** : sans `firebase deploy`, les requêtes de l'espace Patient échouent en `permission-denied` ou `failed-precondition`.

## Rappels de rendez-vous

`NotificationService` programme deux rappels par rendez-vous à venir : **la veille à 8 h** et **une heure avant**. Ils sont reprogrammés à chaque chargement de l'espace patient et annulés à la déconnexion, pour qu'un rendez-vous annulé disparaisse du lot.

Les rappels utilisent une alarme **imprécise** : aucune permission `SCHEDULE_EXACT_ALARM` n'est demandée, que Google Play n'accorde qu'aux applications de type calendrier ou alarme. Côté Android, `flutter_local_notifications` impose le *desugaring* de `java.time` (`isCoreLibraryDesugaringEnabled` dans `android/app/build.gradle.kts`) et `RECEIVE_BOOT_COMPLETED` pour reprogrammer les rappels après un redémarrage.

## Tests

```bash
flutter test
flutter analyze   # ne doit remonter que des info
```

14 tests passent. `test/widget_test.dart` échoue : c'est le compteur de démonstration laissé par `flutter create`, jamais adapté à l'application.

## Notes

- Nécessite Flutter SDK et un projet Firebase configuré (`firebase.json`, `firebase_options.dart`).
- `Hopital`, `Medecin` et `Specialite` définissent `operator ==` et `hashCode` sur leur `id`. Sans quoi Dart compare par identité, chaque relecture de Firestore crée de nouveaux objets, et un `DropdownButton` conservant l'ancien exemplaire ne retrouve plus aucun item portant sa valeur — plantage assuré dans le formulaire de rendez-vous.
- `firestore.rules` contient encore un bloc `match /rendezvous` (sans tiret bas) hérité d'une ancienne convention de nommage. L'application n'écrit que dans `rendez_vous` : ce bloc est inactif et peut être supprimé.
- Le README par défaut de Flutter a été remplacé par le présent document ; voir `pubspec.yaml` pour le descriptif technique (package `hopital_app`).
