# CycleTrack

CycleTrack est une application mobile développée avec Flutter pour le suivi interactif et sécurisé des cycles menstruels, des symptômes et de l'hydratation, proposant également de nombreuses statistiques et prédictions.

## 🚀 Fonctionnalités principales

### 📅 Suivi de Cycle et Prédictions
*   **Historique des cycles** : Visualisez vos précédents cycles et leur durée.
*   **Prédictions personnalisées** : Prévoyez vos prochaines règles, votre période d'ovulation et votre fenêtre de fertilité.
*   **Calendrier** : Une vue dégagée de votre mois avec les jours importants de votre cycle.

### 🤒 Suivi des Symptômes et de la Santé
*   **Enregistrement quotidien** : Notez vos symptômes de la journée, votre humeur, l'intensité des douleurs, etc.
*   **Suivi de l'hydratation** : Enregistrez vos apports en eau au fil de la journée avec un suivi de votre hydratation.

### 📊 Statistiques et Graphiques
*   **Graphiques avancés** : Analysez l'évolution de vos cycles, la fréquence de vos symptômes et votre consommation d'eau via des graphiques faciles à lire.

### 🔒 Sécurité et Vie Privée
*   **Protection par Code PIN** : Verrouillez l'application avec un code PIN personnel.
*   **Authentification Biométrique** : Support de Touch ID / Face ID / Empreinte digitale pour un accès rapide et sécurisé.
*   **Données locales** : L'ensemble de vos données est sauvegardé hors ligne sur votre appareil grâce à une base de données sécurisée (SQLite).
*   **Sauvegarde et Restauration** : Exportez et importez vos données en toute sécurité pour ne jamais rien perdre lors d'un changement de téléphone.

### 🔔 Notifications et Rappels
*   **Rappels personnalisables** : Restez alertée avant le début prévu de vos règles, ovulation, ou pour la prise de pilule et boire de l'eau.

### 💑 Mode Couple
*   **Partage** : Partage d'informations avec votre partenaire pour un meilleur suivi.

### 🎨 Design Moderne et Personnalisation
*   Interface UI/UX au format Material Design 3, colorée et moderne.
*   Support du mode sombre (Dark Mode) et clair (Light Mode).

## 🛠 Bibliothèques & Outils techniques

Ce projet Flutter utilise de nombreux packages pour proposer une expérience de qualité :

*   **sqflite** : Base de données locale sécurisée
*   **flutter_local_notifications** / **flutter_timezone** : Planification des rappels et alertes automatiques
*   **fl_chart** : Représentation visuelle des données et des statistiques
*   **pinput** / **local_auth** : Sécurité de l'application via mot de passe et intégration biométrique
*   **file_picker** / **path_provider** : Outils de stockage pour l'export & importation de sauvegarde

## 📱 Comment lancer le projet ?

Assurez-vous d'avoir installé [Flutter](https://flutter.dev/docs/get-started/install) sur votre machine.

1. Clonez le dépôt et naviguez dans le répertoire du projet.
2. Téléchargez les dépendances Flutter :
```bash
flutter pub get
```
3. Exécutez l'application sur un émulateur ou appareil physique :
```bash
flutter run
```
