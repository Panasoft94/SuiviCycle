import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/widgets.dart';

// ═══════════════════════════════════════
// GUIDE D'UTILISATION — AIDE SCREEN
// ═══════════════════════════════════════

class AideScreen extends StatefulWidget {
  const AideScreen({super.key});

  @override
  State<AideScreen> createState() => _AideScreenState();
}

class _AideScreenState extends State<AideScreen> with TickerProviderStateMixin {
  late final TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // ── App Bar ──
          SliverAppBar(
            floating: true,
            snap: true,
            elevation: 0,
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            leading: const AppBackButton(),
            title: const Text('Guide & Aide',
                style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
          ),

          // ── Hero Card ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _buildHeroCard(cs),
            ),
          ),

          // ── Search Bar ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _buildQuickActions(cs),
            ),
          ),

          // ── Sticky Tab Bar ──
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabDelegate(
              child: Container(
                color: cs.surface,
                child: TabBar(
                  controller: _tabController,
                  labelColor: cs.primary,
                  unselectedLabelColor: cs.onSurfaceVariant,
                  indicatorColor: cs.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Tutoriels'),
                    Tab(text: 'FAQ'),
                    Tab(text: 'À propos'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTutorialsTab(cs),
            _buildFaqTab(cs),
            _buildAboutTab(cs),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // HERO CARD
  // ═══════════════════════════════════════

  Widget _buildHeroCard(ColorScheme cs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primary,
              cs.primary.withAlpha(200),
              cs.tertiary.withAlpha(180),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withAlpha(50),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '📖 Guide CycleTrack',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Bienvenue dans\nvotre guide',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Découvrez toutes les fonctionnalités pour maîtriser le suivi de votre cycle.',
                    style: TextStyle(
                      color: Colors.white.withAlpha(210),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // QUICK ACTIONS (raccourcis thématiques)
  // ═══════════════════════════════════════

  Widget _buildQuickActions(ColorScheme cs) {
    final actions = [
      _QuickAction('Démarrer', Icons.play_circle_rounded, const Color(0xFF42A5F5)),
      _QuickAction('Cycles', Icons.loop_rounded, const Color(0xFFEC407A)),
      _QuickAction('Symptômes', Icons.favorite_rounded, const Color(0xFFFF7043)),
      _QuickAction('Sécurité', Icons.shield_rounded, const Color(0xFF66BB6A)),
    ];

    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final a = actions[index];
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              // Scroll to the relevant section in tutorials tab
              _tabController.animateTo(0);
            },
            child: Container(
              width: 80,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: a.color.withAlpha(18),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: a.color.withAlpha(50)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: a.color.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(a.icon, size: 18, color: a.color),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    a.label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: a.color,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════
  // TAB 1 — TUTORIELS
  // ═══════════════════════════════════════

  Widget _buildTutorialsTab(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Premiers pas ──
        _buildSectionTitle('🚀 Premiers pas', cs),
        const SizedBox(height: 10),
        _GuideExpansionCard(
          icon: Icons.person_add_rounded,
          color: const Color(0xFF42A5F5),
          title: 'Créer votre compte',
          subtitle: 'Protégez vos données personnelles',
          steps: const [
            _GuideStep(
              number: '1',
              title: 'Accédez aux Paramètres',
              description:
                  'Depuis l\'écran principal, appuyez sur l\'onglet Paramètres en bas de l\'écran.',
            ),
            _GuideStep(
              number: '2',
              title: 'Créer un code PIN',
              description:
                  'Dans la section Sécurité, appuyez sur "Créer un code PIN" et choisissez un code à 4 chiffres facile à retenir.',
            ),
            _GuideStep(
              number: '3',
              title: 'Activer la biométrie (optionnel)',
              description:
                  'Activez l\'empreinte digitale ou Face ID pour un déverrouillage rapide et sécurisé.',
            ),
          ],
        ),
        const SizedBox(height: 10),
        _GuideExpansionCard(
          icon: Icons.play_arrow_rounded,
          color: const Color(0xFFEC407A),
          title: 'Démarrer un cycle',
          subtitle: 'Enregistrez le premier jour de vos règles',
          steps: const [
            _GuideStep(
              number: '1',
              title: 'Tableau de bord',
              description:
                  'Depuis le tableau de bord, appuyez sur le bouton "Démarrer un cycle" ou sur le gros bouton central.',
            ),
            _GuideStep(
              number: '2',
              title: 'Sélectionnez la date',
              description:
                  'Choisissez la date du premier jour de vos règles. Par défaut, c\'est aujourd\'hui.',
            ),
            _GuideStep(
              number: '3',
              title: 'C\'est parti !',
              description:
                  'CycleTrack calcule automatiquement les prédictions : ovulation, prochaines règles, phases du cycle.',
            ),
          ],
        ),

        const SizedBox(height: 28),

        // ── Suivi quotidien ──
        _buildSectionTitle('📊 Suivi quotidien', cs),
        const SizedBox(height: 10),
        _GuideExpansionCard(
          icon: Icons.dashboard_rounded,
          color: const Color(0xFF7E57C2),
          title: 'Le tableau de bord',
          subtitle: 'Votre vue d\'ensemble quotidienne',
          steps: const [
            _GuideStep(
              number: '•',
              title: 'Progression du cycle',
              description:
                  'Le cercle central affiche le jour actuel de votre cycle avec la phase en cours (folliculaire, ovulation, lutéale, menstruelle).',
            ),
            _GuideStep(
              number: '•',
              title: 'Dates clés',
              description:
                  'Retrouvez les prédictions pour la prochaine ovulation et les prochaines règles avec un compte à rebours.',
            ),
            _GuideStep(
              number: '•',
              title: 'Actions rapides',
              description:
                  'Accédez en un tap aux symptômes, à l\'hydratation, à l\'historique et aux statistiques.',
            ),
          ],
        ),
        const SizedBox(height: 10),
        _GuideExpansionCard(
          icon: Icons.favorite_rounded,
          color: const Color(0xFFEF5350),
          title: 'Enregistrer vos symptômes',
          subtitle: 'Humeur, douleur, énergie et plus',
          steps: const [
            _GuideStep(
              number: '1',
              title: 'Ouvrir le suivi',
              description:
                  'Depuis le tableau de bord, appuyez sur la carte "Symptômes du jour" ou l\'icône cœur.',
            ),
            _GuideStep(
              number: '2',
              title: 'Notez votre humeur',
              description:
                  'Sélectionnez un emoji qui correspond à votre état émotionnel : 😊 😐 😢 😡 😴',
            ),
            _GuideStep(
              number: '3',
              title: 'Évaluez vos niveaux',
              description:
                  'Ajustez les curseurs pour la douleur, l\'énergie et la libido de 0 à 5.',
            ),
            _GuideStep(
              number: '4',
              title: 'Ajoutez des notes',
              description:
                  'Un champ libre vous permet de noter tout détail pertinent (alimentation, sommeil, événements...).',
            ),
          ],
        ),
        const SizedBox(height: 10),
        _GuideExpansionCard(
          icon: Icons.water_drop_rounded,
          color: const Color(0xFF29B6F6),
          title: 'Suivi d\'hydratation',
          subtitle: 'Vos objectifs d\'eau quotidiens',
          steps: const [
            _GuideStep(
              number: '•',
              title: 'Objectif personnalisé',
              description:
                  'Définissez votre objectif quotidien d\'hydratation en millilitres.',
            ),
            _GuideStep(
              number: '•',
              title: 'Ajoutez facilement',
              description:
                  'Appuyez sur les boutons rapides (+150ml, +250ml, +500ml) pour enregistrer votre consommation.',
            ),
            _GuideStep(
              number: '•',
              title: 'Suivez votre progression',
              description:
                  'Une barre de progression visuelle vous montre où vous en êtes par rapport à votre objectif.',
            ),
          ],
        ),

        const SizedBox(height: 28),

        // ── Fonctionnalités avancées ──
        _buildSectionTitle('✨ Fonctionnalités avancées', cs),
        const SizedBox(height: 10),
        _GuideExpansionCard(
          icon: Icons.bar_chart_rounded,
          color: const Color(0xFFFF7043),
          title: 'Statistiques & Graphiques',
          subtitle: 'Analysez vos tendances',
          steps: const [
            _GuideStep(
              number: '•',
              title: 'Onglet Aperçu',
              description:
                  'Résumé global avec durée moyenne, score de régularité, insights intelligents et calendrier thermique de votre historique.',
            ),
            _GuideStep(
              number: '•',
              title: 'Onglet Graphiques',
              description:
                  'Visualisez l\'évolution de vos cycles avec des courbes interactives et la durée de vos règles en barres.',
            ),
            _GuideStep(
              number: '•',
              title: 'Onglet Tendances',
              description:
                  'Barres d\'humeur, niveaux moyens de douleur/énergie/libido, et un résumé de votre bien-être général.',
            ),
          ],
        ),
        const SizedBox(height: 10),
        _GuideExpansionCard(
          icon: Icons.people_rounded,
          color: const Color(0xFFAB47BC),
          title: 'Mode Couple',
          subtitle: 'Partagez avec votre partenaire',
          steps: const [
            _GuideStep(
              number: '•',
              title: 'Vue partenaire',
              description:
                  'Votre partenaire accède à une vue simplifiée du cycle en cours avec la phase actuelle et le jour du cycle.',
            ),
            _GuideStep(
              number: '•',
              title: 'Fenêtre de fertilité',
              description:
                  'Indication visuelle de la fenêtre fertile pour une meilleure planification.',
            ),
            _GuideStep(
              number: '•',
              title: 'Conseils contextuels',
              description:
                  'Des suggestions bienveillantes adaptées à chaque phase du cycle pour mieux se comprendre.',
            ),
          ],
        ),
        const SizedBox(height: 10),
        _GuideExpansionCard(
          icon: Icons.history_rounded,
          color: const Color(0xFF26A69A),
          title: 'Historique des cycles',
          subtitle: 'Consultez et gérez vos cycles passés',
          steps: const [
            _GuideStep(
              number: '•',
              title: 'Filtres intelligents',
              description:
                  'Filtrez vos cycles par statut : tous, en cours ou terminés. Les cycles sont groupés par mois.',
            ),
            _GuideStep(
              number: '•',
              title: 'Détails complets',
              description:
                  'Appuyez sur un cycle pour voir ses détails : dates, durée, ovulation, phase, progression.',
            ),
            _GuideStep(
              number: '•',
              title: 'Glisser pour supprimer',
              description:
                  'Glissez une carte vers la gauche pour supprimer un cycle, avec confirmation de sécurité.',
            ),
          ],
        ),

        const SizedBox(height: 28),

        // ── Sécurité & Paramètres ──
        _buildSectionTitle('🔒 Sécurité & Paramètres', cs),
        const SizedBox(height: 10),
        _GuideExpansionCard(
          icon: Icons.lock_rounded,
          color: const Color(0xFF66BB6A),
          title: 'Protéger vos données',
          subtitle: 'PIN, biométrie et verrouillage auto',
          steps: const [
            _GuideStep(
              number: '🔑',
              title: 'Code PIN',
              description:
                  'Un code à 4 chiffres protège l\'accès à l\'application. Vous pouvez le modifier à tout moment.',
            ),
            _GuideStep(
              number: '👆',
              title: 'Empreinte / Face ID',
              description:
                  'Activez la biométrie pour déverrouiller rapidement sans saisir votre PIN.',
            ),
            _GuideStep(
              number: '🔒',
              title: 'Verrouillage automatique',
              description:
                  'Comme WhatsApp ! Quand vous quittez l\'app, elle se verrouille automatiquement au retour.',
            ),
          ],
        ),
        const SizedBox(height: 10),
        _GuideExpansionCard(
          icon: Icons.notifications_active_rounded,
          color: const Color(0xFFFFCA28),
          title: 'Notifications',
          subtitle: 'Ne manquez aucune date importante',
          steps: const [
            _GuideStep(
              number: '•',
              title: 'Rappels de règles',
              description:
                  'Recevez des alertes 3 jours, 2 jours, 1 jour avant et le jour même de vos prochaines règles.',
            ),
            _GuideStep(
              number: '•',
              title: 'Rappels d\'ovulation',
              description:
                  'Soyez prévenue de l\'approche de votre ovulation pour optimiser votre suivi de fertilité.',
            ),
            _GuideStep(
              number: '•',
              title: 'Personnalisable',
              description:
                  'Activez ou désactivez chaque type de notification individuellement dans les Paramètres.',
            ),
          ],
        ),
        const SizedBox(height: 10),
        _GuideExpansionCard(
          icon: Icons.backup_rounded,
          color: const Color(0xFF78909C),
          title: 'Sauvegarde & Restauration',
          subtitle: 'Préservez vos données en toute sécurité',
          steps: const [
            _GuideStep(
              number: '1',
              title: 'Sauvegarder',
              description:
                  'Paramètres → Maintenance → Sauvegarder. Un fichier de sauvegarde est créé sur votre appareil.',
            ),
            _GuideStep(
              number: '2',
              title: 'Restaurer',
              description:
                  'Paramètres → Maintenance → Restaurer. Sélectionnez votre fichier de sauvegarde pour récupérer vos données.',
            ),
            _GuideStep(
              number: '⚠️',
              title: 'Attention',
              description:
                  'La restauration remplace toutes les données actuelles. Faites une sauvegarde avant si nécessaire.',
            ),
          ],
        ),

        const SizedBox(height: 28),

        // ── Astuces ──
        _buildSectionTitle('💡 Astuces', cs),
        const SizedBox(height: 10),
        _buildTipsCard(cs),
      ],
    );
  }

  // ── Tips Card ──

  Widget _buildTipsCard(ColorScheme cs) {
    final tips = [
      _Tip(
        '📱',
        'Utilisez chaque jour',
        'Plus vous enregistrez régulièrement, plus les prédictions deviennent précises.',
      ),
      _Tip(
        '📝',
        'Notez vos symptômes',
        'Même les petits détails comptent ! Ils révèlent des tendances sur plusieurs mois.',
      ),
      _Tip(
        '💧',
        'Hydratez-vous',
        'L\'hydratation influence votre bien-être pendant tout le cycle. Utilisez le suivi d\'eau !',
      ),
      _Tip(
        '📊',
        'Consultez les stats',
        'Après 3 cycles ou plus, vos statistiques deviennent vraiment parlantes.',
      ),
      _Tip(
        '💾',
        'Sauvegardez souvent',
        'Faites une sauvegarde régulière pour ne jamais perdre vos données.',
      ),
      _Tip(
        '🤝',
        'Mode Couple',
        'Invitez votre partenaire à consulter le Mode Couple pour une meilleure complicité.',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer.withAlpha(50),
            cs.tertiaryContainer.withAlpha(30),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.primary.withAlpha(40)),
      ),
      child: Column(
        children: tips.asMap().entries.map((entry) {
          final tip = entry.value;
          final isLast = entry.key == tips.length - 1;
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tip.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tip.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tip.description,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: cs.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!isLast)
                Divider(
                  color: cs.outlineVariant.withAlpha(50),
                  height: 20,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════
  // TAB 2 — FAQ
  // ═══════════════════════════════════════

  Widget _buildFaqTab(ColorScheme cs) {
    final faqs = [
      _FaqItem(
        question: 'Comment démarrer mon premier cycle ?',
        answer:
            'Depuis le tableau de bord, appuyez sur le bouton "Démarrer un cycle". Sélectionnez la date du premier jour de vos règles et validez. CycleTrack calculera automatiquement les prédictions.',
        icon: Icons.play_circle_outline_rounded,
        color: const Color(0xFFEC407A),
      ),
      _FaqItem(
        question: 'Comment terminer un cycle en cours ?',
        answer:
            'Le cycle se termine automatiquement lorsque vous démarrez un nouveau cycle. La date de fin sera le jour précédant le début du nouveau cycle.',
        icon: Icons.stop_circle_outlined,
        color: const Color(0xFF42A5F5),
      ),
      _FaqItem(
        question: 'Les prédictions sont-elles fiables ?',
        answer:
            'Les prédictions se basent sur votre historique personnel. Plus vous enregistrez de cycles, plus elles deviennent précises. Après 3 à 6 cycles, la fiabilité est optimale. Elles restent des estimations et ne remplacent pas un avis médical.',
        icon: Icons.auto_awesome_rounded,
        color: const Color(0xFFFF7043),
      ),
      _FaqItem(
        question: 'Mes données sont-elles sécurisées ?',
        answer:
            'Toutes vos données sont stockées localement sur votre appareil, jamais envoyées sur internet. Le code PIN et la biométrie ajoutent une couche de protection supplémentaire.',
        icon: Icons.shield_rounded,
        color: const Color(0xFF66BB6A),
      ),
      _FaqItem(
        question: 'Comment fonctionne le Mode Couple ?',
        answer:
            'Le Mode Couple offre une vue simplifiée du cycle en cours avec la phase, le jour du cycle, des conseils bienveillants et une indication de fertilité. Il est accessible depuis l\'onglet dédié dans l\'écran principal.',
        icon: Icons.people_rounded,
        color: const Color(0xFFAB47BC),
      ),
      _FaqItem(
        question: 'Comment sauvegarder mes données ?',
        answer:
            'Allez dans Paramètres → Maintenance des données → Sauvegarder. Un fichier sera créé sur votre appareil. Pour restaurer, sélectionnez "Restaurer" et choisissez votre fichier de sauvegarde.',
        icon: Icons.backup_rounded,
        color: const Color(0xFF78909C),
      ),
      _FaqItem(
        question: 'Comment modifier la durée par défaut de mon cycle ?',
        answer:
            'Allez dans Paramètres → Cycle & Prédictions → Durée du cycle. Vous pouvez ajuster de 15 à 54 jours. Cette valeur est utilisée quand il n\'y a pas assez d\'historique pour calculer une moyenne.',
        icon: Icons.tune_rounded,
        color: const Color(0xFF26A69A),
      ),
      _FaqItem(
        question: 'Que faire si j\'ai oublié mon code PIN ?',
        answer:
            'Malheureusement, si vous oubliez votre PIN et n\'avez pas activé la biométrie, vous devrez réinstaller l\'application. Pensez à activer l\'empreinte digitale comme sécurité de secours !',
        icon: Icons.lock_reset_rounded,
        color: const Color(0xFFEF5350),
      ),
      _FaqItem(
        question: 'À quoi servent les statistiques ?',
        answer:
            'Les statistiques vous aident à comprendre votre corps : régularité de vos cycles, durée moyenne des règles, tendances d\'humeur et de symptômes. Elles sont utiles aussi pour votre médecin.',
        icon: Icons.insights_rounded,
        color: const Color(0xFFFFCA28),
      ),
      _FaqItem(
        question: 'Puis-je supprimer un cycle par erreur ?',
        answer:
            'Oui, dans l\'historique des cycles, glissez la carte vers la gauche ou ouvrez les détails et appuyez sur Supprimer. Une confirmation est toujours demandée avant suppression définitive.',
        icon: Icons.delete_outline_rounded,
        color: const Color(0xFFFF8A65),
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: faqs.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildFaqHeader(cs),
          );
        }
        final faq = faqs[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _FaqExpansionCard(faq: faq),
        );
      },
    );
  }

  Widget _buildFaqHeader(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withAlpha(50),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.tertiary.withAlpha(40)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.tertiary.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.help_outline_rounded,
                size: 22, color: cs.tertiary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Questions fréquentes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Trouvez rapidement les réponses à vos questions',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // TAB 3 — À PROPOS
  // ═══════════════════════════════════════

  Widget _buildAboutTab(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // ── App Identity ──
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primaryContainer.withAlpha(60),
                    cs.primaryContainer.withAlpha(25),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withAlpha(20),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(Icons.water_drop_rounded,
                  size: 52, color: cs.primary),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'CycleTrack',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: cs.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Version 1.1.0',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              'Votre compagnon personnel pour un suivi simple et intelligent de votre cycle menstruel.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),

        // ── Features Showcase ──
        _buildSectionTitle('🌟 Fonctionnalités clés', cs),
        const SizedBox(height: 12),
        _buildFeatureGrid(cs),

        const SizedBox(height: 32),

        // ── Developer Section ──
        _buildSectionTitle('👨‍💻 Développeur', cs),
        const SizedBox(height: 12),
        _buildDeveloperCard(cs),

        const SizedBox(height: 24),

        // ── Footer ──
        Center(
          child: Column(
            children: [
              Text(
                'Dévéloppé par CEO Anicet DJIMTOLOUMA',
                style: TextStyle(
                  fontSize: 12.5,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '© 2024 – 2026 Panasoft Corporation',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureGrid(ColorScheme cs) {
    final features = [
      _Feature(Icons.track_changes_rounded, 'Suivi intelligent',
          'Prédictions automatiques', const Color(0xFFEC407A)),
      _Feature(Icons.edit_note_rounded, 'Journal quotidien',
          'Symptômes & humeurs', const Color(0xFFFF7043)),
      _Feature(Icons.insights_rounded, 'Statistiques',
          'Graphiques & tendances', const Color(0xFF42A5F5)),
      _Feature(Icons.people_rounded, 'Mode Couple',
          'Partage simplifié', const Color(0xFFAB47BC)),
      _Feature(Icons.water_drop_rounded, 'Hydratation',
          'Suivi de l\'eau', const Color(0xFF29B6F6)),
      _Feature(Icons.shield_rounded, 'Sécurité',
          'PIN & biométrie', const Color(0xFF66BB6A)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final f = features[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: f.color.withAlpha(15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: f.color.withAlpha(40)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: f.color.withAlpha(28),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(f.icon, size: 20, color: f.color),
              ),
              const SizedBox(height: 10),
              Text(
                f.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                f.subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeveloperCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withAlpha(60)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primary.withAlpha(30),
                      cs.primary.withAlpha(15),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.code_rounded, size: 26, color: cs.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anicet DJIMTOLOUMA',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Ingénieur logiciel,Dévéloppeur web & mobile senior ',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildContactRow(
            Icons.email_rounded,
            'webmasterdjim@gmail.com',
            const Color(0xFF42A5F5),
            cs,
          ),
          const SizedBox(height: 10),
          _buildContactRow(
            Icons.phone_rounded,
            '+236 72 39 59 35',
            const Color(0xFF66BB6A),
            cs,
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(
      IconData icon, String text, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════

  Widget _buildSectionTitle(String title, ColorScheme cs) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Divider(color: cs.outlineVariant.withAlpha(60), thickness: 1),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
// GUIDE EXPANSION CARD (tutoriels dépliables)
// ═══════════════════════════════════════════════════

class _GuideExpansionCard extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<_GuideStep> steps;

  const _GuideExpansionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.steps,
  });

  @override
  State<_GuideExpansionCard> createState() => _GuideExpansionCardState();
}

class _GuideExpansionCardState extends State<_GuideExpansionCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  late final Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _rotationAnimation =
        Tween<double>(begin: 0, end: 0.5).animate(_expandAnimation);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: _expanded
            ? widget.color.withAlpha(12)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _expanded
              ? widget.color.withAlpha(60)
              : cs.outlineVariant.withAlpha(60),
          width: _expanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // ── Header ──
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.color.withAlpha(25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child:
                        Icon(widget.icon, size: 22, color: widget.color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: _expanded
                                ? widget.color
                                : cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RotationTransition(
                    turns: _rotationAnimation,
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: _expanded
                          ? widget.color
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expandable Content ──
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Divider(
                      color: widget.color.withAlpha(30), height: 1),
                  const SizedBox(height: 14),
                  ...widget.steps.map((step) => _buildStepRow(step, cs)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(_GuideStep step, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.color.withAlpha(22),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              step.number,
              style: TextStyle(
                fontSize: step.number.length > 1 ? 13 : 12.5,
                fontWeight: FontWeight.bold,
                color: widget.color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  step.description,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// FAQ EXPANSION CARD
// ═══════════════════════════════════════════════════

class _FaqExpansionCard extends StatefulWidget {
  final _FaqItem faq;
  const _FaqExpansionCard({required this.faq});

  @override
  State<_FaqExpansionCard> createState() => _FaqExpansionCardState();
}

class _FaqExpansionCardState extends State<_FaqExpansionCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _expandAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() {
      _expanded = !_expanded;
      _expanded ? _controller.forward() : _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final faq = widget.faq;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: _expanded
            ? faq.color.withAlpha(10)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _expanded
              ? faq.color.withAlpha(50)
              : cs.outlineVariant.withAlpha(50),
        ),
      ),
      child: InkWell(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: faq.color.withAlpha(22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        Icon(faq.icon, size: 18, color: faq.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      faq.question,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: _expanded
                            ? faq.color
                            : cs.onSurface,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 22,
                      color: _expanded
                          ? faq.color
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              SizeTransition(
                sizeFactor: _expandAnimation,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, left: 48),
                  child: Text(
                    faq.answer,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// STICKY TAB DELEGATE
// ═══════════════════════════════════════════════════

class _StickyTabDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _StickyTabDelegate({required this.child});

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _StickyTabDelegate oldDelegate) =>
      child != oldDelegate.child;
}

// ═══════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════

class _GuideStep {
  final String number;
  final String title;
  final String description;
  const _GuideStep({
    required this.number,
    required this.title,
    required this.description,
  });
}

class _FaqItem {
  final String question;
  final String answer;
  final IconData icon;
  final Color color;
  const _FaqItem({
    required this.question,
    required this.answer,
    required this.icon,
    required this.color,
  });
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  const _QuickAction(this.label, this.icon, this.color);
}

class _Tip {
  final String emoji;
  final String title;
  final String description;
  const _Tip(this.emoji, this.title, this.description);
}

class _Feature {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _Feature(this.icon, this.title, this.subtitle, this.color);
}

