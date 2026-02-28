part of 'home_page.dart';

extension _HomePageTabsProfileExt on _HomePageState {
  String _formatScore(int? score) {
    if (score == null) {
      return '-';
    }
    return '$score';
  }

  String _essayRankLabel(int? score) {
    if (score == null) {
      return 'Sem rank';
    }
    if (score >= 960) {
      return 'Elite';
    }
    if (score >= 900) {
      return 'Ouro';
    }
    if (score >= 800) {
      return 'Prata';
    }
    if (score >= 700) {
      return 'Bronze';
    }
    return 'Base';
  }

  bool _isFocusedStudyItem({
    required String skill,
    required String materia,
    required int modulo,
  }) {
    final focusedSkill = _focusedStudySkill.trim();
    if (focusedSkill.isEmpty || skill.trim() != focusedSkill) {
      return false;
    }
    final focusedMateria = _focusedStudyMateria.trim();
    if (focusedMateria.isNotEmpty &&
        materia.trim().isNotEmpty &&
        materia.trim() != focusedMateria) {
      return false;
    }
    if (_focusedStudyModulo > 0 &&
        modulo > 0 &&
        modulo != _focusedStudyModulo) {
      return false;
    }
    return true;
  }

  Widget _buildStudentProfileCard() {
    final palette = context.appPalette;
    final profileItems = _studentProfiles;
    final hasSelected = profileItems.any(
      (item) => item.id == _selectedStudentProfileId,
    );
    final selectedValue = hasSelected
        ? _selectedStudentProfileId
        : (profileItems.isEmpty ? null : profileItems.first.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Perfil offline + ficha de planejamento',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Perfis cadastrados: $_studentProfileCount'),
            Text(
              'Ativo: ${_activeStudentProfile == null ? '-' : _activeStudentProfile!.displayName}',
            ),
            Text(
              'Tema/fonte: ${_themeModeLabel(_profileThemeMode)} | ${(_profileFontScale * 100).round()}%',
              style: TextStyle(color: palette.muted),
            ),
            const SizedBox(height: 8),
            if (profileItems.isEmpty)
              const Text('Nenhum perfil local ainda.')
            else
              DropdownButtonFormField<String>(
                key: ValueKey(selectedValue ?? 'no_profile'),
                initialValue: selectedValue,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Perfil ativo',
                ),
                items: profileItems
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(
                          '${item.displayName}${item.isActive ? ' (ativo)' : ''}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _busy ? null : _switchStudentProfile,
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _profileNameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Nome do perfil',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _profileTargetYearController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Ano alvo',
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _profileHoursPerDayController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Horas por dia',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('profile_theme_$_profileThemeMode'),
                    initialValue: _profileThemeMode,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Tema visual',
                    ),
                    items: const [
                      DropdownMenuItem<String>(
                        value: profileThemeModeSystem,
                        child: Text('Sistema (padrão)'),
                      ),
                      DropdownMenuItem<String>(
                        value: profileThemeModeLight,
                        child: Text('Claro'),
                      ),
                      DropdownMenuItem<String>(
                        value: profileThemeModeDark,
                        child: Text('Escuro'),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }
                            final normalized = normalizeProfileThemeMode(value);
                            _updateState(() {
                              _profileThemeMode = normalized;
                            });
                            widget.onAppearanceChanged
                                ?.call(normalized, _profileFontScale);
                          },
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tamanho da fonte: ${(_profileFontScale * 100).round()}%',
                      ),
                      Slider(
                        value: _profileFontScale,
                        min: profileFontScaleMin,
                        max: profileFontScaleMax,
                        divisions: 11,
                        label: '${(_profileFontScale * 100).round()}%',
                        onChanged: _busy
                            ? null
                            : (value) {
                                final normalized =
                                    normalizeProfileFontScale(value);
                                _updateState(() {
                                  _profileFontScale = normalized;
                                });
                                widget.onAppearanceChanged
                                    ?.call(_profileThemeMode, normalized);
                              },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _profileStudyDaysController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Dias de estudo (csv)',
                helperText: 'Ex.: seg,ter,qua,qui,sex',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _profileFocusAreaController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Área de foco',
                helperText: 'Ex.: Natureza, Matemática, Linguagens...',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _profileExamDateController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Data da prova (YYYY-MM-DD)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _profilePlannerContextController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Contexto/planner do estudante',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _busy
                      ? null
                      : () {
                          _updateState(() {
                            _selectedStudentProfileId = '';
                            _profileNameController.text = 'Novo perfil';
                            _profileTargetYearController.clear();
                            _profileStudyDaysController.text =
                                'seg,ter,qua,qui,sex';
                            _profileHoursPerDayController.text = '2';
                            _profileFocusAreaController.clear();
                            _profileExamDateController.clear();
                            _profilePlannerContextController.clear();
                            _profileThemeMode = profileThemeModeSystem;
                            _profileFontScale = profileFontScaleDefault;
                            _status =
                                'Novo perfil em edição. Salve para criar.';
                          });
                          widget.onAppearanceChanged?.call(
                            profileThemeModeSystem,
                            profileFontScaleDefault,
                          );
                        },
                  child: const Text('Novo perfil'),
                ),
                ElevatedButton(
                  onPressed: _busy ? null : () => _saveStudentProfile(),
                  child: const Text('Salvar perfil'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _exportActiveProfile,
                  child: const Text('Exportar perfil'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _profileExportPathController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Caminho de exportação (.zip)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _profileImportPathController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Caminho para importar perfil (.zip ou .json)',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : _importProfileFromFile,
              child: const Text('Importar e ativar perfil'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlannerForecastCard() {
    final palette = context.appPalette;
    final plan = _offlinePlanForecast;
    final days = plan.days;
    final riskLabel = plan.riskLabel.trim().toLowerCase();
    final riskText = riskLabel == 'alto'
        ? 'Alto'
        : riskLabel == 'medio'
            ? 'Médio'
            : riskLabel == 'baixo'
                ? 'Baixo'
                : '-';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Planejamento inteligente (offline)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Capacidade semanal: ${plan.weeklyCapacityHours.toStringAsFixed(1)}h | '
              'Carga estimada: ${plan.weeklyRequiredHours.toStringAsFixed(1)}h | '
              'Risco: $riskText',
              style: TextStyle(
                color: _riskColor(context, riskLabel),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              plan.note.isEmpty ? '-' : plan.note,
              style: TextStyle(color: palette.muted),
            ),
            const SizedBox(height: 8),
            if (days.isEmpty)
              const Text(
                'Sem previsão de agenda. Preencha o perfil e salve para gerar.',
              )
            else
              ...days.map(
                (day) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${day.dateLabel} | ${day.totalMinutes} min'),
                      const SizedBox(height: 4),
                      ...day.slots.map(
                        (slot) => Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 4),
                          child: Text(
                            '- ${slot.skill} (${slot.minutes}m) | ${slot.reason} | '
                            '${_moduleHintForSkill(slot.skill)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  StudyBlockSuggestion? _findStudyBlockSuggestionForSkill(String skill) {
    final normalized = skill.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    for (final item in _studyBlockSuggestions) {
      if (item.skill.trim().toLowerCase() == normalized) {
        return item;
      }
    }
    return null;
  }

  ModuleSuggestion? _findModuleSuggestionForSkill(String skill) {
    final normalized = skill.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    for (final item in _moduleSuggestions) {
      if (item.matchedSkill.trim().toLowerCase() == normalized) {
        return item;
      }
    }
    return null;
  }

  String _moduleHintForSkill(String skill) {
    final block = _findStudyBlockSuggestionForSkill(skill);
    if (block != null && block.modulo > 0) {
      final titlePart = block.title.trim().isEmpty ? '' : ' | ${block.title}';
      final pagePart = block.page.trim().isEmpty ? '' : ' | pág. ${block.page}';
      return 'Módulo sugerido: ${block.materia} M${block.modulo}$pagePart$titlePart';
    }

    final module = _findModuleSuggestionForSkill(skill);
    if (module != null && module.modulo > 0) {
      final titlePart = module.title.trim().isEmpty ? '' : ' | ${module.title}';
      final pagePart =
          module.page.trim().isEmpty ? '' : ' | pág. ${module.page}';
      return 'Módulo sugerido: Vol ${module.volume} ${module.materia} M${module.modulo}$pagePart$titlePart';
    }

    return 'Sem módulo sugerido para esta skill (ainda).';
  }

  Future<void> _analyzeAndSaveEssaySession() async {
    final rawFeedback = _essayFeedbackController.text.trim();
    if (rawFeedback.isEmpty) {
      _updateState(() {
        _status = 'Cole o retorno da IA para analisar/salvar a sessão.';
      });
      return;
    }

    final parserMode = EssayParserMode.fromValue(_essayParserModeSelecionado);
    final parsed = EssayFeedbackParser.parse(
      rawFeedback: rawFeedback,
      mode: parserMode,
    );

    if (!parsed.isValid && parserMode == EssayParserMode.validado) {
      _updateState(() {
        _status =
            'Formato inválido no modo validado. Esperado C1..C5 no texto da IA.';
      });
      return;
    }

    _updateState(() {
      _busy = true;
      _status = 'Salvando sessão de redação...';
    });

    try {
      final db = await _localDatabase.open();
      final themeTitle = _essayThemeController.text.trim().isEmpty
          ? 'Tema não informado'
          : _essayThemeController.text.trim();
      final generatedPrompt = EssayPromptBuilder.buildThemeGenerationPrompt(
        focusHint: _essayFocusController.text.trim(),
      );
      final correctionPrompt = EssayPromptBuilder.buildCorrectionPrompt(
        themeTitle: themeTitle,
        studentContext: _essayContextController.text.trim(),
      );

      await _localDatabase.insertEssaySession(
        db,
        input: EssaySessionInput(
          themeTitle: themeTitle,
          themeSource: _essayThemeSourceSelecionado,
          generatedPrompt: generatedPrompt,
          correctionPrompt: correctionPrompt,
          submittedText: _essayStudentTextController.text.trim(),
          submittedPhotoPath: '',
          iaFeedbackRaw: _essayFeedbackController.text,
          parserMode: parserMode.value,
          c1Score: parsed.c1,
          c2Score: parsed.c2,
          c3Score: parsed.c3,
          c4Score: parsed.c4,
          c5Score: parsed.c5,
          finalScore: parsed.finalScore,
          legibilityWarning: parsed.hasLegibilityWarning,
        ),
      );

      await _refreshStats();
      if (!mounted) {
        return;
      }

      final legibilityNote = parsed.hasLegibilityWarning
          ? ' | alerta de legibilidade: ${parsed.illegibleCount} [ILEGÍVEL]'
          : '';
      final rankNote = ' | rank ${_essayRankLabel(parsed.finalScore)}';
      _updateState(() {
        _status =
            'Sessão salva | C1 ${_formatScore(parsed.c1)} C2 ${_formatScore(parsed.c2)} '
            'C3 ${_formatScore(parsed.c3)} C4 ${_formatScore(parsed.c4)} '
            'C5 ${_formatScore(parsed.c5)} | Final ${_formatScore(parsed.finalScore)}'
            '$rankNote$legibilityNote';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _updateState(() {
        _status = 'Falha ao salvar sessão de redação: $error';
      });
    } finally {
      if (mounted) {
        _updateState(() {
          _busy = false;
        });
      }
    }
  }

  Widget _buildWeakSkillsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Habilidades com maior dificuldade',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_weakSkills.isEmpty)
              const Text(
                  'Sem dados ainda. Resolva questões para gerar diagnóstico.')
            else
              ..._weakSkills.map(
                (item) => Text(
                  '${item.skill} | acurácia ${_percent(item.accuracy)}% '
                  '(${item.correct}/${item.total})',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillPriorityCard() {
    if (_skillPriorities.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Priorização automática por lacuna',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Sem dados suficientes. Resolva questões para calcular prioridade.',
              ),
            ],
          ),
        ),
      );
    }

    final focoCount =
        _skillPriorities.where((item) => item.band == 'foco').length;
    final manutencaoCount =
        _skillPriorities.where((item) => item.band == 'manutencao').length;
    final forteCount =
        _skillPriorities.where((item) => item.band == 'forte').length;
    final topItems = _skillPriorities.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Priorização automática por lacuna',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Faixas | foco: $focoCount | manutenção: $manutencaoCount | forte: $forteCount',
            ),
            const SizedBox(height: 8),
            ...topItems.map(
              (item) => Text(
                '${item.skill} | ${item.band} | prioridade ${item.priorityScore.toStringAsFixed(3)} '
                '| acurácia ${_percent(item.accuracy)}% | tentativas ${item.attempts} '
                '| recência ${item.daysSinceLastSeen}d',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdaptiveSessionCard() {
    final totalQuestions = _readTreinoQuantidade();
    final slots = _buildAdaptiveSlots(totalQuestions: totalQuestions);
    final focusCount = slots
        .where((slot) => slot.band == 'foco')
        .fold<int>(0, (sum, slot) => sum + slot.questionCount);
    final maintenanceCount = slots
        .where((slot) => slot.band == 'manutencao')
        .fold<int>(0, (sum, slot) => sum + slot.questionCount);
    final strongCount = slots
        .where((slot) => slot.band == 'forte')
        .fold<int>(0, (sum, slot) => sum + slot.questionCount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sessão adaptativa sugerida (60/30/10)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Total alvo: $totalQuestions questões | '
              'foco $focusCount | manutenção $maintenanceCount | forte $strongCount',
            ),
            const SizedBox(height: 8),
            if (slots.isEmpty)
              const Text(
                'Sem slots adaptativos ainda. Resolva mais questões para gerar distribuição.',
              )
            else
              ...slots.map(
                (slot) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${slot.skill} | ${slot.band} | '
                          '${slot.questionCount} questão(ões) | '
                          'prioridade ${slot.priorityScore.toStringAsFixed(3)}',
                        ),
                      ),
                      OutlinedButton(
                        onPressed:
                            _busy ? null : () => _iniciarSlotAdaptativo(slot),
                        child: const Text('Iniciar'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleSuggestionsCard() {
    final palette = context.appPalette;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Módulos sugeridos para revisão (livro)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_moduleSuggestions.isEmpty)
              const Text(
                  'Sem recomendações ainda. Registre tentativas e habilidades no conteúdo.')
            else
              ..._moduleSuggestions.map(
                (item) {
                  final isFocused = _isFocusedStudyItem(
                    skill: item.matchedSkill,
                    materia: item.materia,
                    modulo: item.modulo,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color:
                              isFocused ? palette.accent : Colors.grey.shade400,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: isFocused
                            ? palette.accent.withValues(alpha: 0.10)
                            : null,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Skill ${item.matchedSkill} -> Vol ${item.volume} | ${item.materia}'
                            ' | Módulo ${item.modulo} | pág. ${item.page.isEmpty ? '-' : item.page}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (item.title.trim().isNotEmpty) Text(item.title),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () =>
                                        _iniciarTreinoModuloSuggestion(item),
                                child: const Text('Treinar skill'),
                              ),
                              if (isFocused)
                                Text(
                                  'Módulo em foco',
                                  style: TextStyle(color: palette.accent),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReelsTab() {
    const alternatives = ['A', 'B', 'C', 'D', 'E'];

    String previewText(String value) {
      final normalized = value.trim().replaceAll('\n', ' ');
      if (normalized.length <= 720) {
        return normalized;
      }
      return '${normalized.substring(0, 720)}...';
    }

    if (_plannerReels.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reels de questões',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ainda não há questões para montar o feed inteligente.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Registre tentativas (ou inicialize a demo) para o planner priorizar automaticamente as próximas questões.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: _busy ? null : _refreshStats,
                        child: const Text('Tentar novamente'),
                      ),
                      OutlinedButton(
                        onPressed: _busy ? null : _seedDemo,
                        child: const Text('Inicializar demo local'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Feed inteligente: ${_plannerReels.length} questão(ões) recomendadas',
                ),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _refreshStats,
                child: const Text('Atualizar feed'),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: _plannerReels.length,
            onPageChanged: (index) {
              _updateState(() {
                _reelCurrentIndex = index;
                _reelQuestionStartedAt = DateTime.now();
              });
            },
            itemBuilder: (context, index) {
              final entry = _plannerReels[index];
              final question = entry.question;
              final marked = _reelMarkedAnswers[question.id] ?? '';
              final feedback = _reelFeedbackByQuestion[question.id] ?? '';
              final answered = marked.isNotEmpty;

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView(
                      children: [
                        Text(
                          'Reel ${index + 1}/${_plannerReels.length} | ${_bandLabel(entry.band)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Skill ${entry.skill.isEmpty ? '-' : entry.skill} | prioridade ${entry.priorityScore.toStringAsFixed(3)}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${question.year}/${question.day}/${question.number}'
                          '${question.variation > 1 ? ' (v${question.variation})' : ''}'
                          ' | ${question.area}${question.discipline.trim().isEmpty ? '' : ' | ${question.discipline}'}',
                        ),
                        if (question.difficulty.trim().isNotEmpty)
                          Text('Dificuldade: ${question.difficulty}'),
                        if (question.hasImage)
                          const Text('Inclui imagem/contexto visual.'),
                        const SizedBox(height: 8),
                        Text(previewText(question.statement)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: alternatives
                              .map(
                                (option) => OutlinedButton(
                                  onPressed: _busy || answered
                                      ? null
                                      : () => _responderReel(option),
                                  child: Text(option),
                                ),
                              )
                              .toList(),
                        ),
                        if (marked.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Resposta marcada: $marked'),
                        ],
                        if (feedback.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(feedback),
                        ],
                        if (!answered) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'Toque em A/B/C/D/E para registrar e receber feedback imediato.',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAulasTab() {
    final palette = context.appPalette;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aulas e módulos recomendados',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Esta área conecta o desempenho atual com os módulos do livro e as aulas que serão construídas com IA + revisão manual.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildModuleSuggestionsCard(),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Próximos blocos do planner',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_studyBlockSuggestions.isEmpty)
                  const Text(
                    'Sem blocos recomendados no momento. Resolva algumas questões no reels para ativar recomendações por skill.',
                  )
                else
                  ..._studyBlockSuggestions.map(
                    (item) {
                      final isFocused = _isFocusedStudyItem(
                        skill: item.skill,
                        materia: item.materia,
                        modulo: item.modulo,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isFocused
                                  ? palette.accent
                                  : Colors.grey.shade400,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: isFocused
                                ? palette.accent.withValues(alpha: 0.10)
                                : null,
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.skill} | ${item.recommendedQuestions} questões | '
                                '${item.recommendedMinutes} min',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${item.materia.isEmpty ? 'Matéria não mapeada' : item.materia}'
                                '${item.modulo > 0 ? ' | Módulo ${item.modulo}' : ''}'
                                '${item.page.trim().isEmpty ? '' : ' | pág. ${item.page}'}',
                              ),
                              if (item.title.trim().isNotEmpty)
                                Text(item.title),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _iniciarBlocoSugestao(item),
                                    child: const Text('Abrir treino'),
                                  ),
                                  OutlinedButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _revisarTeoriaSuggestion(item),
                                    child: const Text('Revisar teoria'),
                                  ),
                                  if (isFocused)
                                    Text(
                                      'Foco atual',
                                      style: TextStyle(color: palette.accent),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPerfilTab() {
    final palette = context.appPalette;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Versão de conteúdo: $_contentVersion'),
                const SizedBox(height: 8),
                Text('Questões no banco local: $_questionCount'),
                Text('Módulos de livro no banco local: $_bookModuleCount'),
                Text('Vínculos módulo x questão: $_moduleQuestionMatchCount'),
                Text('Sessões de redação: $_essaySessionCount'),
                Text('Tentativas registradas: $_attemptCount'),
                Text('Acurácia global: ${_percent(_globalAccuracy)}%'),
                Text('Perfis locais: $_studentProfileCount'),
                Text(
                  'Perfil ativo: ${_activeStudentProfile == null ? '-' : _activeStudentProfile!.displayName}',
                ),
                Text('Banco local: $_databasePath'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildStudentProfileCard(),
        const SizedBox(height: 12),
        _buildPlannerForecastCard(),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Operação local',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _manifestController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'URL do manifest.json',
                    helperText:
                        'Ex.: release no GitHub Pages, S3 ou servidor próprio.',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _autoUpdateStatusLabel(),
                  style: TextStyle(color: palette.muted),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: _busy ? null : _seedDemo,
                      child: const Text('Inicializar demo local'),
                    ),
                    ElevatedButton(
                      onPressed: _busy ? null : _runUpdate,
                      child: const Text('Procurar atualização agora'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _recordDemoAttempt(false),
                      child: const Text('Simular erro'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _recordDemoAttempt(true),
                      child: const Text('Simular acerto'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : _refreshStats,
                      child: const Text('Recarregar status'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            title: const Text('Ferramentas avançadas'),
            subtitle: const Text(
              'Diagnóstico, treino completo, filtros, redação e intercorrelação',
            ),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              _buildWeakSkillsCard(),
              const SizedBox(height: 12),
              _buildDiagnosticoCard(),
              const SizedBox(height: 12),
              _buildSkillPriorityCard(),
              const SizedBox(height: 12),
              _buildAdaptiveSessionCard(),
              const SizedBox(height: 12),
              _buildStudyBlockSuggestionsCard(),
              const SizedBox(height: 12),
              _buildRecentAttemptsCard(),
              const SizedBox(height: 12),
              _buildTreinoCard(),
              const SizedBox(height: 12),
              _buildQuestionFiltersCard(),
              const SizedBox(height: 12),
              _buildSimuladoCard(),
              const SizedBox(height: 12),
              _buildIntercorrelationFiltersCard(),
              const SizedBox(height: 12),
              _buildEssayPromptBuilderCard(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SelectableText(
          _status,
          style: TextStyle(
            color: _statusColor(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
