# CycleTrack

**Version 1.1.0** · Flutter · Dart 3.9+

CycleTrack est une application mobile développée avec Flutter pour le suivi interactif et sécurisé des cycles menstruels, des symptômes et de l'hydratation, proposant également de nombreuses statistiques et prédictions intelligentes.

> 🔐 100% hors-ligne — vos données restent sur votre appareil.

---

## 🚀 Fonctionnalités principales

### 📅 Suivi de Cycle et Prédictions Intelligentes
*   **Historique des cycles** : Visualisez vos précédents cycles et leur durée.
*   **Prédictions personnalisées** : Prévoyez vos prochaines règles, votre période d'ovulation et votre fenêtre de fertilité basées sur votre historique réel.
*   **Détection de phase précise** : L'ovulation est affichée uniquement le jour exact calculé (et non une fenêtre approximative), avec 4 phases distinctes : Règles → Folliculaire → Ovulation → Lutéale.
*   **Algorithme adaptatif** : Les prédictions s'affinent automatiquement avec la moyenne de vos cycles précédents.
*   **Calendrier** : Une vue dégagée de votre mois avec les jours importants de votre cycle.

### 🤒 Suivi des Symptômes et de la Santé
*   **Enregistrement quotidien** : Notez vos symptômes de la journée, votre humeur, l'intensité des douleurs, le niveau d'énergie et la libido.
*   **Suivi de l'hydratation** : Enregistrez vos apports en eau au fil de la journée avec un objectif personnalisable.

### 📊 Statistiques et Graphiques
*   **Graphiques avancés** : Analysez l'évolution de vos cycles, la fréquence de vos symptômes et votre consommation d'eau via des graphiques interactifs (fl_chart).
*   **Heatmap calendrier** : Vue en heatmap pour visualiser les tendances sur plusieurs mois.
*   **Statistiques rapides** : Durée moyenne de cycle et durée moyenne des règles affichées sur le tableau de bord.

### 🔔 Notifications Récursives
*   **Rappels ovulation** : Notifications automatiques à J-3, J-2, J-1 et le jour même de l'ovulation prévue.
*   **Rappels règles** : Notifications automatiques à J-3, J-2, J-1 et le jour même du début de cycle prévu.
*   **Personnalisables** : Activez ou désactivez indépendamment les rappels d'ovulation et de règles depuis les paramètres.
*   **Persistantes** : Les notifications survivent aux redémarrages du téléphone grâce aux receivers Android.

### 🔒 Sécurité et Vie Privée
*   **Protection par Code PIN** : Verrouillez l'application avec un code PIN personnel.
*   **Authentification Biométrique** : Support de Touch ID / Face ID / Empreinte digitale pour un accès rapide et sécurisé.
*   **Données locales** : L'ensemble de vos données est sauvegardé hors ligne sur votre appareil grâce à une base de données SQLite.
*   **Sauvegarde et Restauration** : Exportez et importez vos données pour ne jamais rien perdre lors d'un changement de téléphone.

### 💑 Mode Couple
*   **Tableau de bord partenaire** : Phase actuelle, conseils bienveillants, dates clés (ovulation, prochaines règles) et décompte.

### 🎨 Design Moderne et Personnalisation
*   Interface UI/UX au format Material Design 3, colorée et moderne.
*   Support du mode sombre (Dark Mode) et clair (Light Mode).
*   Animations fluides et composants arrondis.

---

## 🛠 Stack Technique

| Package | Rôle |
|---|---|
| **sqflite** `^2.4.2` | Base de données locale SQLite |
| **flutter_local_notifications** `^19.5.0` | Planification des rappels programmés |
| **flutter_timezone** `^5.0.1` | Détection du fuseau horaire pour les notifications |
| **fl_chart** `^0.68.0` | Graphiques et statistiques visuelles |
| **flutter_heatmap_calendar** `^1.0.5` | Vue heatmap calendrier |
| **pinput** `^4.0.0` | Saisie de code PIN |
| **local_auth** `^2.2.0` | Authentification biométrique |
| **file_picker** `^8.0.3` | Sélection de fichiers pour sauvegarde/restauration |
| **path_provider** `^2.1.3` | Accès au système de fichiers |
| **permission_handler** `^11.3.1` | Gestion des permissions Android/iOS |
| **device_info_plus** `^10.1.0` | Détection de la version Android (alarmes exactes) |
| **intl** `^0.20.2` | Localisation et formatage des dates en français |

---

## 📱 Comment lancer le projet ?

### Prérequis
- [Flutter](https://flutter.dev/docs/get-started/install) SDK `^3.9.2`
- Android Studio / Xcode
- Un émulateur ou appareil physique

### Installation

1. Clonez le dépôt et naviguez dans le répertoire du projet :
```bash
git clone <url-du-repo>
cd cycles
```

2. Téléchargez les dépendances Flutter :
```bash
flutter pub get
```

3. Exécutez l'application :
```bash
flutter run
```

### Configuration Android requise

Le fichier `AndroidManifest.xml` inclut les permissions suivantes pour le bon fonctionnement des notifications :

```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

---

## 📁 Structure du projet

```
lib/
├── main.dart                  # Point d'entrée, thème, routing
├── database/
│   └── database_helper.dart   # CRUD SQLite (cycles, symptômes, notes, hydratation)
├── models/
│   ├── cycle.dart             # Modèle Cycle
│   ├── symptom.dart           # Modèle Symptôme
│   ├── note.dart              # Modèle Note
│   ├── settings.dart          # Modèle Paramètres
│   └── hydration.dart         # Modèle Hydratation
├── services/
│   ├── notification_service.dart  # Planification des notifications
│   └── backup_service.dart        # Import/Export de la BDD
├── screens/
│   ├── dashboard/             # Tableau de bord principal
│   ├── cycles/                # Historique, prédictions, mode couple
│   ├── symptom/               # Journal de symptômes
│   ├── hydration/             # Suivi d'hydratation
│   ├── stats/                 # Statistiques et graphiques
│   ├── settings/              # Paramètres de l'app
│   ├── aide/                  # Page d'aide
│   ├── home/                  # Navigation principale (TabBar)
│   └── user_account/          # PIN, login, biométrie
└── utils/
    ├── string_extensions.dart # Extensions String (capitalize)
    └── widgets.dart           # Widgets réutilisables
```

---

## 📄 Licence

Projet privé — Tous droits réservés.

