import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../data/local_database.dart';
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

  bool _busy = false;
  String _status = 'Pronto.';
  String _contentVersion = '0';
  int _questionCount = 0;
  int _bookModuleCount = 0;
  int _attemptCount = 0;
  double _globalAccuracy = 0;
  String _databasePath = '-';
  List<WeakSkillStat> _weakSkills = const [];
  List<ModuleSuggestion> _moduleSuggestions = const [];

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  @override
  void dispose() {
    _manifestController.dispose();
    super.dispose();
  }

  String _percent(double value) {
    return (value * 100).toStringAsFixed(1);
  }

  Future<void> _refreshStats() async {
    final db = await _localDatabase.open();
    final questionCount = await _localDatabase.countQuestions(db);
    final bookModuleCount = await _localDatabase.countBookModules(db);
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
    final version = await _localDatabase.getContentVersion(db);

    if (!mounted) {
      return;
    }
    setState(() {
      _questionCount = questionCount;
      _bookModuleCount = bookModuleCount;
      _attemptCount = attemptCount;
      _globalAccuracy = accuracy;
      _databasePath = databasePath;
      _weakSkills = weakSkills;
      _moduleSuggestions = moduleSuggestions;
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
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
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
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
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
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
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
            SelectableText(_status),
          ],
        ),
      ),
    );
  }
}
