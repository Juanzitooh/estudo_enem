part of 'home_page.dart';

extension _HomePageAdvancedCardsExt on _HomePageState {
  Widget _buildTreinoCard() {
    final question = _currentTreinoQuestion;
    final answered = _treinoAcertos + _treinoErros;
    final accuracy = answered <= 0 ? 0 : (_treinoAcertos / answered) * 100;
    const alternativas = ['A', 'B', 'C', 'D', 'E'];

    String previewText(String value) {
      final normalized = value.trim().replaceAll('\n', ' ');
      if (normalized.length <= 600) {
        return normalized;
      }
      return '${normalized.substring(0, 600)}...';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Modo treino por habilidade (correção imediata)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _treinoQuantidadeController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Qtde treino',
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: CheckboxListTile(
                    value: _treinoEmbaralhar,
                    onChanged: _busy
                        ? null
                        : (value) {
                            _updateState(() {
                              _treinoEmbaralhar = value ?? true;
                            });
                          },
                    title: const Text('Embaralhar'),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                ElevatedButton(
                  onPressed: _busy ? null : _iniciarTreino,
                  child: const Text('Iniciar treino'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _encerrarTreino,
                  child: const Text('Encerrar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Sessão: ${_treinoQuestions.length} questão(ões)'),
            Text(
                'Respondidas: $answered | Acurácia: ${accuracy.toStringAsFixed(1)}%'),
            if (question == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                    'Inicie uma sessão para começar a responder questões.'),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Questão ${_treinoCurrentIndex + 1}/${_treinoQuestions.length} '
                    '| ${question.year}/${question.day}/${question.number}'
                    '${question.variation > 1 ? ' (v${question.variation})' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${question.area} | ${question.discipline}'
                    '${question.skill.isEmpty ? '' : ' | ${question.skill}'}',
                  ),
                  if (question.difficulty.trim().isNotEmpty)
                    Text('Dificuldade: ${question.difficulty}'),
                  const SizedBox(height: 6),
                  Text(previewText(question.statement)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: alternativas
                        .map(
                          (option) => OutlinedButton(
                            onPressed: _busy || _treinoRespondida
                                ? null
                                : () => _responderTreino(option),
                            child: Text(option),
                          ),
                        )
                        .toList(),
                  ),
                  if (_treinoRespostaSelecionada.isNotEmpty)
                    Text('Resposta marcada: $_treinoRespostaSelecionada'),
                  if (_treinoFeedback.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_treinoFeedback),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed:
                            _busy || !_treinoRespondida ? null : _proximaTreino,
                        child: const Text('Próxima questão'),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticoCard() {
    final easyCount = _diagnosticoQuestions
        .where((item) => item.difficulty.toLowerCase() == 'facil')
        .length;
    final mediumCount = _diagnosticoQuestions
        .where((item) => item.difficulty.toLowerCase() == 'media')
        .length;
    final hardCount = _diagnosticoQuestions
        .where((item) => item.difficulty.toLowerCase() == 'dificil')
        .length;
    final current = _currentDiagnosticoQuestion;
    final answered = _diagnosticoAcertos + _diagnosticoErros;
    final accuracy = answered <= 0 ? 0 : (_diagnosticoAcertos / answered) * 100;
    final totalSession = _diagnosticoSessionQuestions.length;
    final subjectScores = _diagnosticoSubjectScores();
    final topDeficits = _diagnosticoTopSkillDeficits();
    const alternativas = ['A', 'B', 'C', 'D', 'E'];

    String previewText(String value) {
      final normalized = value.trim().replaceAll('\n', ' ');
      if (normalized.length <= 520) {
        return normalized;
      }
      return '${normalized.substring(0, 520)}...';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Diagnóstico por dificuldade (3/3/3)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _diagnosticoPorNivelController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Qtd por nível',
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _busy ? null : _montarDiagnostico333,
                  child: const Text('Montar diagnóstico'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _iniciarTreinoDiagnostico,
                  child: const Text('Iniciar diagnóstico'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _encerrarDiagnostico,
                  child: const Text('Encerrar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Resultado atual | fácil: $easyCount | média: $mediumCount | difícil: $hardCount | total: ${_diagnosticoQuestions.length}',
            ),
            if (_diagnosticoSessionQuestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Sessão: ${current == null ? totalSession : _diagnosticoCurrentIndex + 1}/$totalSession '
                '| Respondidas: $answered | Acurácia: ${accuracy.toStringAsFixed(1)}%',
              ),
              if (current != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Q ${current.year}/${current.day}/${current.number}'
                  '${current.variation > 1 ? ' (v${current.variation})' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${current.materia.isEmpty ? current.discipline : current.materia}'
                  '${current.skill.isEmpty ? '' : ' | ${current.skill}'}'
                  '${current.difficulty.isEmpty ? '' : ' | ${current.difficulty}'}',
                ),
                const SizedBox(height: 6),
                Text(previewText(current.statement)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: alternativas
                      .map(
                        (option) => OutlinedButton(
                          onPressed: _busy || _diagnosticoRespondida
                              ? null
                              : () => _responderDiagnostico(option),
                          child: Text(option),
                        ),
                      )
                      .toList(),
                ),
                if (_diagnosticoRespostaSelecionada.isNotEmpty)
                  Text('Resposta marcada: $_diagnosticoRespostaSelecionada'),
                if (_diagnosticoFeedback.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_diagnosticoFeedback),
                  ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _busy || !_diagnosticoRespondida
                      ? null
                      : _proximaDiagnostico,
                  child: const Text('Próxima questão'),
                ),
              ],
            ] else if (_diagnosticoQuestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._diagnosticoQuestions.take(12).map(
                    (item) => Text(
                      'Q ${item.year}/${item.day}/${item.number} '
                      '| ${item.difficulty.isEmpty ? '-' : item.difficulty} '
                      '| ${item.skill.isEmpty ? '-' : item.skill}',
                    ),
                  ),
            ],
            if (_diagnosticoAnswerEntries.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Resumo do diagnóstico',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Score geral: $_diagnosticoAcertos/$answered '
                '(${accuracy.toStringAsFixed(1)}%)',
              ),
              Text(_diagnosticoErroDominante()),
              const SizedBox(height: 6),
              const Text(
                'Score por matéria',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              if (subjectScores.isEmpty)
                const Text('- Sem matéria identificada.')
              else
                ...subjectScores.map(
                  (item) => Text(
                    '- ${item.subject}: ${item.correct}/${item.total} '
                    '(${(item.accuracy * 100).toStringAsFixed(1)}%)',
                  ),
                ),
              const SizedBox(height: 6),
              const Text(
                'Top 5 habilidades em déficit',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              if (topDeficits.isEmpty)
                const Text('- Sem habilidade mapeada nas questões respondidas.')
              else
                ...topDeficits.map(
                  (item) => Text(
                    '- ${item.skill}: déficit ${(item.deficit * 100).toStringAsFixed(1)}% '
                    '| ${item.correct}/${item.total}',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStudyBlockSuggestionsCard() {
    final priorityMap = <String, SkillPriorityItem>{};
    for (final item in _skillPriorities) {
      priorityMap[item.skill] = item;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Habilidades em foco',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_studyBlockSuggestions.isEmpty)
              const Text(
                'Ainda sem blocos sugeridos. Resolva algumas questões para gerar priorização.',
              )
            else
              ..._studyBlockSuggestions.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Domínio: ${_percent(item.accuracy)}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${item.skill} | ${item.correct}/${item.attempts} acertos',
                        ),
                        Text(
                          'Causa provável: ${_inferErrorReasonForSuggestion(item, priorityMap[item.skill])}',
                        ),
                        Text(
                          'Bloco sugerido: ${item.recommendedQuestions} questões '
                          '| ${item.recommendedMinutes} min',
                        ),
                        Text(
                          'Banco disponível: ${item.questionPool} questão(ões) para a skill.',
                        ),
                        if (item.materia.trim().isNotEmpty || item.modulo > 0)
                          Text(
                            'Revisão recomendada: '
                            '${item.materia.trim().isEmpty ? '-' : item.materia}'
                            '${item.modulo > 0 ? ' | Módulo ${item.modulo}' : ''}'
                            '${item.page.trim().isEmpty ? '' : ' | pág. ${item.page}'}'
                            '${item.title.trim().isEmpty ? '' : ' | ${item.title}'}',
                          ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _iniciarBlocoSugestao(item),
                              child: const Text('Treinar agora'),
                            ),
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _revisarTeoriaSuggestion(item),
                              child: const Text('Revisar teoria'),
                            ),
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _copyStudyPromptForSuggestion(
                                        item,
                                        mode: 'aula',
                                      ),
                              child: const Text('Prompt: aula'),
                            ),
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _copyStudyPromptForSuggestion(
                                        item,
                                        mode: 'videos',
                                      ),
                              child: const Text('Prompt: vídeos'),
                            ),
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _copyStudyPromptForSuggestion(
                                        item,
                                        mode: 'treino',
                                      ),
                              child: const Text('Prompt: treino'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (_studyPromptPreview.trim().isNotEmpty)
              SelectableText(_studyPromptPreview),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAttemptsCard() {
    String compactDate(String raw) {
      if (raw.trim().isEmpty) {
        return '-';
      }
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) {
        return raw;
      }
      final local = parsed.toLocal();
      final dd = local.day.toString().padLeft(2, '0');
      final mm = local.month.toString().padLeft(2, '0');
      final hh = local.hour.toString().padLeft(2, '0');
      final min = local.minute.toString().padLeft(2, '0');
      return '$dd/$mm $hh:$min';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Histórico recente de tentativas',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_recentAttempts.isEmpty)
              const Text('Sem tentativas registradas ainda.')
            else
              ..._recentAttempts.map(
                (attempt) => Text(
                  '${attempt.isCorrect ? 'Acerto' : 'Erro'} | '
                  'Q ${attempt.year}/${attempt.day}/${attempt.number}'
                  '${attempt.variation > 1 ? ' (v${attempt.variation})' : ''} | '
                  '${attempt.skill.isEmpty ? '-' : attempt.skill} | '
                  '${attempt.competency.isEmpty ? '-' : attempt.competency} | '
                  '${compactDate(attempt.answeredAt)}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionFiltersCard() {
    final years = <int?>[null, ..._questionFilterOptions.years];
    final days = <int?>[null, ..._questionFilterOptions.days];
    final areas = <String>['', ..._questionFilterOptions.areas];
    final disciplines = <String>['', ..._questionFilterOptions.disciplines];
    final materias = <String>['', ..._questionFilterOptions.materias];
    final competencies = <String>['', ..._questionFilterOptions.competencies];
    final skills = <String>['', ..._questionFilterOptions.skills];
    final difficulties = <String>['', ..._questionFilterOptions.difficulties];
    const hasImageOptions = ['', 'sim', 'nao'];

    String previewText(String value) {
      final normalized = value.trim().replaceAll('\n', ' ');
      if (normalized.length <= 240) {
        return normalized;
      }
      return '${normalized.substring(0, 240)}...';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtro de questões (cards)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<int?>(
                    key: ValueKey('question_year_$_questionYearSelecionado'),
                    initialValue: _questionYearSelecionado,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Ano',
                    ),
                    items: years
                        .map(
                          (value) => DropdownMenuItem<int?>(
                            value: value,
                            child: Text(value == null ? 'Todos' : '$value'),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) {
                            _updateState(() {
                              _questionYearSelecionado = value;
                            });
                          },
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<int?>(
                    key: ValueKey('question_day_$_questionDaySelecionado'),
                    initialValue: _questionDaySelecionado,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Dia',
                    ),
                    items: days
                        .map(
                          (value) => DropdownMenuItem<int?>(
                            value: value,
                            child: Text(value == null ? 'Todos' : '$value'),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) {
                            _updateState(() {
                              _questionDaySelecionado = value;
                            });
                          },
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('question_area_$_questionAreaSelecionada'),
                    initialValue: _questionAreaSelecionada,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Área',
                    ),
                    items: areas
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value.isEmpty ? 'Todas' : value),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) {
                            _updateState(() {
                              _questionAreaSelecionada = value ?? '';
                            });
                          },
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(
                      'question_discipline_$_questionDisciplineSelecionada',
                    ),
                    initialValue: _questionDisciplineSelecionada,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Disciplina',
                    ),
                    items: disciplines
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value.isEmpty ? 'Todas' : value),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) {
                            _updateState(() {
                              _questionDisciplineSelecionada = value ?? '';
                            });
                          },
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(
                        'question_materia_$_questionMateriaSelecionada'),
                    initialValue: _questionMateriaSelecionada,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Matéria',
                    ),
                    items: materias
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value.isEmpty ? 'Todas' : value),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) {
                            _updateState(() {
                              _questionMateriaSelecionada = value ?? '';
                            });
                          },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(
                      'question_competency_$_questionCompetencySelecionada',
                    ),
                    initialValue: _questionCompetencySelecionada,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Competência',
                    ),
                    items: competencies
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value.isEmpty ? 'Todas' : value),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) {
                            _updateState(() {
                              _questionCompetencySelecionada = value ?? '';
                            });
                          },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('question_skill_$_questionSkillSelecionada'),
                    initialValue: _questionSkillSelecionada,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Habilidade',
                    ),
                    items: skills
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value.isEmpty ? 'Todas' : value),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) {
                            _updateState(() {
                              _questionSkillSelecionada = value ?? '';
                            });
                          },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(
                      'question_difficulty_$_questionDifficultySelecionada',
                    ),
                    initialValue: _questionDifficultySelecionada,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Dificuldade',
                    ),
                    items: difficulties
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value.isEmpty ? 'Todas' : value),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) {
                            _updateState(() {
                              _questionDifficultySelecionada = value ?? '';
                            });
                          },
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(
                      'question_has_image_$_questionHasImageSelecionado',
                    ),
                    initialValue: _questionHasImageSelecionado,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Tem imagem',
                    ),
                    items: hasImageOptions
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value.isEmpty
                                  ? 'Todos'
                                  : value == 'sim'
                                      ? 'Com imagem'
                                      : 'Sem imagem',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) {
                            _updateState(() {
                              _questionHasImageSelecionado = value ?? '';
                            });
                          },
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _questionLimitController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Limite',
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
                OutlinedButton(
                  onPressed: _busy ? null : _applyQuestionFilters,
                  child: const Text('Aplicar filtro'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _clearQuestionFilters,
                  child: const Text('Limpar filtro'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Resultados: ${_filteredQuestions.length}'),
            const SizedBox(height: 4),
            if (_filteredQuestions.isEmpty)
              const Text('Sem questões para os filtros atuais.')
            else
              ..._filteredQuestions.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Q ${item.year}/${item.day}/${item.number} '
                          '${item.variation > 1 ? '(v${item.variation})' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.area} | ${item.discipline}'
                          '${item.materia.isEmpty ? '' : ' | ${item.materia}'}',
                        ),
                        Text(
                          'Competência: ${item.competency.isEmpty ? '-' : item.competency} '
                          '| Habilidade: ${item.skill.isEmpty ? '-' : item.skill} '
                          '| Dificuldade: ${item.difficulty.isEmpty ? '-' : item.difficulty} '
                          '| Imagem: ${item.hasImage ? 'sim' : 'nao'}',
                        ),
                        const SizedBox(height: 4),
                        Text(previewText(item.statement)),
                        if (item.answer.trim().isNotEmpty)
                          Text('Gabarito: ${item.answer.trim()}'),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimuladoCard() {
    String previewText(String value) {
      final normalized = value.trim().replaceAll('\n', ' ');
      if (normalized.length <= 180) {
        return normalized;
      }
      return '${normalized.substring(0, 180)}...';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Simulado rápido (com filtros atuais)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _simuladoQuantidadeController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Qtde questões',
                    ),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: TextField(
                    controller: _simuladoTempoPorQuestaoController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Min/questão',
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: CheckboxListTile(
                    value: _simuladoEmbaralhar,
                    onChanged: _busy
                        ? null
                        : (value) {
                            _updateState(() {
                              _simuladoEmbaralhar = value ?? true;
                            });
                          },
                    title: const Text('Embaralhar'),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                ElevatedButton(
                  onPressed: _busy ? null : _montarSimulado,
                  child: const Text('Montar simulado'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _limparSimulado,
                  child: const Text('Limpar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Questões no simulado: ${_simuladoQuestions.length}'),
            Text('Tempo sugerido: $_simuladoTempoTotalMinutos minutos'),
            Text(
              'Distribuição por área: '
              '${_buildSimuladoDistribuicaoResumo(_simuladoQuestions)}',
            ),
            const SizedBox(height: 8),
            if (_simuladoQuestions.isEmpty)
              const Text('Nenhum simulado montado ainda.')
            else
              ..._simuladoQuestions.map(
                (item) => Text(
                  'Q ${item.year}/${item.day}/${item.number} '
                  '${item.area} | ${item.skill.isEmpty ? '-' : item.skill}'
                  '${item.difficulty.isEmpty ? '' : ' | ${item.difficulty}'}'
                  ' | ${previewText(item.statement)}',
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
                            _updateState(() {
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
            TextField(
              controller: _essayStudentTextController,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Texto da redação do aluno (opcional)',
                helperText:
                    'Se preencher, o prompt de reescrita preserva sua estrutura original.',
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
                            _updateState(() {
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
                            _updateState(() {
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
                OutlinedButton(
                  onPressed: _busy ? null : _copyEssayRewritePrompt,
                  child: const Text('Copiar prompt: reescrita'),
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
            Text(
              'Com nota: ${_essayScoreSummary.scoredSessionCount} | '
              'Melhor: ${_formatScore(_essayScoreSummary.bestScore)} | '
              'Média: ${_essayScoreSummary.averageScore.toStringAsFixed(1)} | '
              'Última: ${_formatScore(_essayScoreSummary.latestScore)} '
              '(${_essayRankLabel(_essayScoreSummary.latestScore)})',
            ),
            const SizedBox(height: 8),
            if (_recentEssaySessions.isEmpty)
              const Text('Sem sessões de redação salvas ainda.')
            else
              ..._recentEssaySessions.map(
                (session) => Text(
                  '#${session.id} | ${session.themeTitle} | ${session.parserMode} '
                  '| Final ${_formatScore(session.finalScore)} '
                  '(${_essayRankLabel(session.finalScore)})'
                  '${session.legibilityWarning ? ' | alerta legibilidade' : ''}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
