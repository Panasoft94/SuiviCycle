# CycleTrack

**Version 2.0.0** · Flutter · Dart 3.9+

CycleTrack est une application mobile pour le suivi interactif et sécurisé des cycles menstruels, des symptômes et de l'hydratation, proposant des statistiques avancées, des prédictions intelligentes et un design Material Design 3 professionnel.

> 🔐 100% hors-ligne — vos données restent sur votre appareil.

---

## ✨ Nouveautés v2.0.0

### Refonte UI/UX complète
Chaque écran a été entièrement repensé avec un design système cohérent :
- **Animations d'entrée** staggerées sur tous les écrans (slide-up, fade-in, bounce)
- **Hero cards** avec gradients dynamiques adaptés à la phase du cycle
- **Cercle de progression** animé personnalisé (CustomPaint) sur le tableau de bord
- **Timeline visuelle** des 4 phases du cycle avec marqueur animé
- **Cartes compactes** avec emojis, icônes colorées et compteurs à rebours
- **Dialogs redessinés** avec icônes, coins arrondis 24px et boutons `FilledButton`
- **Salutation intelligente** (Bonjour/Bon après-midi/Bonsoir) + date en français

### Nouvelles fonctionnalités
- **🔒 Verrouillage automatique** — Style WhatsApp : verrouille l'app quand elle passe en arrière-plan, avec protection anti-boucle du dialog biométrique
- **📊 Statistiques 3 onglets** — Aperçu (heatmap, résumé), Graphiques (LineChart/BarChart), Tendances (régularité, insights)
- **💧 Hydratation enrichie** — Progression circulaire animée, streak, objectifs, graphique hebdomadaire, boutons rapides avec bounce
- **🤒 Module symptômes repensé** — Graphique tendances (douleur/énergie/libido), filtres chips, swipe-to-delete, emoji humeur dominant
- **📖 Guide d'utilisation** — 3 onglets (Tutoriels pas-à-pas, FAQ 10 questions, À propos)
- **🔮 Prédictions détaillées** — Score de fiabilité 0-100%, timeline du cycle, explication de l'algorithme, éducation 4 phases
- **💑 Mode couple enrichi** — Timeline de phase, décompte, baromètre d'humeur, conseils contextuels
- **📜 Historique des cycles** — Cartes détaillées, durée des règles, indicateurs visuels

---

## 🚀 Fonctionnalités principales

### 📅 Tableau de Bord Intelligent
*   **Hero card gradient** : Cercle de progression animé avec jour actuel, phase, dates clés (début, ovulation, fin prévue).
*   **Timeline des phases** : Progression visuelle `🩸 Règles → 🌱 Folliculaire → 🌸 Ovulation → 🌙 Lutéale` avec marqueur actif animé.
*   **Prochaines étapes** : Cartes ovulation et prochain cycle avec compteurs à rebours colorés.
*   **Conseil bien-être** : Conseil contextuel personnalisé selon la phase actuelle.
*   **Résumé du jour** : Humeur (avec emoji) + hydratation (mini progress) côte à côte.
*   **Quick stats** : Cycle moyen, règles moyennes, nombre total de cycles.
*   **Alerte intelligente** : Notification visuelle quand les règles sont imminentes (±2 jours).

### 📅 Suivi de Cycle et Prédictions
*   **Historique des cycles** : Visualisez vos précédents cycles avec cartes détaillées et durée des règles.
*   **Prédictions personnalisées** : Prochaines règles, ovulation et fenêtre de fertilité basées sur votre historique.
*   **Détection de phase précise** : L'ovulation est affichée le jour exact calculé, avec 4 phases distinctes.
*   **Algorithme adaptatif** : Prédictions affinées automatiquement avec la moyenne pondérée de vos cycles.
*   **Score de fiabilité** : Indicateur 0-100% animé basé sur le nombre de cycles enregistrés et leur régularité.
*   **Éducation intégrée** : Explication de l'algorithme en 5 étapes et description des 4 phases du cycle.

### 🤒 Suivi des Symptômes
*   **Graphique tendances** : LineChart interactif avec 3 filtres (Douleur / Énergie / Libido) via FilterChips.
*   **Carte résumé** : Emoji humeur dominante, moyennes douleur/énergie/libido.
*   **Swipe-to-delete** : Suppression intuitive par glissement avec dialogue de confirmation.
*   **6 humeurs** : Heureuse 😊, Triste 😢, En colère 😡, Anxieuse 😰, Calme 😌, Énergique ⚡.
*   **Sliders 0-5** : Niveaux de douleur, énergie et libido avec indicateurs visuels.

### 💧 Suivi de l'Hydratation
*   **Progression circulaire** : Animée, passe du bleu au vert quand l'objectif (2L) est atteint.
*   **Mini stats** : Streak (jours consécutifs), objectifs atteints, moyenne quotidienne.
*   **5 boutons rapides** : Ajout instantané avec animation bounce (verre, tasse, bouteille…).
*   **Graphique hebdomadaire** : BarChart animé des 7 derniers jours.
*   **Historique catégorisé** : Liste du jour avec icônes par type de boisson.

### 📊 Statistiques Avancées (3 onglets)
*   **Aperçu** : Heatmap calendrier, résumé global, score de régularité.
*   **Graphiques** : LineChart durées de cycle, BarChart durées de règles, barres d'humeur avec emojis.
*   **Tendances** : Insights intelligents, indicateurs de niveau, analyse des patterns.

### 🔔 Notifications Récursives
*   **Rappels ovulation** : J-3, J-2, J-1 et jour J de l'ovulation prévue.
*   **Rappels règles** : J-3, J-2, J-1 et jour J du début de cycle prévu.
*   **Personnalisables** : Activez/désactivez indépendamment depuis les paramètres.
*   **Persistantes** : Survivent aux redémarrages via receivers Android.

### 🔒 Sécurité et Vie Privée
*   **Code PIN** : Verrouillage avec code PIN 4 chiffres (Pinput).
*   **Biométrie** : Touch ID / Face ID / Empreinte pour accès rapide.
*   **Verrouillage automatique** : Style WhatsApp — verrouille l'app dès qu'elle passe en arrière-plan. Détection de tous les états lifecycle (`inactive`/`paused`/`hidden`) avec cache mémoire, cooldown anti-boucle et protection du dialog biométrique.
*   **Données 100% locales** : SQLite, aucun serveur distant.
*   **Sauvegarde/Restauration** : Export et import de la base de données.

### 💑 Mode Couple
*   **Hero card** : Phase actuelle avec gradient et emoji.
*   **Timeline de phase** : Progression visuelle du cycle pour le partenaire.
*   **Décomptes** : Jours restants avant ovulation et prochaines règles.
*   **Baromètre d'humeur** : Indicateur visuel de l'humeur du jour.
*   **Conseils contextuels** : Advice boxes adaptées à chaque phase.

### 📖 Guide d'Utilisation
*   **Tutoriels** : Cartes expandables pas-à-pas couvrant toutes les fonctionnalités.
*   **FAQ** : 10 questions fréquentes avec réponses détaillées.
*   **À propos** : Grille de fonctionnalités, infos développeur, version.
*   **Raccourcis rapides** : Accès direct aux écrans principaux depuis l'aide.

### 🎨 Design System
*   **Material Design 3** avec `colorScheme.surfaceContainerLow`, border radius 20-24px.
*   **Gradients dynamiques** : Couleur adaptée à la phase du cycle en cours.
*   **Mode sombre / clair** complet.
*   **Animations fluides** : `TweenAnimationBuilder`, `AnimationController`, `Dismissible`, bounce.
*   **Emojis** intégrés dans l'interface pour une lecture intuitive.

---

## 🛠 Stack Technique

| Package | Version | Rôle |
|---|---|---|
| **sqflite** | `^2.4.2` | Base de données locale SQLite |
| **flutter_local_notifications** | `^19.5.0` | Planification des rappels programmés |
| **flutter_timezone** | `^5.0.1` | Détection du fuseau horaire |
| **fl_chart** | `^0.68.0` | LineChart, BarChart — statistiques et tendances |
| **flutter_heatmap_calendar** | `^1.0.5` | Vue heatmap calendrier |
| **pinput** | `^4.0.0` | Saisie de code PIN sécurisée |
| **local_auth** | `^2.2.0` | Authentification biométrique |
| **another_flushbar** | `^1.12.30` | Notifications in-app (flushbar) |
| **file_picker** | `^8.0.3` | Sélection de fichiers (sauvegarde/restauration) |
| **path_provider** | `^2.1.3` | Accès au système de fichiers |
| **permission_handler** | `^11.3.1` | Gestion des permissions Android/iOS |
| **device_info_plus** | `^10.1.0` | Détection version Android (alarmes exactes) |
| **android_intent_plus** | `^5.0.2` | Intent Android pour permissions |
| **intl** | `^0.20.2` | Localisation et formatage des dates (fr_FR) |

---

## 📱 Comment lancer le projet ?

### Prérequis
- [Flutter](https://flutter.dev/docs/get-started/install) SDK `^3.9.2`
- Android Studio / Xcode
- Un émulateur ou appareil physique

### Installation

```bash
# Cloner le dépôt
git clone <url-du-repo>
cd cycles

# Installer les dépendances
flutter pub get

# Lancer l'application
flutter run
```

### Configuration Android requise

Le fichier `AndroidManifest.xml` inclut les permissions suivantes :

```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
```

---

## 📁 Structure du projet

```
lib/
├── main.dart                        # Point d'entrée, thème Material 3, WidgetsBindingObserver (auto-lock)
├── database/
│   └── database_helper.dart         # CRUD SQLite v11 (cycles, symptômes, notes, hydratation, users, settings)
├── models/
│   ├── cycle.dart                   # Modèle Cycle (startDate, endDate, periodEndDate, phase, ovulation…)
│   ├── symptom.dart                 # Modèle Symptôme (mood, painLevel, energyLevel, libidoLevel)
│   ├── note.dart                    # Modèle Note
│   ├── settings.dart                # Modèle Paramètres (avec autoLock, copyWith())
│   └── hydration.dart               # Modèle Hydratation
├── services/
│   ├── notification_service.dart    # Planification notifications (timezone, fallback, alarmes exactes)
│   └── backup_service.dart          # Import/Export de la BDD
├── screens/
│   ├── dashboard/
│   │   └── dashboard_screen.dart    # ★ Tableau de bord (hero card, timeline, stats, feature grid)
│   ├── cycles/
│   │   ├── cycle_history_screen.dart    # ★ Historique des cycles (cartes détaillées)
│   │   ├── prediction_details_screen.dart # ★ Prédictions (fiabilité, timeline, algorithme, éducation)
│   │   └── couple_mode_screen.dart      # ★ Mode couple (timeline, décompte, conseils)
│   ├── symptom/
│   │   ├── symptom_screen.dart      # ★ Liste symptômes (LineChart, filtres, swipe-delete)
│   │   └── add_symptom_screen.dart  # Ajout/édition symptôme
│   ├── hydration/
│   │   └── hydration_screen.dart    # ★ Hydratation (progression circulaire, streak, graphique)
│   ├── stats/
│   │   └── stats_screen.dart        # ★ Statistiques 3 onglets (Aperçu, Graphiques, Tendances)
│   ├── settings/
│   │   └── settings_screen.dart     # ★ Paramètres (sécurité séparée, auto-lock toggle)
│   ├── aide/
│   │   └── aide_screen.dart         # ★ Guide utilisation 3 onglets (Tutoriels, FAQ, À propos)
│   ├── home/
│   │   └── home_screen.dart         # Navigation principale (TabBar)
│   └── user_account/
│       ├── login.dart               # Page de connexion PIN
│       ├── create_pin.dart          # Création de compte + PIN
│       ├── change_pin_screen.dart   # Modification du PIN
│       ├── lock_screen.dart         # ★ Écran de verrouillage auto (PIN + biométrie)
│       └── user_account_screen.dart # Gestion du compte
└── utils/
    ├── string_extensions.dart       # Extension capitalize()
    └── widgets.dart                 # AppBackButton, slideTransition()
```

> Les fichiers marqués ★ ont été entièrement réécrits dans la v2.0.0.

---

## 🏗 Architecture & Patterns

| Pattern | Utilisation |
|---|---|
| **FutureBuilder + _XxxData** | Classe privée regroupant toutes les données async pour chaque écran |
| **WidgetsBindingObserver** | Détection lifecycle pour verrouillage automatique |
| **Cache mémoire** | État auto-lock en RAM pour éviter les appels DB pendant les transitions |
| **TweenAnimationBuilder** | Animations d'entrée staggerées sur les listes |
| **CustomPainter** | Cercle de progression du cycle (dashboard) |
| **Singleton DB** | `DatabaseHelper._instance` avec `factory` constructor |
| **Singleton Notifications** | `NotificationService._instance` avec fallback init |

---

## 📄 Licence

Projet privé — Tous droits réservés.

