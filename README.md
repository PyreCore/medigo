# Medigo — Application mobile de gestion hospitalière

Application mobile **Flutter** pour la gestion hospitalière : prise de rendez-vous en ligne pour les patients, gestion des créneaux par les médecins, accueil et administration par les secrétaires et les administrateurs. Construite avec **Firebase** pour l'authentification et les données.

> Projet en cours de développement (v1).

## Fonctionnalités

| Module | Rôle |
| --- | --- |
| `lib/patient/screens/espace_patient_visiteur.dart` | Premier écran : espace Patient en mode visiteur, utilisable sans compte (hôpitaux, recherche, spécialités) ; la réservation demande une connexion |
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

## Mode visiteur (sans connexion)

Au lancement, l'application s'ouvre directement sur **l'espace Patient en mode visiteur** (`EspacePatientVisiteur`), avec la même barre de navigation que l'espace connecté :

| Onglet | Visiteur (non connecté) |
| --- | --- |
| **Accueil** | Bienvenue, nombre d'hôpitaux et de spécialités, puces de spécialités (un appui affiche les hôpitaux qui la proposent), aperçu des hôpitaux |
| **Hôpitaux** | Recherche par nom, ville ou téléphone, filtre par spécialité, fiche de chaque hôpital (adresse, téléphone, email, spécialités et médecins) |
| **Prendre RDV** | Le vrai formulaire : hôpital, spécialité, recherche de médecin, date et créneaux libres. Seul l'envoi demande un compte |
| **Profil** | « Visiteur » : connexion, inscription, et accès des professionnels (médecin, secrétaire, administrateur) |

Les boutons « Prendre rendez-vous », « Réserver » et « Réserver dans cet hôpital » ouvrent le formulaire, avec l'hôpital déjà choisi le cas échéant. Le visiteur peut tout consulter, jusqu'aux créneaux libres d'un médecin. Seul le bouton **« Envoyer ma demande »** passe par le contrôle `_exigerConnexion` : un visiteur voit la fenêtre « Connexion requise », un utilisateur déjà connecté est envoyé vers son espace.

Le visiteur ne lit que les collections ouvertes en lecture anonyme par `firestore.rules` : `hopitaux`, `specialites`, `disponibilites`, `creneaux_occupes` et `medecins`. Les médecins viennent de `medecins` (`PatientService.getMedecinsPublics`) et non de `users`, réservée aux comptes connectés. Seuls le nom, le prénom et la spécialité sont repris, et l'identifiant utilisé est `userId`, l'uid du compte du médecin, sous lequel sont rangées ses disponibilités. Un médecin sans `userId` dans `medecins` n'apparaît pas pour les visiteurs.

**Reprise de la réservation après connexion.** Quand le visiteur appuie sur « Envoyer ma demande », sa réservation (hôpital, médecin, date, créneau, motif) est gardée en mémoire par `ReservationEnAttente` (`lib/patient/reservation_en_attente.dart`). Après la connexion ou l'inscription, `PatientHomeLoader` la reprend : l'espace s'ouvre sur l'onglet « Prendre RDV », formulaire pré-rempli, et le patient n'a plus qu'à envoyer. L'écran de connexion n'est pas modifié.

- La réservation n'est reprise qu'**une fois**, et expire au bout de **30 minutes** : un téléphone partagé ne la propose pas au compte suivant. « Plus tard » l'efface.
- Le médecin et le créneau sont **revérifiés** à la reprise : si le créneau a été pris entre-temps, ou si le médecin n'exerce plus, un message le signale et seul ce choix est à refaire.
- Elle vit en mémoire seulement : fermer l'application l'efface.

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
    ├── screens/                 # Connexion, inscription, routage
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
flutter analyze   # doit afficher « No issues found! »
```

Au 6 novembre 2026 : **82 tests passent** et `flutter analyze` affiche **« No issues found! »** (voir [Nettoyage de l'analyse](#nettoyage-de-lanalyse-6-novembre-2026)).

## Organisation du travail

Projet de groupe : chaque membre a la charge d'un ou plusieurs espaces de l'application.

| Membre (identifiant Git) | Partie | Commits (au 6 novembre) |
| --- | --- | --- |
| **chris2007-t** | Configuration Firebase, espaces Administrateur système et Administrateur d'hôpital, connexion, site admin dédié | 17 |
| **joworst-boy** | Espaces Médecin et Secrétaire (fonctions, notifications, responsive, design) | 11 |
| **Andem** | Première version des espaces Médecin et Secrétaire | 1 |
| **mvp** / **etoumbi9** / **PyreCore** | Espace Patient (dont le mode visiteur), inscription, règles Firestore, rappels, README, nettoyage de l'analyse | 12 |

> `mvp`, `etoumbi9` et `PyreCore` désignent le même membre, qui a commité depuis plusieurs configurations Git différentes.

### Répartition par dossier

| Dossier | Responsable principal |
| --- | --- |
| `lib/admin/`, `lib/adminHopital/` | chris2007-t |
| `lib/medecin/`, `lib/secretaire/`, `lib/theme/` | joworst-boy (base posée par Andem) |
| `lib/patient/`, `lib/services/patient_service.dart`, `firestore.rules`, `firestore.indexes.json` | mvp / etoumbi9 |
| `lib/shared/`, `lib/models/`, `lib/widgets/` | partagés (modifiés par plusieurs membres) |

### Historique des commits

Les heures sont celles des auteurs. Les commits de fusion (*merge*) sont signalés mais n'apportent pas de code nouveau.

Historique arrêté au 6 novembre 2026. L'historique complet et toujours à jour se consulte sur GitHub : [github.com/PyreCore/medigo/commits/master](https://github.com/PyreCore/medigo/commits/master).


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

#### Novembre 2026 — Navigation, messages d'erreur, site admin et mode visiteur

| Date | Auteur | Commit | Contenu |
| --- | --- | --- | --- |
| 05/11 10:09 | chris2007-t | `e925cda` | **Bouton retour** depuis un espace : ramène à l'écran de connexion (mobile). |
| 05/11 10:25 | chris2007-t | `4198e75` | **Retour = déconnexion** : quitter un espace ferme la session. |
| 05/11 11:25 | chris2007-t | `6907fbe` | **Espaces admin** : l'erreur (ex. email déjà utilisé) est affichée au lieu d'être ignorée. |
| 05/11 11:30 | chris2007-t | `017b5f2` | **Admin système mobile** : « Retour à l'accueil » déconnecte la session. |
| 05/11 11:42 | chris2007-t | `4f763d2` | **Erreur en rouge dans la fenêtre** lors de la création de comptes. |
| 05/11 11:52 | chris2007-t | `aff9dda` | **Ajout d'hôpital et inscription patient** : erreurs affichées en rouge dans le formulaire. |
| 05/11 12:04 | chris2007-t | `408ccf8` | **Ajout d'hôpital** : vérifie si l'email est déjà utilisé ; corrige un `setState` qui recevait une `Future` dans `_rafraichirStats`. |
| 06/11 11:34 | PyreCore | `9a21ee1` | **Espace Patient : remarques d'analyse corrigées** (`withValues`, `'clé': ?valeur`) et section « Organisation du travail » du README. |
| 06/11 11:55 | PyreCore | `ff2913e` | **17 remarques d'analyse restantes corrigées** (espaces admin, `patient_card.dart`) : `flutter analyze` à zéro. |
| 06/11 12:02 | chris2007-t | `782b9fc` | **Site admin dédié** : second site Firebase Hosting (`medigo-f2fd5-admin.web.app`) et point d'entrée `lib/main_admin.dart`. |
| 06/11 12:28 | chris2007-t | `6306f5c` | **Connexion exclusive de l'admin système** sur le site dédié (`login_admin_systeme_screen.dart`), refusée sur le site public. |
| 06/11 12:32 | PyreCore | `06581ce` | **Mode visiteur** : l'application s'ouvre sur l'espace Patient sans connexion ; la réservation demande un compte. Remplace l'ancien accueil public. 9 tests ajoutés. |
| 06/11 12:35 | PyreCore | `0efa8cc` | **README** : historique à jour (site admin dédié, mode visiteur, heures et nombre de commits par membre). |
| 06/11 12:40 | PyreCore | `fb18eef` | **README** : ajout du commit `0efa8cc` à l'historique. |
| 06/11 12:45 | PyreCore | `2c666dd` | **Script `tool/historique.dart`** : historique et nombre de commits par membre générés depuis `git log`, descriptions existantes conservées (script retiré ensuite : GitHub affiche déjà l'historique). |


### Nettoyage de l'analyse (6 novembre 2026)

`flutter analyze` signalait **27 remarques**. Toutes ont été corrigées : il n'en reste **aucune**, et les 65 tests passent toujours.

**Pourquoi ces corrections étaient nécessaires :**

- **Risque de plantage dans les espaces d'administration (11 cas).** Les fenêtres de création de comptes (hôpital, admin d'hôpital, médecin, secrétaire) et de suppression d'hôpital vérifiaient le mauvais écran après l'enregistrement dans Firestore. Si la fenêtre était fermée pendant l'enregistrement (double clic, bouton retour, réseau lent), l'application pouvait **fermer le mauvais écran ou planter** au moment même où un administrateur crée un compte.
- **Risque que le projet entier ne compile plus (11 cas).** `value` sur les listes déroulantes et `withOpacity` sont obsolètes et annoncés comme supprimés dans une future version de Flutter. Sans correction, **une simple mise à jour de Flutter aurait empêché toute l'application de se construire**, pour tous les espaces.
- **Lisibilité (5 cas).** Code simplifié dans `patient_service.dart`, sans changement de comportement.

Aucune de ces remarques ne constituait une faille de sécurité : la protection des données repose sur `firestore.rules`, qui n'a pas été modifié.

| Remarque | Nb | Fichiers (partie) | Correction | Intérêt |
| --- | --- | --- | --- | --- |
| `use_build_context_synchronously` | 11 | `admin_dashboard.dart`, `gestion_hopitaux.dart`, `gestion_specialites.dart`, `hopital_detail_screen.dart`, `admin_hopital_dashboard.dart` (admin) | Après un `await` dans une boîte de dialogue : `if (context.mounted) Navigator.pop(context)` au lieu de `if (mounted)`. Le `setState` de l'écran reste protégé par `mounted`. | **Évite un vrai bug.** `mounted` vérifiait l'écran parent, pas la boîte de dialogue. Si celle-ci est fermée pendant l'enregistrement Firestore (double clic, bouton retour), `Navigator.pop` pouvait fermer le mauvais écran ou planter. |
| `value` obsolète sur `DropdownButtonFormField` | 4 | `admin_dashboard.dart`, `hopital_detail_screen.dart`, `admin_hopital_dashboard.dart` (admin) | `value:` → `initialValue:` | **Compatibilité future.** `value` est obsolète depuis Flutter 3.33 et sera supprimé : le projet ne compilerait plus après une mise à jour de Flutter. Le comportement est identique, car ces listes ne changent que par `onChanged`. |
| `withOpacity` obsolète | 7 | `lib/patient/screens/` (patient), `widgets/patient_card.dart` (secrétaire) | `couleur.withOpacity(x)` → `couleur.withValues(alpha: x)` | **Compatibilité future et précision.** La nouvelle API conserve la transparence sans arrondi. Le rendu est le même à l'écran. |
| `use_null_aware_elements` | 5 | `services/patient_service.dart` (patient) | `if (x != null) 'clé': x` → `'clé': ?x` | **Lisibilité.** Syntaxe Dart 3.8 plus courte, même résultat : le champ n'est envoyé à Firestore que s'il a une valeur. |

Garder `flutter analyze` à zéro remarque permet de repérer immédiatement tout nouveau problème introduit par un commit.

## Notes

- Nécessite Flutter SDK et un projet Firebase configuré (`firebase.json`, `firebase_options.dart`).
- `Hopital`, `Medecin` et `Specialite` définissent `operator ==` et `hashCode` sur leur `id`. Sans quoi Dart compare par identité, chaque relecture de Firestore crée de nouveaux objets, et un `DropdownButton` conservant l'ancien exemplaire ne retrouve plus aucun item portant sa valeur — plantage assuré dans le formulaire de rendez-vous.
- `firestore.rules` contient encore un bloc `match /rendezvous` (sans tiret bas) hérité d'une ancienne convention de nommage. L'application n'écrit que dans `rendez_vous` : ce bloc est inactif et peut être supprimé.
- Le README par défaut de Flutter a été remplacé par le présent document ; voir `pubspec.yaml` pour le descriptif technique (package `hopital_app`).
