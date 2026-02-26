import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../data/local_database.dart';
import '../essay/essay_feedback_parser.dart';
import '../essay/essay_prompt_builder.dart';
import '../update/content_updater.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final LocalDatabase _localDatabase = LocalDatabase();
  final TextEditingController _manifestController = TextEditingController(
    text: AppConfig.defaultManifestUrl,
  );
  final TextEditingController _matchMateriaController = TextEditingController();
  final TextEditingController _matchAssuntoController = TextEditingController();
  final TextEditingController _matchScoreController = TextEditingController(
    text: '0.50',
  );
  final TextEditingController _essayThemeController = TextEditingController();
  final TextEditingController _essayFocusController = TextEditingController();
  final TextEditingController _essayContextController = TextEditingController();
  final TextEditingController _essayFeedbackController =
      TextEditingController();

  bool _busy = false;
  String _status = 'Pronto.';
  String _essayPromptPreview = '';
  String _contentVersion = '0';
  int _questionCount = 0;
  int _bookModuleCount = 0;
  int _moduleQuestionMatchCount = 0;
  int _essaySessionCount = 0;
  int _attemptCount = 0;
  double _globalAccuracy = 0;
  String _databasePath = '-';
  List<WeakSkillStat> _weakSkills = const [];
  List<ModuleSuggestion> _moduleSuggestions = const [];
  List<ModuleQuestionMatch> _moduleQuestionMatches = const [];
  List<EssaySessionRecord> _recentEssaySessions = const [];
  String _matchTipoSelecionado = '';
  String _essayThemeSourceSelecionado = 'ia';
  String _essayParserModeSelecionado = EssayParserMode.livre.value;

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  @override
  void dispose() {
    _manifestController.dispose();
    _matchMateriaController.dispose();
    _matchAssuntoController.dispose();
    _matchScoreController.dispose();
    _essayThemeController.dispose();
    _essayFocusController.dispose();
    _essayContextController.dispose();
    _essayFeedbackController.dispose();
    super.dispose();
  }

  String _percent(double value) {
    return (value * 100).toStringAsFixed(1);
  }

  double _readMinScore() {
    final parsed = double.tryParse(
      _matchScoreController.text.trim().replaceAll(',', '.'),
    );
    if (parsed == null || parsed <= 0) {
      return 0;
    }
    if (parsed > 1) {
      return 1;
    }
    return parsed;
  }

  ModuleQuestionMatchFilter _buildMatchFilter() {
    return ModuleQuestionMatchFilter(
      materia: _matchMateriaController.text.trim(),
      assunto: _matchAssuntoController.text.trim(),
      tipoMatch: _matchTipoSelecionado,
      minScore: _readMinScore(),
      limit: 20,
    );
  }

  Future<void> _refreshStats() async {
    final db = await _localDatabase.open();
    final questionCount = await _localDatabase.countQuestions(db);
    final bookModuleCount = await _localDatabase.countBookModules(db);
    final moduleQuestionMatchCount =
        await _localDatabase.countModuleQuestionMatches(db);
    final essaySessionCount = await _localDatabase.countEssaySessions(db);
    final attemptCount = await _localDatabase.countAttempts(db);
    final accuracy = await _localDatabase.globalAccuracy(db);
    final databasePath = await _localDatabase.databasePath();
    final weakSkills = await _localDatabase.loadWeakSkills(db, limit: 5);
    final moduleSuggestions = await _localDatabase.recommendModulesByWeakSkills(
      db,
      weakSkillLimit: 3,
      modulePerSkill: 2,
      maxTotal: 8,
    );
    final moduleQuestionMatches =
        await _localDatabase.searchModuleQuestionMatches(
      db,
      filter: _buildMatchFilter(),
    );
    final recentEssaySessions = await _localDatabase.loadRecentEssaySessions(
      db,
      limit: 5,
    );
    final version = await _localDatabase.getContentVersion(db);

    if (!mounted) {
      return;
    }
    setState(() {
      _questionCount = questionCount;
      _bookModuleCount = bookModuleCount;
      _moduleQuestionMatchCount = moduleQuestionMatchCount;
      _essaySessionCount = essaySessionCount;
      _attemptCount = attemptCount;
      _globalAccuracy = accuracy;
      _databasePath = databasePath;
      _weakSkills = weakSkills;
      _moduleSuggestions = moduleSuggestions;
      _moduleQuestionMatches = moduleQuestionMatches;
      _recentEssaySessions = recentEssaySessions;
      _contentVersion = version;
    });
  }

  Future<void> _seedDemo() async {
    setState(() {
      _busy = true;
      _status = 'Carregando dados locais de demonstração...';
    });

    try {
      final db = await _localDatabase.open();
      await _localDatabase.seedLocalDemoIfEmpty(db);
      await _refreshStats();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Demo local carregada.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Falha ao carregar demo: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _recordDemoAttempt(bool isCorrect) async {
    setState(() {
      _busy = true;
      _status = isCorrect
          ? 'Registrando acerto de demonstração...'
          : 'Registrando erro de demonstração...';
    });

    try {
      final db = await _localDatabase.open();
      await _localDatabase.recordDemoAttempt(db, isCorrect: isCorrect);
      await _refreshStats();

      if (!mounted) {
        return;
      }
      setState(() {
        _status = isCorrect
            ? 'Acerto de demonstração registrado.'
            : 'Erro de demonstração registrado.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Falha ao registrar tentativa demo: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _runUpdate() async {
    final manifestText = _manifestController.text.trim();
    if (manifestText.isEmpty) {
      setState(() {
        _status = 'Informe uma URL de manifest.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Buscando update...';
    });

    try {
      final updater = ContentUpdater(
        localDatabase: _localDatabase,
        manifestUri: Uri.parse(manifestText),
      );
      final result = await updater.checkAndUpdate();
      await _refreshStats();

      if (!mounted) {
        return;
      }
      setState(() {
        _status = result.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Falha no update: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _applyMatchFilters() async {
    setState(() {
      _busy = true;
      _status = 'Aplicando filtros de intercorrelação...';
    });

    try {
      await _refreshStats();
      if (!mounted) {
        return;
      }
      setState(() {
        _status =
            'Filtro aplicado. ${_moduleQuestionMatches.length} vínculo(s) exibidos.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Falha ao aplicar filtro: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _clearMatchFilters() async {
    _matchMateriaController.clear();
    _matchAssuntoController.clear();
    _matchScoreController.text = '0.50';
    setState(() {
      _matchTipoSelecionado = '';
    });
    await _applyMatchFilters();
  }

  Future<void> _copyPrompt({
    required String prompt,
    required String successMessage,
  }) async {
    await Clipboard.setData(ClipboardData(text: prompt));
    if (!mounted) {
      return;
    }
    setState(() {
      _essayPromptPreview = prompt;
      _status = successMessage;
    });
  }

  Future<void> _copyEssayThemePrompt() async {
    final prompt = EssayPromptBuilder.buildThemeGenerationPrompt(
      focusHint: _essayFocusController.text.trim(),
    );
    await _copyPrompt(
      prompt: prompt,
      successMessage: 'Prompt de geração de tema copiado.',
    );
  }

  Future<void> _copyEssayCorrectionPrompt() async {
    final theme = _essayThemeController.text.trim();
    if (theme.isEmpty) {
      setState(() {
        _status = 'Informe o tema da redação para gerar o prompt de correção.';
      });
      return;
    }

    final prompt = EssayPromptBuilder.buildCorrectionPrompt(
      themeTitle: theme,
      studentContext: _essayContextController.text.trim(),
    );
    await _copyPrompt(
      prompt: prompt,
      successMessage: 'Prompt de correção de redação copiado.',
    );
  }

  String _formatScore(int? score) {
    if (score == null) {
      return '-';
    }
    return '$score';
  }

  Future<void> _analyzeAndSaveEssaySession() async {
    final rawFeedback = _essayFeedbackController.text.trim();
    if (rawFeedback.isEmpty) {
      setState(() {
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
      setState(() {
        _status =
            'Formato inválido no modo validado. Esperado C1..C5 no texto da IA.';
      });
      return;
    }

    setState(() {
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
          submittedText: '',
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
      setState(() {
        _status =
            'Sessão salva | C1 ${_formatScore(parsed.c1)} C2 ${_formatScore(parsed.c2)} '
            'C3 ${_formatScore(parsed.c3)} C4 ${_formatScore(parsed.c4)} '
            'C5 ${_formatScore(parsed.c5)} | Final ${_formatScore(parsed.finalScore)}'
            '$legibilityNote';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Falha ao salvar sessão de redação: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
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

  Widget _buildModuleSuggestionsCard() {
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
                (item) => Text(
                  'Skill ${item.matchedSkill} -> Vol ${item.volume} | ${item.materia} '
                  '| Módulo ${item.modulo} | pág. ${item.page.isEmpty ? '-' : item.page} '
                  '${item.title.isEmpty ? '' : '| ${item.title}'}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntercorrelationFiltersCard() {
    const matchTypes = ['', 'direto', 'relacionado', 'interdisciplinar'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtro local de módulo x questão',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _matchMateriaController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Matéria (ex.: Biologia 1)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _matchAssuntoController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Tag/assunto (ex.: termodinamica)',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _matchScoreController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Score mínimo (0..1)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_matchTipoSelecionado),
                    initialValue: _matchTipoSelecionado,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Tipo de match',
                    ),
                    items: matchTypes
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value.isEmpty ? 'Todos' : value),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) {
                            setState(() {
                              _matchTipoSelecionado = value ?? '';
                            });
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : _applyMatchFilters,
                  child: const Text('Aplicar filtro'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _clearMatchFilters,
                  child: const Text('Limpar filtro'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_moduleQuestionMatches.isEmpty)
              const Text('Sem vínculos para os filtros atuais.')
            else
              ..._moduleQuestionMatches.map(
                (item) => Text(
                  'Q ${item.year}/${item.day}/${item.number} | ${item.materia} '
                  '| V${item.volume} M${item.modulo} | ${item.tipoMatch} '
                  '(${_percent(item.scoreMatch)}%)'
                  '${item.assuntosMatch.isEmpty ? '' : ' | ${item.assuntosMatch}'}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEssayPromptBuilderCard() {
    const themeSources = ['ia', 'offline'];
    const parserModes = ['livre', 'validado'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Prompt Builder de Redação (IA externa)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _essayFocusController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Preferência para novo tema (opcional)',
                helperText:
                    'Ex.: cidadania digital, saúde pública, mobilidade urbana.',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _essayThemeController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Tema para correção da redação',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _essayContextController,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Contexto do aluno (opcional)',
                helperText:
                    'Ex.: dificuldades em proposta de intervenção e coesão.',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_essayThemeSourceSelecionado),
                    initialValue: _essayThemeSourceSelecionado,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Origem do tema',
                    ),
                    items: themeSources
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) {
                            setState(() {
                              _essayThemeSourceSelecionado = value ?? 'ia';
                            });
                          },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_essayParserModeSelecionado),
                    initialValue: _essayParserModeSelecionado,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Parser de feedback IA',
                    ),
                    items: parserModes
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) {
                            setState(() {
                              _essayParserModeSelecionado = value ?? 'livre';
                            });
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : _copyEssayThemePrompt,
                  child: const Text('Copiar prompt: gerar tema'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _copyEssayCorrectionPrompt,
                  child: const Text('Copiar prompt: corrigir redação'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _essayFeedbackController,
              maxLines: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Retorno da IA (colar aqui para salvar sessão)',
                helperText:
                    'No modo validado, o parser exige C1..C5 no feedback.',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _busy ? null : _analyzeAndSaveEssaySession,
                  child: const Text('Analisar + salvar sessão'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_essayPromptPreview.isEmpty)
              const Text(
                'Ainda sem prompt gerado nesta sessão. Clique em um botão para copiar.',
              )
            else
              SelectableText(_essayPromptPreview),
            const SizedBox(height: 8),
            Text('Sessões de redação salvas: $_essaySessionCount'),
            const SizedBox(height: 8),
            if (_recentEssaySessions.isEmpty)
              const Text('Sem sessões de redação salvas ainda.')
            else
              ..._recentEssaySessions.map(
                (session) => Text(
                  '#${session.id} | ${session.themeTitle} | ${session.parserMode} '
                  '| Final ${_formatScore(session.finalScore)}'
                  '${session.legibilityWarning ? ' | alerta legibilidade' : ''}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ENEM Offline Client (MVP)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
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
                    Text(
                      'Vínculos módulo x questão: $_moduleQuestionMatchCount',
                    ),
                    Text('Sessões de redação: $_essaySessionCount'),
                    Text('Tentativas registradas: $_attemptCount'),
                    Text('Acurácia global: ${_percent(_globalAccuracy)}%'),
                    Text('Banco local: $_databasePath'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _manifestController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'URL do manifest.json',
                helperText:
                    'Ex.: release no GitHub Pages, S3 ou servidor próprio.',
              ),
            ),
            const SizedBox(height: 16),
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
                  child: const Text('Atualizar por manifest'),
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
            const SizedBox(height: 16),
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            _buildWeakSkillsCard(),
            const SizedBox(height: 12),
            _buildModuleSuggestionsCard(),
            const SizedBox(height: 12),
            _buildIntercorrelationFiltersCard(),
            const SizedBox(height: 12),
            _buildEssayPromptBuilderCard(),
            const SizedBox(height: 12),
            SelectableText(_status),
          ],
        ),
      ),
    );
  }
}
