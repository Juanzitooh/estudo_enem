part of 'home_page.dart';

const Color _lime = Color(0xFFD7F47A);
const Color _coral = Color(0xFFFF8E70);
const Color _deepGreen = Color(0xFF173F3C);

extension _HomePageDashboardExt on _HomePageState {
  Widget _buildResponsiveShell(Widget tabBody) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktopShell = constraints.maxWidth >= 1080;
        if (!useDesktopShell) {
          return _buildMobileShell(tabBody);
        }
        return _buildDesktopShell(tabBody);
      },
    );
  }

  Widget _buildDesktopShell(Widget tabBody) {
    final palette = context.appPalette;
    return Scaffold(
      body: Row(
        children: [
          _DashboardSidebar(
            selectedIndex: _selectedTabIndex,
            profileName: _activeStudentProfile?.displayName ?? 'Visitante',
            onSelected: _selectTab,
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: palette.muted.withValues(alpha: 0.13),
          ),
          Expanded(
            child: Column(
              children: [
                _DashboardTopBar(
                  title: _tabTitle(),
                  status: _status,
                  onToggleTheme: _toggleTheme,
                ),
                if (_busy) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1480),
                      child: tabBody,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileShell(Widget tabBody) {
    final palette = context.appPalette;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 56,
        leading: const Padding(
          padding: EdgeInsets.only(left: 14),
          child: _BrandMark(size: 38),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IMPULSO',
              style: TextStyle(
                color: palette.text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              _tabTitle(),
              style: TextStyle(color: palette.muted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Alternar tema',
            onPressed: _toggleTheme,
            icon: const Icon(Icons.contrast_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: tabBody),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: _selectTab,
        destinations: _appDestinations
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }

  void _selectTab(int index) {
    _updateState(() {
      _selectedTabIndex = index;
    });
  }

  Future<void> _exploreDemo() async {
    if (_questionCount == 0) {
      await _seedDemo();
    }
    if (!mounted) {
      return;
    }
    _selectTab(_HomePageState._tabQuestoes);
  }

  String get _dashboardName {
    final displayName = _activeStudentProfile?.displayName.trim() ?? '';
    if (displayName.isEmpty) {
      return 'visitante';
    }
    return displayName.split(RegExp(r'\s+')).first;
  }

  String get _questionMetric {
    if (_questionCount <= 0) {
      return '2 mil+';
    }
    return _questionCount.toString();
  }

  String get _accuracyMetric {
    if (_attemptCount <= 0) {
      return '—';
    }
    return '${(_globalAccuracy * 100).round()}%';
  }

  Widget _buildDashboardTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DashboardHero(
                  name: _dashboardName,
                  attempts: _attemptCount,
                  accuracy: _globalAccuracy,
                  onExplore: _exploreDemo,
                  onOpenLessons: () => _selectTab(_HomePageState._tabAulas),
                ),
                const SizedBox(height: 22),
                _DashboardMetrics(
                  items: [
                    _DashboardMetric(
                      icon: Icons.library_books_rounded,
                      value: _questionMetric,
                      label: 'questões mapeadas',
                      color: _lime,
                    ),
                    _DashboardMetric(
                      icon: Icons.track_changes_rounded,
                      value: _accuracyMetric,
                      label: 'acurácia atual',
                      color: _coral,
                    ),
                    _DashboardMetric(
                      icon: Icons.auto_stories_rounded,
                      value: '${_bookModuleCount <= 0 ? 6 : _bookModuleCount}',
                      label: _bookModuleCount <= 0
                          ? 'volumes na trilha'
                          : 'módulos disponíveis',
                      color: const Color(0xFFA8D8C4),
                    ),
                    _DashboardMetric(
                      icon: Icons.bolt_rounded,
                      value: '$_attemptCount',
                      label: 'respostas registradas',
                      color: const Color(0xFFFFC7B8),
                    ),
                  ],
                ),
                const SizedBox(height: 38),
                const _DashboardSectionTitle(
                  eyebrow: 'PLANEJAMENTO ADAPTATIVO',
                  title: 'Uma rotina que cabe na sua semana',
                  description:
                      'O plano combina tempo disponível, desempenho e revisão '
                      'para indicar o próximo passo com clareza.',
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final horizontal = constraints.maxWidth >= 840;
                    final children = [
                      Expanded(
                        flex: 6,
                        child: _WeeklyPlanCard(
                          plan: _offlinePlanForecast,
                          onOpenProfile: () =>
                              _selectTab(_HomePageState._tabPerfil),
                        ),
                      ),
                      const SizedBox(width: 18, height: 18),
                      Expanded(
                        flex: 4,
                        child: _FocusCard(
                          weakSkills: _weakSkills,
                          onPractice: () =>
                              _selectTab(_HomePageState._tabQuestoes),
                        ),
                      ),
                    ];
                    if (horizontal) {
                      return Row(children: children);
                    }
                    return Column(
                      children: [
                        _WeeklyPlanCard(
                          plan: _offlinePlanForecast,
                          onOpenProfile: () =>
                              _selectTab(_HomePageState._tabPerfil),
                        ),
                        const SizedBox(height: 18),
                        _FocusCard(
                          weakSkills: _weakSkills,
                          onPractice: () =>
                              _selectTab(_HomePageState._tabQuestoes),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 42),
                const _DashboardSectionTitle(
                  eyebrow: 'COMO FUNCIONA',
                  title: 'Do diagnóstico ao domínio',
                  description:
                      'Uma jornada curta, mensurável e construída para manter '
                      'o foco no que realmente melhora sua nota.',
                ),
                const SizedBox(height: 18),
                _JourneyGrid(
                  onOpenQuestions: () =>
                      _selectTab(_HomePageState._tabQuestoes),
                  onOpenLessons: () => _selectTab(_HomePageState._tabAulas),
                  onOpenProfile: () => _selectTab(_HomePageState._tabPerfil),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardSidebar extends StatelessWidget {
  const _DashboardSidebar({
    required this.selectedIndex,
    required this.profileName,
    required this.onSelected,
  });

  final int selectedIndex;
  final String profileName;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      width: 248,
      color: palette.surface,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandLockup(),
          const SizedBox(height: 40),
          Text(
            'NAVEGAÇÃO',
            style: TextStyle(
              color: palette.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          ..._appDestinations.indexed.map((entry) {
            final index = entry.$1;
            final item = entry.$2;
            final selected = selectedIndex == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _SidebarItem(
                item: item,
                selected: selected,
                onTap: () => onSelected(index),
              ),
            );
          }),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const _ProfileAvatar(size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF61B983),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Dados locais',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _AppDestination item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final foreground = selected ? _deepGreen : palette.muted;
    return Material(
      color: selected ? _lime : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(selected ? item.selectedIcon : item.icon, color: foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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

class _DashboardTopBar extends StatelessWidget {
  const _DashboardTopBar({
    required this.title,
    required this.status,
    required this.onToggleTheme,
  });

  final String title;
  final String status;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 34),
      color: palette.background,
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Alternar tema claro/escuro',
            onPressed: onToggleTheme,
            icon: const Icon(Icons.contrast_rounded),
          ),
          const SizedBox(width: 12),
          const _ProfileAvatar(size: 42),
        ],
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Semantics(
      label: 'Impulso ENEM',
      child: Row(
        children: [
          const _BrandMark(size: 44),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IMPULSO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                Text(
                  'estudo inteligente',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.muted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _deepGreen,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        Icons.north_east_rounded,
        color: _lime,
        size: size * 0.58,
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Perfil do estudante',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _coral.withValues(alpha: 0.26),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person_rounded,
          color: const Color(0xFF9A4735),
          size: size * 0.58,
        ),
      ),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.name,
    required this.attempts,
    required this.accuracy,
    required this.onExplore,
    required this.onOpenLessons,
  });

  final String name;
  final int attempts;
  final double accuracy;
  final VoidCallback onExplore;
  final VoidCallback onOpenLessons;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF173F3C), Color(0xFF27675B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _deepGreen.withValues(alpha: 0.20),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -80,
            top: -120,
            child: _DecorativeOrb(size: 300, color: _lime),
          ),
          const Positioned(
            left: 410,
            bottom: -95,
            child: _DecorativeOrb(size: 190, color: _coral),
          ),
          Padding(
            padding: const EdgeInsets.all(30),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontal = constraints.maxWidth >= 760;
                final copy = _HeroCopy(
                  name: name,
                  onExplore: onExplore,
                  onOpenLessons: onOpenLessons,
                );
                final progress = _HeroProgressCard(
                  attempts: attempts,
                  accuracy: accuracy,
                );
                if (!horizontal) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      copy,
                      const SizedBox(height: 26),
                      progress,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 6, child: copy),
                    const SizedBox(width: 42),
                    Expanded(flex: 4, child: progress),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({
    required this.name,
    required this.onExplore,
    required this.onOpenLessons,
  });

  final String name;
  final VoidCallback onExplore;
  final VoidCallback onOpenLessons;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: const Text(
            '✦  APRENDIZADO OFFLINE-FIRST',
            style: TextStyle(
              color: _lime,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Olá, $name.',
          style: const TextStyle(
            color: Color(0xFFDAE7E1),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Seu próximo passo\ncomeça aqui.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 42,
            height: 1.06,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Questões, aulas e um plano adaptativo reunidos em uma experiência '
          'simples — seus dados continuam no seu dispositivo.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 15,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _lime,
                foregroundColor: _deepGreen,
              ),
              onPressed: onExplore,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Explorar demonstração'),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.52),
                ),
              ),
              onPressed: onOpenLessons,
              child: const Text('Conhecer as aulas'),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroProgressCard extends StatelessWidget {
  const _HeroProgressCard({required this.attempts, required this.accuracy});

  final int attempts;
  final double accuracy;

  @override
  Widget build(BuildContext context) {
    final hasProgress = attempts > 0;
    final progress = hasProgress ? accuracy.clamp(0.08, 1.0) : 0.64;
    final percentage = (progress * 100).round();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _lime.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: _deepGreen,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'Ritmo da semana',
                  style: TextStyle(
                    color: _deepGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                hasProgress ? 'AO VIVO' : 'PRÉVIA',
                style: const TextStyle(
                  color: Color(0xFF5C716B),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                '$percentage%',
                style: const TextStyle(
                  color: _deepGreen,
                  fontSize: 42,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 4),
                child: Text(
                  'da meta',
                  style: TextStyle(color: Color(0xFF60716D)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              color: _coral,
              backgroundColor: const Color(0xFFE7ECE7),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const _MiniDay(label: 'S', active: true),
              const _MiniDay(label: 'T', active: true),
              const _MiniDay(label: 'Q', active: true),
              const _MiniDay(label: 'Q', active: false),
              _MiniDay(label: 'S', active: hasProgress),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniDay extends StatelessWidget {
  const _MiniDay({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? _deepGreen : const Color(0xFFE7ECE7),
              shape: BoxShape.circle,
            ),
            child: active
                ? const Icon(Icons.check_rounded, color: _lime, size: 16)
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF60716D),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorativeOrb extends StatelessWidget {
  const _DecorativeOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.18), width: 2),
      ),
    );
  }
}

class _DashboardMetric {
  const _DashboardMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
}

class _DashboardMetrics extends StatelessWidget {
  const _DashboardMetrics({required this.items});

  final List<_DashboardMetric> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 880
            ? 4
            : constraints.maxWidth >= 520
                ? 2
                : 1;
        const spacing = 14.0;
        final width =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _MetricCard(item: item),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.item});

  final _DashboardMetric item;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.52),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(item.icon, color: _deepGreen),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                  Text(
                    item.label,
                    maxLines: 2,
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 11,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardSectionTitle extends StatelessWidget {
  const _DashboardSectionTitle({
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: TextStyle(
              color: palette.warning,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              height: 1.15,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(color: palette.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _WeeklyPlanCard extends StatelessWidget {
  const _WeeklyPlanCard({required this.plan, required this.onOpenProfile});

  final OfflinePlanForecast plan;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final hasPlan = plan.days.isNotEmpty;
    final rows = hasPlan
        ? plan.days
            .take(4)
            .map(
              (day) => (
                day.dateLabel,
                day.slots.isEmpty ? 'Revisão livre' : day.slots.first.skill,
                day.totalMinutes,
              ),
            )
            .toList()
        : const [
            ('Segunda', 'Linguagens · interpretação', 45),
            ('Quarta', 'Humanas · repertório', 60),
            ('Sexta', 'Matemática · fundamentos', 50),
          ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                const Text(
                  'Plano da semana',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                TextButton(
                  onPressed: onOpenProfile,
                  child: Text(hasPlan ? 'Ajustar plano' : 'Criar meu plano'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...rows.indexed.map((entry) {
              final index = entry.$1;
              final row = entry.$2;
              return Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: index == 0
                      ? _lime.withValues(alpha: 0.22)
                      : palette.background,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: index == 0 ? _lime : palette.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: _deepGreen,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.$1,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            row.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(color: palette.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${row.$3} min',
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.weakSkills, required this.onPractice});

  final List<WeakSkillStat> weakSkills;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final skill = weakSkills.isEmpty ? null : weakSkills.first;
    final label = skill?.skill ?? 'H18 · Leitura e interpretação';
    final accuracy = skill?.accuracy ?? 0.42;
    return Card(
      color: _coral.withValues(alpha: 0.18),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _coral.withValues(alpha: 0.34),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'FOCO RECOMENDADO',
                style: TextStyle(
                  color: Color(0xFF7A3A2C),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(
              Icons.center_focus_strong_rounded,
              color: _deepGreen,
              size: 34,
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: const TextStyle(
                fontSize: 20,
                height: 1.2,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Uma sessão curta agora ajuda a consolidar essa habilidade e '
              'melhora as próximas recomendações.',
              style: TextStyle(color: palette.muted, height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: accuracy,
                      minHeight: 8,
                      color: _coral,
                      backgroundColor: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(accuracy * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onPractice,
                icon: const Icon(Icons.bolt_rounded),
                label: const Text('Praticar agora'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyGrid extends StatelessWidget {
  const _JourneyGrid({
    required this.onOpenQuestions,
    required this.onOpenLessons,
    required this.onOpenProfile,
  });

  final VoidCallback onOpenQuestions;
  final VoidCallback onOpenLessons;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final items = [
      _JourneyItem(
        number: '01',
        icon: Icons.bolt_rounded,
        title: 'Pratique',
        description:
            'Resolva questões reais em um feed que prioriza suas lacunas.',
        color: _lime,
        action: onOpenQuestions,
      ),
      _JourneyItem(
        number: '02',
        icon: Icons.auto_stories_rounded,
        title: 'Entenda',
        description:
            'Receba aulas e recuperações curtas conectadas aos seus erros.',
        color: _coral,
        action: onOpenLessons,
      ),
      _JourneyItem(
        number: '03',
        icon: Icons.insights_rounded,
        title: 'Evolua',
        description:
            'Acompanhe habilidades, conceitos e consistência em um só lugar.',
        color: const Color(0xFFA8D8C4),
        action: onOpenProfile,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 800 ? 3 : 1;
        const spacing = 16.0;
        final width =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _JourneyCard(item: item),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _JourneyItem {
  const _JourneyItem({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.action,
  });

  final String number;
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback action;
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.item});

  final _JourneyItem item;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Card(
      child: InkWell(
        onTap: item.action,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(item.icon, color: _deepGreen),
                  ),
                  const Spacer(),
                  Text(
                    item.number,
                    style: TextStyle(
                      color: palette.muted.withValues(alpha: 0.52),
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                item.description,
                style: TextStyle(color: palette.muted, height: 1.45),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Text(
                    'Explorar',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(width: 5),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
