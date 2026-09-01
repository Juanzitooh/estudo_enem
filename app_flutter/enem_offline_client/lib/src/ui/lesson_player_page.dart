import 'package:flutter/material.dart';

import '../data/local_database.dart';
import '../lessons/lesson_asset_repository.dart';
import '../lessons/lesson_player_models.dart';

class LessonPlayerPage extends StatefulWidget {
  const LessonPlayerPage({
    super.key,
    required this.assetPath,
  });

  final String assetPath;

  @override
  State<LessonPlayerPage> createState() => _LessonPlayerPageState();
}

class _LessonPlayerPageState extends State<LessonPlayerPage> {
  final LessonAssetRepository _repository = const LessonAssetRepository();
  final LocalDatabase _localDatabase = LocalDatabase();
  final Map<String, String> _answersByQuestion = <String, String>{};
  bool _submitted = false;
  int _outdatedAttemptCount = 0;
  List<LessonVersionAttemptSummary> _attemptSummaries = const [];
  late Future<LessonPlayerData> _lessonFuture;

  @override
  void initState() {
    super.initState();
    _lessonFuture = _loadLessonAndRestoreProgress();
  }

  Future<LessonPlayerData> _loadLessonAndRestoreProgress() async {
    final lesson = await _repository.loadLesson(widget.assetPath);
    try {
      final db = await _localDatabase.open();
      await _localDatabase.markLessonAttemptsOutdated(
        db,
        lessonId: lesson.id,
        keepLessonVersion: lesson.version,
      );
      _outdatedAttemptCount = await _localDatabase.countOutdatedLessonAttempts(
        db,
        lessonId: lesson.id,
      );
      _attemptSummaries = await _localDatabase.loadLessonAttemptSummaries(
        db,
        lessonId: lesson.id,
      );
      final progress = await _localDatabase.loadLessonProgress(
        db,
        lessonId: lesson.id,
        lessonVersion: lesson.version,
      );
      if (progress != null) {
        _answersByQuestion
          ..clear()
          ..addAll(progress.answers);
        _submitted = progress.submitted;
      }
    } catch (_) {
      // fallback silencioso para não quebrar a abertura da aula
    }
    return lesson;
  }

  int _computeScore(LessonPlayerData lesson) {
    var score = 0;
    for (final question in lesson.questions) {
      final selected = _answersByQuestion[question.id] ?? '';
      if (selected == question.answer) {
        score += 1;
      }
    }
    return score;
  }

  Future<void> _onSelectAlternative(
    String questionId,
    String optionId,
    LessonPlayerData lesson,
  ) async {
    if (_submitted) {
      return;
    }
    setState(() {
      _answersByQuestion[questionId] = optionId;
    });
    await _persistLessonProgress(lesson);
  }

  Future<void> _onSubmit(LessonPlayerData lesson) async {
    final total = lesson.questions.length;
    final answered = _answersByQuestion.length;
    if (answered < total) {
      final missing = total - answered;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Marque todas as questões antes de corrigir. Faltam $missing.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _submitted = true;
    });
    await _persistLessonProgress(lesson);
    await _persistLessonQuestionAttempts(lesson);
  }

  Future<void> _onReset(LessonPlayerData lesson) async {
    setState(() {
      _answersByQuestion.clear();
      _submitted = false;
    });
    await _clearLessonProgress(lesson);
  }

  Future<void> _persistLessonProgress(LessonPlayerData lesson) async {
    try {
      final db = await _localDatabase.open();
      await _localDatabase.upsertLessonProgress(
        db,
        lessonId: lesson.id,
        lessonVersion: lesson.version,
        answers: _answersByQuestion,
        submitted: _submitted,
        score: _computeScore(lesson),
        totalQuestions: lesson.questions.length,
      );
    } catch (_) {
      // sem bloqueio de UI em caso de falha local de persistência
    }
  }

  Future<void> _clearLessonProgress(LessonPlayerData lesson) async {
    try {
      final db = await _localDatabase.open();
      await _localDatabase.deleteLessonProgress(
        db,
        lessonId: lesson.id,
        lessonVersion: lesson.version,
      );
    } catch (_) {
      // sem bloqueio de UI em caso de falha local de persistência
    }
  }

  Future<void> _persistLessonQuestionAttempts(LessonPlayerData lesson) async {
    final attempts = <LessonQuestionAttemptInput>[];
    for (final question in lesson.questions) {
      final selected =
          (_answersByQuestion[question.id] ?? '').trim().toUpperCase();
      if (selected.isEmpty) {
        continue;
      }
      attempts.add(
        LessonQuestionAttemptInput(
          lessonQuestionId: question.id,
          selectedOption: selected,
          isCorrect: selected == question.answer,
          sourceQuestionId: question.sourceQuestionId,
        ),
      );
    }
    if (attempts.isEmpty) {
      return;
    }

    try {
      final db = await _localDatabase.open();
      await _localDatabase.upsertLessonQuestionAttempts(
        db,
        lessonId: lesson.id,
        lessonVersion: lesson.version,
        attempts: attempts,
      );
      await _refreshAttemptHistory(lesson);
    } catch (_) {
      // sem bloqueio de UI em caso de falha local de persistência
    }
  }

  Future<void> _refreshAttemptHistory(LessonPlayerData lesson) async {
    try {
      final db = await _localDatabase.open();
      final outdatedCount = await _localDatabase.countOutdatedLessonAttempts(
        db,
        lessonId: lesson.id,
      );
      final summaries = await _localDatabase.loadLessonAttemptSummaries(
        db,
        lessonId: lesson.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _outdatedAttemptCount = outdatedCount;
        _attemptSummaries = summaries;
      });
    } catch (_) {
      // sem bloqueio de UI em caso de falha local de persistência
    }
  }

  Widget _buildHeader(LessonPlayerData lesson) {
    final competencies = lesson.competencies.join(', ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lesson.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('${lesson.area} | ${lesson.materia}'),
            Text('Volume ${lesson.volume} | Módulo ${lesson.modulo}'),
            if (competencies.isNotEmpty) Text('Competências: $competencies'),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleListCard({
    required String title,
    required List<String> items,
  }) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $item'),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderedListCard({
    required String title,
    required List<String> items,
  }) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...items.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('${entry.key + 1}. ${entry.value}'),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentContextCard(LessonCurrentContextData? contextData) {
    if (contextData == null) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contexto brasileiro e atualidades (12 meses)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (contextData.window.isNotEmpty)
              Text('Janela: ${contextData.window}'),
            const SizedBox(height: 8),
            ...contextData.events.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${event.date} - ${event.title}\n${event.description}',
                ),
              ),
            ),
            if (contextData.connection.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Conexão com o módulo: ${contextData.connection}'),
            ],
            if (contextData.brazilCut.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Recorte brasileiro/regional: ${contextData.brazilCut}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExamplesCard(List<LessonPracticalExampleData> examples) {
    if (examples.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Exemplos práticos contextualizados',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...examples.map(
              (example) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${example.title}${example.kind.isEmpty ? '' : ' (${example.kind})'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (example.scenario.isNotEmpty)
                      Text('Cenário: ${example.scenario}'),
                    if (example.application.isNotEmpty)
                      Text('Aplicação: ${example.application}'),
                    if (example.conclusion.isNotEmpty)
                      Text('Conclusão: ${example.conclusion}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaseStudyCard(LessonCaseStudyData? caseStudy) {
    if (caseStudy == null) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Problema real aplicado',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (caseStudy.situation.isNotEmpty)
              Text('Situação: ${caseStudy.situation}'),
            if (caseStudy.reflectionQuestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...caseStudy.reflectionQuestions.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${entry.key + 1}. ${entry.value}'),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeepeningCard(
    LessonDeepeningData? deepening, {
    required bool unlocked,
  }) {
    if (deepening == null || !unlocked) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aprofundamento',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (deepening.goal.isNotEmpty) Text('Objetivo: ${deepening.goal}'),
            if (deepening.videoKeywords.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Palavras-chave para vídeo:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: deepening.videoKeywords
                    .map((keyword) => Chip(label: Text(keyword)))
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(
    LessonPlayerData lesson,
    LessonQuestionData question,
    int index,
    bool showResult,
  ) {
    final selected = _answersByQuestion[question.id] ?? '';
    final isCorrect = selected == question.answer;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Q${index + 1} [${question.level}]',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(question.statement),
            const SizedBox(height: 10),
            RadioGroup<String>(
              groupValue: selected,
              onChanged: (next) async {
                if (_submitted || next == null) {
                  return;
                }
                await _onSelectAlternative(question.id, next, lesson);
              },
              child: Column(
                children: question.options.map((option) {
                  final value = option.id;
                  return RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${option.id}) ${option.text}'),
                    value: value,
                    enabled: !_submitted,
                    selected: selected == value,
                  );
                }).toList(),
              ),
            ),
            if (showResult)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? Colors.green.withValues(alpha: 0.10)
                      : Colors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isCorrect
                      ? 'Correta. Gabarito: ${question.answer}. ${question.commentary}'
                      : 'Incorreta. Você marcou $selected e o gabarito é ${question.answer}. ${question.commentary}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionHistoryCard(LessonPlayerData lesson) {
    if (_attemptSummaries.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Histórico de versões da aula',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ..._attemptSummaries.map((summary) {
              final isCurrent = summary.lessonVersion == lesson.version;
              final percent = summary.attemptCount <= 0
                  ? 0
                  : (summary.correctCount * 100 / summary.attemptCount).round();
              final outdatedLabel = summary.outdatedCount > 0
                  ? ' | desatualizadas: ${summary.outdatedCount}'
                  : '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${isCurrent ? 'Atual' : 'Versão'} ${summary.lessonVersion} '
                  '| ${summary.correctCount}/${summary.attemptCount} ($percent%)'
                  '$outdatedLabel',
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aula do módulo')),
      body: FutureBuilder<LessonPlayerData>(
        future: _lessonFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Não foi possível carregar a aula. Verifique o asset e tente novamente.',
                ),
              ),
            );
          }

          final lesson = snapshot.data!;
          final total = lesson.questions.length;
          final answered = _answersByQuestion.length;
          final score = _submitted ? _computeScore(lesson) : 0;
          final percent =
              _submitted && total > 0 ? (score * 100 / total).round() : 0;
          final hasAttemptedQuestions = answered > 0 || _submitted;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(lesson),
              if (_outdatedAttemptCount > 0) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Você tem $_outdatedAttemptCount tentativa(s) de versão anterior marcada(s) como desatualizada(s).',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _buildVersionHistoryCard(lesson),
              const SizedBox(height: 12),
              _buildSimpleListCard(
                title: 'Expectativas de aprendizagem',
                items: lesson.learningExpectations,
              ),
              const SizedBox(height: 12),
              _buildCurrentContextCard(lesson.currentContext),
              const SizedBox(height: 12),
              _buildSimpleListCard(
                title: 'Conceitos centrais',
                items: lesson.concepts,
              ),
              const SizedBox(height: 12),
              _buildOrderedListCard(
                title: '4.2 Passo a passo de resolução',
                items: lesson.resolutionSteps,
              ),
              const SizedBox(height: 12),
              _buildSimpleListCard(
                title: '4.3 Como isso aparece no ENEM',
                items: lesson.enemPatterns,
              ),
              const SizedBox(height: 12),
              _buildExamplesCard(lesson.examples),
              const SizedBox(height: 12),
              _buildCaseStudyCard(lesson.caseStudy),
              const SizedBox(height: 12),
              _buildSimpleListCard(
                title: 'Checagem rápida',
                items: lesson.quickCheck,
              ),
              if (lesson.summary.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Resumo: ${lesson.summary}'),
                  ),
                ),
              ],
              if (lesson.deepening != null && hasAttemptedQuestions) ...[
                const SizedBox(height: 12),
                _buildDeepeningCard(
                  lesson.deepening,
                  unlocked: hasAttemptedQuestions,
                ),
              ],
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Questões da aula',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _submitted
                            ? 'Resultado: $score/$total ($percent%)'
                            : 'Respondidas: $answered/$total',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton(
                            onPressed: _submitted
                                ? null
                                : () async => _onSubmit(lesson),
                            child: const Text('Finalizar e corrigir'),
                          ),
                          OutlinedButton(
                            onPressed: answered == 0 && !_submitted
                                ? null
                                : () async => _onReset(lesson),
                            child: const Text('Refazer'),
                          ),
                        ],
                      ),
                      if (!_submitted)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            'Gabarito oculto até finalizar.',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                      if (!hasAttemptedQuestions)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Aprofundamento será liberado após sua primeira tentativa.',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...lesson.questions.asMap().entries.map(
                    (entry) => _buildQuestionCard(
                      lesson,
                      entry.value,
                      entry.key,
                      _submitted,
                    ),
                  ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}
