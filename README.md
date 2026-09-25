# Medigo — Application mobile de gestion hospitalière

Application mobile **Flutter** pour la gestion hospitalière : administration des hôpitaux, des spécialités et des médecins. Construite avec **Firebase** pour l'authentification et les données.

> Projet en cours de développement (v1).

## Fonctionnalités

| Module | Rôle |
| --- | --- |
| `lib/admin/` | Tableau de bord administrateur : gestion des hôpitaux et des spécialités |
| `lib/adminHopital/` | Tableau de bord de l'administrateur d'un hôpital |
| `lib/medecin/` | Tableau de bord du médecin |
| `lib/shared/` | Éléments partagés (écran de connexion…) |
| `lib/main.dart` | Point d'entrée + routes (`/login`, tableaux de bord…) |

## Technologies

- **Flutter** (Dart) — application multi-plateforme (Android, iOS, web, desktop)
- **Firebase** — initialisation (`firebase_options.dart`), authentification et base de données (`firebase.json`)

## Structure

```
lib/
├── main.dart                    # Démarrage + routes
├── firebase_options.dart        # Configuration Firebase
├── admin/                       # Administration globale (hôpitaux, spécialités)
│   └── screens/
├── adminHopital/                # Administration d'un hôpital
│   └── screens/
├── medecin/                     # Espace médecin
│   └── screens/
└── shared/                      # Écrans et widgets partagés
```

## Démarrage

```bash
# Récupérer les dépendances
flutter pub get

# Configurer Firebase (fichier de configuration adapté à votre projet)
# puis lancer l'application
flutter run
```

## Notes

- Nécessite Flutter SDK et un projet Firebase configuré (`firebase.json`, `firebase_options.dart`).
- Le README par défaut de Flutter a été remplacé par le présent document ; voir `pubspec.yaml` pour le descriptif technique (package `hopital_app`).