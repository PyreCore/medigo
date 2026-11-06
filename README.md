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

Au 6 novembre 2026 : **65 tests passent**, `flutter analyze` ne remonte **aucune erreur ni avertissement** (17 remarques de niveau info, voir [Remarques d'analyse restantes](#remarques-danalyse-restantes)).

## Organisation du travail

Projet de groupe : chaque membre a la charge d'un ou plusieurs espaces de l'application.

| Membre (identifiant Git) | Partie | Commits |
| --- | --- | --- |
| **chris2007-t** | Configuration Firebase, espaces Administrateur système et Administrateur d'hôpital, connexion | 15 |
| **joworst-boy** | Espaces Médecin et Secrétaire (fonctions, notifications, responsive, design) | 11 |
| **Andem** | Première version des espaces Médecin et Secrétaire | 1 |
| **mvp** / **etoumbi9** | Espace Patient, accueil public, inscription, règles Firestore, rappels, README | 6 |

> `mvp` et `etoumbi9` désignent le même membre, qui a commité depuis deux configurations Git différentes.

### Répartition par dossier

| Dossier | Responsable principal |
| --- | --- |
| `lib/admin/`, `lib/adminHopital/` | chris2007-t |
| `lib/medecin/`, `lib/secretaire/`, `lib/theme/` | joworst-boy (base posée par Andem) |
| `lib/patient/`, `lib/services/patient_service.dart`, `firestore.rules`, `firestore.indexes.json` | mvp / etoumbi9 |
| `lib/shared/`, `lib/models/`, `lib/widgets/` | partagés (modifiés par plusieurs membres) |

### Historique des commits

Les heures sont celles des auteurs. Les commits de fusion (*merge*) sont signalés mais n'apportent pas de code nouveau.

#### Septembre 2026 — Mise en place

| Date | Auteur | Commit | Contenu |
| --- | --- | --- | --- |
| 15/09 20:52 | chris2007-t | `31a0b7a` | **Configuration de la base de données** : création du projet Flutter (toutes plateformes) et branchement Firebase (`google-services.json`). |
| 22/09 07:50 | chris2007-t | `0c80722` | **Envoi de l'admin** : premiers écrans de `lib/admin/screens/` (4 fichiers). |
| 22/09 07:54 | chris2007-t | `ccc45e8` | **Envoi partie médecin** : premier écran de l'espace médecin. |
| 22/09 07:56 | chris2007-t | `b955247` | **Modification de `main.dart`** : retrait du code de démonstration Flutter. |
| 22/09 07:58 | chris2007-t | `6e8e85b` | **Administration des hôpitaux** : tableau de bord de `lib/adminHopital/`. |
| 22/09 08:00 | chris2007-t | `eae86d4` | **Dossier `shared`** : modèle Hôpital, écran de connexion et service Firestore communs. |
| 24/09 11:42 | Andem | `b11ce17` | **Parties médecin et secrétaire** : écrans médecin et secrétaire, modèles (`models/`), services et cartes (`widgets/`), 30 fichiers. |
| 25/09 09:40 | etoumbi9 | `f0838b6` | **README** : remplace le README par défaut de Flutter. |
| 25/09 20:54 | joworst-boy | `f75d4e4` | **Fichier qui gênait chris** : retrait de 2 lignes en conflit dans `lib/widgets/`. |
| 25/09 21:08 | chris2007-t | `a9592e2` | *Fusion* : garde la version admin de l'écran de connexion. |
| 25/09 21:38 | joworst-boy | `066cbd1` | **Espaces médecin/secrétaire complets** et correction d'un problème d'index Firestore. |
| 25/09 21:42 | joworst-boy | `536fad4` | *Fusion* de `master`. |
| 25/09 21:53 | joworst-boy | `f65d629` | **Connexion médecin/secrétaire** : chaque rôle arrive sur le bon écran, ajout de la branche secrétaire. |

#### Octobre 2026 — Espaces Patient, Médecin et Secrétaire

| Date | Auteur | Commit | Contenu |
| --- | --- | --- | --- |
| 01/10 15:33 | mvp | `16f57c4` | **Espace Patient : plus de plantage sur la sélection d'hôpital ou de médecin**. `operator ==` et `hashCode` sur l'id pour Hôpital, Médecin et Spécialité ; le médecin est désélectionné s'il sort du filtre de recherche ; tests associés. |
| 01/10 15:39 | mvp | `19d1b07` | **README** : décrit l'espace Patient, les rôles, les collections Firestore, les rappels et les tests. |
| 01/10 15:48 | mvp | `2b9e920` | **Règles de sécurité et index Firestore** : un patient ne lit que les médecins et son propre dossier ; collection `creneaux_occupes` sans donnée personnelle ; index composites. |
| 01/10 15:48 | mvp | `83c3653` | **Espace Patient sur de vrais créneaux** : modèles Créneau et Spécialité, services Créneau / Disponibilité / Patient, écrans « mes rendez-vous », prise et modification de rendez-vous, profil ; libération du créneau à l'annulation ; tests. |
| 01/10 15:48 | mvp | `9fc49f3` | **Accueil public, inscription patient et rappels** : écran d'accueil sans compte, inscription patient, `RoutageRole`, déconnexions vers l'accueil, rappels la veille à 8 h et une heure avant. |
| 01/10 21:25 | joworst-boy | `2725884` | **Revue de la structure des espaces médecin et secrétaire** (28 fichiers). |
| 01/10 23:03 | joworst-boy | `d584684` | *Fusion* : synchronisation des versions. |
| 11/10 13:39 | joworst-boy | `c0e75ee` | **Notifications et synchronisation** des informations entre les espaces médecin et secrétaire. |
| 17/10 01:08 | joworst-boy | `0709b53` | **Interface responsive** médecin et secrétaire, avec tests de mise en page à 4 largeurs d'écran. |
| 17/10 03:35 | joworst-boy | `bcafe27` | **Design médecin et secrétaire** : création de `lib/theme/`. |
| 17/10 15:15 | joworst-boy | `c4cc99b` | **Amélioration du design** de l'espace médecin et secrétaire. |
| 23/10 14:23 | joworst-boy | `7cf918e` | **Design maquette** : navigation en dégradé, formulaires validés, filtres de l'espace médecin. |
| 26/10 19:34 | chris2007-t | `35094bd` | **Espaces admin en violet**, page profil, règles de mot de passe, correction des fenêtres invisibles. |

#### Novembre 2026 — Navigation et messages d'erreur

| Date | Auteur | Commit | Contenu |
| --- | --- | --- | --- |
| 05/11 10:09 | chris2007-t | `e925cda` | **Bouton retour** depuis un espace : ramène à l'écran de connexion (mobile). |
| 05/11 10:25 | chris2007-t | `4198e75` | **Retour = déconnexion** : quitter un espace ferme la session. |
| 05/11 11:25 | chris2007-t | `6907fbe` | **Espaces admin** : l'erreur (ex. email déjà utilisé) est affichée au lieu d'être ignorée. |
| 05/11 11:30 | chris2007-t | `017b5f2` | **Admin système mobile** : « Retour à l'accueil » déconnecte la session. |
| 05/11 11:42 | chris2007-t | `4f763d2` | **Erreur en rouge dans la fenêtre** lors de la création de comptes. |
| 05/11 11:52 | chris2007-t | `aff9dda` | **Ajout d'hôpital et inscription patient** : erreurs affichées en rouge dans le formulaire. |
| 05/11 12:04 | chris2007-t | `408ccf8` | **Ajout d'hôpital** : vérifie si l'email est déjà utilisé ; corrige un `setState` qui recevait une `Future` dans `_rafraichirStats`. |

### Remarques d'analyse restantes

Le 6 novembre 2026, les remarques `flutter analyze` de la partie Patient ont été corrigées (`withOpacity` → `withValues` dans `lib/patient/screens/`, syntaxe `'clé': ?valeur` dans `patient_service.dart`). Les 17 remarques restantes concernent les parties des autres membres et leur sont laissées :

| Remarque | Fichiers | Responsable | Correction proposée |
| --- | --- | --- | --- |
| `use_build_context_synchronously` (11) | `admin_dashboard.dart`, `gestion_hopitaux.dart`, `gestion_specialites.dart`, `hopital_detail_screen.dart`, `admin_hopital_dashboard.dart` | chris2007-t | Dans les boîtes de dialogue, remplacer `if (mounted)` par `if (context.mounted)` avant `Navigator.pop(context)` : `mounted` teste l'écran parent, pas la boîte de dialogue. |
| `value` obsolète sur `DropdownButtonFormField` (4) | `admin_dashboard.dart`, `hopital_detail_screen.dart`, `admin_hopital_dashboard.dart` | chris2007-t | Remplacer `value:` par `initialValue:`, en vérifiant les listes qui dépendent d'un autre choix. |
| `withOpacity` obsolète (2) | `lib/widgets/patient_card.dart` (utilisé par l'espace secrétaire) | joworst-boy | Remplacer par `.withValues(alpha: …)`. |

## Notes

- Nécessite Flutter SDK et un projet Firebase configuré (`firebase.json`, `firebase_options.dart`).
- `Hopital`, `Medecin` et `Specialite` définissent `operator ==` et `hashCode` sur leur `id`. Sans quoi Dart compare par identité, chaque relecture de Firestore crée de nouveaux objets, et un `DropdownButton` conservant l'ancien exemplaire ne retrouve plus aucun item portant sa valeur — plantage assuré dans le formulaire de rendez-vous.
- `firestore.rules` contient encore un bloc `match /rendezvous` (sans tiret bas) hérité d'une ancienne convention de nommage. L'application n'écrit que dans `rendez_vous` : ce bloc est inactif et peut être supprimé.
- Le README par défaut de Flutter a été remplacé par le présent document ; voir `pubspec.yaml` pour le descriptif technique (package `hopital_app`).
