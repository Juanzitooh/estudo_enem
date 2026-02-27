import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../config/app_config.dart';
import '../data/local_database.dart';
import '../essay/essay_feedback_parser.dart';
import '../essay/essay_prompt_builder.dart';
import '../study/offline_planner.dart';
import '../study/study_prompt_builder.dart';
import '../update/content_updater.dart';

class _AdaptiveSlot {
  const _AdaptiveSlot({
    required this.skill,
    required this.band,
    required this.questionCount,
    required this.priorityScore,
  });

  final String skill;
  final String band;
  final int questionCount;
  final double priorityScore;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onAppearanceChanged});

  final void Function(String themeMode, double fontScale)? onAppearanceChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final LocalDatabase _localDatabase = LocalDatabase();
  final TextEditingController _manifestController = TextEditingController(
    text: AppConfig.defaultManifestUrl,
  );
  final TextEditingController _questionLimitController = TextEditingController(
    text: '20',
  );
  final TextEditingController _simuladoQuantidadeController =
      TextEditingController(text: '20');
  final TextEditingController _simuladoTempoPorQuestaoController =
      TextEditingController(text: '3');
  final TextEditingController _treinoQuantidadeController =
      TextEditingController(text: '10');
  final TextEditingController _diagnosticoPorNivelController =
      TextEditingController(text: '3');
  final TextEditingController _matchMateriaController = TextEditingController();
  final TextEditingController _matchAssuntoController = TextEditingController();
  final TextEditingController _matchScoreController = TextEditingController(
    text: '0.50',
  );
  final TextEditingController _essayThemeController = TextEditingController();
  final TextEditingController _essayFocusController = TextEditingController();
  final TextEditingController _essayContextController = TextEditingController();
  final TextEditingController _essayStudentTextController =
      TextEditingController();
  final TextEditingController _essayFeedbackController =
      TextEditingController();
  final TextEditingController _profileNameController = TextEditingController(
    text: 'Perfil principal',
  );
  final TextEditingController _profileTargetYearController =
      TextEditingController();
  final TextEditingController _profileStudyDaysController =
      TextEditingController(text: 'seg,ter,qua,qui,sex');
  final TextEditingController _profileHoursPerDayController =
      TextEditingController(text: '2');
  final TextEditingController _profileFocusAreaController =
      TextEditingController();
  final TextEditingController _profileExamDateController =
      TextEditingController();
  final TextEditingController _profilePlannerContextController =
      TextEditingController();
  final TextEditingController _profileExportPathController =
      TextEditingController();
  final TextEditingController _profileImportPathController =
      TextEditingController();

  bool _busy = false;
  String _status = 'Pronto.';
  String _essayPromptPreview = '';
  String _studyPromptPreview = '';
  String _contentVersion = '0';
  int _questionCount = 0;
  int _bookModuleCount = 0;
  int _moduleQuestionMatchCount = 0;
  int _essaySessionCount = 0;
  int _attemptCount = 0;
  int _studentProfileCount = 0;
  double _globalAccuracy = 0;
  String _databasePath = '-';
  QuestionFilterOptions _questionFilterOptions = const QuestionFilterOptions();
  List<QuestionCardItem> _filteredQuestions = const [];
  List<QuestionCardItem> _treinoQuestions = const [];
  int _treinoCurrentIndex = 0;
  int _treinoAcertos = 0;
  int _treinoErros = 0;
  bool _treinoEmbaralhar = true;
  bool _treinoRespondida = false;
  String _treinoRespostaSelecionada = '';
  String _treinoFeedback = '';
  List<QuestionCardItem> _diagnosticoQuestions = const [];
  List<QuestionCardItem> _simuladoQuestions = const [];
  int _simuladoTempoTotalMinutos = 0;
  bool _simuladoEmbaralhar = true;
  List<AttemptRecord> _recentAttempts = const [];
  List<StudyBlockSuggestion> _studyBlockSuggestions = const [];
  List<SkillPriorityItem> _skillPriorities = const [];
  List<WeakSkillStat> _weakSkills = const [];
  List<ModuleSuggestion> _moduleSuggestions = const [];
  List<ModuleQuestionMatch> _moduleQuestionMatches = const [];
  List<EssaySessionRecord> _recentEssaySessions = const [];
  List<StudentProfileRecord> _studentProfiles = const [];
  StudentProfileRecord? _activeStudentProfile;
  OfflinePlanForecast _offlinePlanForecast = OfflinePlanForecast.empty;
  EssayScoreSummary _essayScoreSummary = const EssayScoreSummary(
    scoredSessionCount: 0,
    averageScore: 0,
  );
  String _matchTipoSelecionado = '';
  int? _questionYearSelecionado;
  int? _questionDaySelecionado;
  String _questionAreaSelecionada = '';
  String _questionDisciplineSelecionada = '';
  String _questionMateriaSelecionada = '';
  String _questionCompetencySelecionada = '';
  String _questionSkillSelecionada = '';
  String _questionDifficultySelecionada = '';
  String _questionHasImageSelecionado = '';
  String _essayThemeSourceSelecionado = 'ia';
  String _essayParserModeSelecionado = EssayParserMode.livre.value;
  String _selectedStudentProfileId = '';
  String _profileThemeMode = profileThemeModeSystem;
  double _profileFontScale = profileFontScaleDefault;

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  @override
  void dispose() {
    _manifestController.dispose();
    _questionLimitController.dispose();
    _simuladoQuantidadeController.dispose();
    _simuladoTempoPorQuestaoController.dispose();
    _treinoQuantidadeController.dispose();
    _diagnosticoPorNivelController.dispose();
    _matchMateriaController.dispose();
    _matchAssuntoController.dispose();
    _matchScoreController.dispose();
    _essayThemeController.dispose();
    _essayFocusController.dispose();
    _essayContextController.dispose();
    _essayStudentTextController.dispose();
    _essayFeedbackController.dispose();
    _profileNameController.dispose();
    _profileTargetYearController.dispose();
    _profileStudyDaysController.dispose();
    _profileHoursPerDayController.dispose();
    _profileFocusAreaController.dispose();
    _profileExamDateController.dispose();
    _profilePlannerContextController.dispose();
    _profileExportPathController.dispose();
    _profileImportPathController.dispose();
    super.dispose();
  }

  String _percent(double value) {
    return (value * 100).toStringAsFixed(1);
  }

  int _readQuestionLimit() {
    final parsed = int.tryParse(_questionLimitController.text.trim());
    if (parsed == null || parsed <= 0) {
      return 20;
    }
    if (parsed > 200) {
      return 200;
    }
    return parsed;
  }

  bool? _readHasImageFilter() {
    if (_questionHasImageSelecionado == 'sim') {
      return true;
    }
    if (_questionHasImageSelecionado == 'nao') {
      return false;
    }
    return null;
  }

  QuestionFilter _buildQuestionFilter() {
    return QuestionFilter(
      year: _questionYearSelecionado,
      day: _questionDaySelecionado,
      area: _questionAreaSelecionada,
      discipline: _questionDisciplineSelecionada,
      materia: _questionMateriaSelecionada,
      competency: _questionCompetencySelecionada,
      skill: _questionSkillSelecionada,
      difficulty: _questionDifficultySelecionada,
      hasImage: _readHasImageFilter(),
      limit: _readQuestionLimit(),
    );
  }

  int _readSimuladoQuantidade() {
    final parsed = int.tryParse(_simuladoQuantidadeController.text.trim());
    if (parsed == null || parsed <= 0) {
      return 20;
    }
    if (parsed > 90) {
      return 90;
    }
    return parsed;
  }

  int _readSimuladoTempoPorQuestao() {
    final parsed = int.tryParse(_simuladoTempoPorQuestaoController.text.trim());
    if (parsed == null || parsed <= 0) {
      return 3;
    }
    if (parsed > 10) {
      return 10;
    }
    return parsed;
  }

  QuestionFilter _buildSimuladoPoolFilter() {
    return QuestionFilter(
      year: _questionYearSelecionado,
      day: _questionDaySelecionado,
      area: _questionAreaSelecionada,
      discipline: _questionDisciplineSelecionada,
      materia: _questionMateriaSelecionada,
      competency: _questionCompetencySelecionada,
      skill: _questionSkillSelecionada,
      difficulty: _questionDifficultySelecionada,
      hasImage: _readHasImageFilter(),
      limit: 200,
    );
  }

  int _readTreinoQuantidade() {
    final parsed = int.tryParse(_treinoQuantidadeController.text.trim());
    if (parsed == null || parsed <= 0) {
      return 10;
    }
    if (parsed > 50) {
      return 50;
    }
    return parsed;
  }

  int _readDiagnosticoPorNivel() {
    final parsed = int.tryParse(_diagnosticoPorNivelController.text.trim());
    if (parsed == null || parsed <= 0) {
      return 3;
    }
    if (parsed > 10) {
      return 10;
    }
    return parsed;
  }

  QuestionFilter _buildTreinoPoolFilter() {
    return QuestionFilter(
      year: _questionYearSelecionado,
      day: _questionDaySelecionado,
      area: _questionAreaSelecionada,
      discipline: _questionDisciplineSelecionada,
      materia: _questionMateriaSelecionada,
      competency: _questionCompetencySelecionada,
      skill: _questionSkillSelecionada,
      difficulty: _questionDifficultySelecionada,
      hasImage: _readHasImageFilter(),
      limit: 200,
    );
  }

  QuestionFilter _buildDiagnosticoFilter({
    required String difficulty,
    required int limit,
  }) {
    return QuestionFilter(
      year: _questionYearSelecionado,
      day: _questionDaySelecionado,
      area: _questionAreaSelecionada,
      discipline: _questionDisciplineSelecionada,
      materia: _questionMateriaSelecionada,
      competency: _questionCompetencySelecionada,
      skill: _questionSkillSelecionada,
      difficulty: difficulty,
      hasImage: _readHasImageFilter(),
      limit: limit,
    );
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

  int? _readProfileTargetYear() {
    final text = _profileTargetYearController.text.trim();
    if (text.isEmpty) {
      return null;
    }
    final parsed = int.tryParse(text);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  double? _readProfileHoursPerDay() {
    final text = _profileHoursPerDayController.text.trim();
    if (text.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(text.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  void _syncProfileFields(StudentProfileRecord profile) {
    _profileNameController.text = profile.displayName;
    _profileTargetYearController.text =
        profile.targetYear == null ? '' : '${profile.targetYear}';
    _profileStudyDaysController.text = profile.studyDaysCsv;
    _profileHoursPerDayController.text = profile.hoursPerDay == null
        ? ''
        : profile.hoursPerDay!.toStringAsFixed(1);
    _profileFocusAreaController.text = profile.focusArea;
    _profileExamDateController.text = profile.examDate;
    _profilePlannerContextController.text = profile.plannerContext;
    _selectedStudentProfileId = profile.id;
    _profileThemeMode = normalizeProfileThemeMode(profile.themeMode);
    _profileFontScale = normalizeProfileFontScale(profile.fontScale);
    widget.onAppearanceChanged?.call(_profileThemeMode, _profileFontScale);
  }

  String _themeModeLabel(String value) {
    final normalized = normalizeProfileThemeMode(value);
    if (normalized == profileThemeModeLight) {
      return 'Claro';
    }
    if (normalized == profileThemeModeDark) {
      return 'Escuro';
    }
    return 'Sistema';
  }

  Future<String> _defaultProfileExportPath(String profileId) async {
    final dbPath = await _localDatabase.databasePath();
    final dir = path.dirname(dbPath);
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final safeProfileId = profileId.trim().isEmpty ? 'perfil' : profileId;
    return path.join(dir, 'profile_export_${safeProfileId}_$timestamp.zip');
  }

  OfflinePlanForecast _buildLiveForecast(StudentProfileRecord? profile) {
    return OfflinePlannerEngine.build(
      now: DateTime.now(),
      profile: profile,
      priorities: _skillPriorities,
      horizonDays: 7,
    );
  }

  OfflinePlanForecast _readSnapshotOrFallback({
    required StudentProfileRecord? profile,
    required OfflinePlanForecast fallback,
  }) {
    if (profile == null) {
      return fallback;
    }
    final rawSnapshot = profile.plannerSnapshotJson.trim();
    if (rawSnapshot.isEmpty) {
      return fallback;
    }
    try {
      final decoded = jsonDecode(rawSnapshot);
      if (decoded is Map<String, dynamic>) {
        return OfflinePlanForecast.fromMap(decoded);
      }
    } catch (_) {
      return fallback;
    }
    return fallback;
  }

  String _archiveFileText(ArchiveFile file) {
    final rawContent = file.content;
    if (rawContent is List<int>) {
      return utf8.decode(rawContent);
    }
    return rawContent.toString();
  }

  Future<void> _refreshStats() async {
    final db = await _localDatabase.open();
    final ensuredProfile = await _localDatabase.ensureDefaultStudentProfile(db);
    final studentProfiles = await _localDatabase.loadStudentProfiles(db);
    final activeStudentProfile =
        await _localDatabase.loadActiveStudentProfile(db) ?? ensuredProfile;
    final studentProfileCount = studentProfiles.length;
    final questionCount = await _localDatabase.countQuestions(db);
    final bookModuleCount = await _localDatabase.countBookModules(db);
    final moduleQuestionMatchCount =
        await _localDatabase.countModuleQuestionMatches(db);
    final essaySessionCount = await _localDatabase.countEssaySessions(db);
    final attemptCount = await _localDatabase.countAttempts(db);
    final accuracy = await _localDatabase.globalAccuracy(db);
    final databasePath = await _localDatabase.databasePath();
    final weakSkills = await _localDatabase.loadWeakSkills(db, limit: 5);
    final questionFilterOptions =
        await _localDatabase.loadQuestionFilterOptions(db);
    final filteredQuestions = await _localDatabase.searchQuestions(
      db,
      filter: _buildQuestionFilter(),
    );
    final recentAttempts =
        await _localDatabase.loadRecentAttempts(db, limit: 10);
    final studyBlockSuggestions =
        await _localDatabase.suggestStudyBlocks(db, limit: 5);
    final skillPriorities = await _localDatabase.loadSkillPriorities(
      db,
      limit: 10,
    );
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
    final essayScoreSummary = await _localDatabase.loadEssayScoreSummary(db);
    final version = await _localDatabase.getContentVersion(db);
    final livePlanForecast = OfflinePlannerEngine.build(
      now: DateTime.now(),
      profile: activeStudentProfile,
      priorities: skillPriorities,
      horizonDays: 7,
    );
    final planForecast = _readSnapshotOrFallback(
      profile: activeStudentProfile,
      fallback: livePlanForecast,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _studentProfiles = studentProfiles;
      _activeStudentProfile = activeStudentProfile;
      _offlinePlanForecast = planForecast;
      _studentProfileCount = studentProfileCount;
      _selectedStudentProfileId = activeStudentProfile.id;
      _questionCount = questionCount;
      _bookModuleCount = bookModuleCount;
      _moduleQuestionMatchCount = moduleQuestionMatchCount;
      _essaySessionCount = essaySessionCount;
      _attemptCount = attemptCount;
      _globalAccuracy = accuracy;
      _databasePath = databasePath;
      _questionFilterOptions = questionFilterOptions;
      _filteredQuestions = filteredQuestions;
      _recentAttempts = recentAttempts;
      _studyBlockSuggestions = studyBlockSuggestions;
      _skillPriorities = skillPriorities;
      _weakSkills = weakSkills;
      _moduleSuggestions = moduleSuggestions;
      _moduleQuestionMatches = moduleQuestionMatches;
      _recentEssaySessions = recentEssaySessions;
      _essayScoreSummary = essayScoreSummary;
      _contentVersion = version;
    });
    _syncProfileFields(activeStudentProfile);
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

  Future<void> _saveStudentProfile({bool makeActive = true}) async {
    final displayName = _profileNameController.text.trim();
    if (displayName.isEmpty) {
      setState(() {
        _status = 'Informe o nome do perfil antes de salvar.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Salvando perfil local...';
    });

    try {
      final db = await _localDatabase.open();
      final selectedId = _selectedStudentProfileId.trim();
      final targetYear = _readProfileTargetYear();
      final hoursPerDay = _readProfileHoursPerDay();
      final studyDaysCsv = _profileStudyDaysController.text.trim();
      final focusArea = _profileFocusAreaController.text.trim();
      final examDate = _profileExamDateController.text.trim();
      final plannerContext = _profilePlannerContextController.text.trim();
      final snapshotSeedProfile = StudentProfileRecord(
        id: selectedId.isEmpty ? 'draft_profile' : selectedId,
        displayName: displayName,
        targetYear: targetYear,
        studyDaysCsv: studyDaysCsv,
        hoursPerDay: hoursPerDay,
        focusArea: focusArea,
        examDate: examDate,
        plannerContext: plannerContext,
        plannerSnapshotJson: '',
        themeMode: _profileThemeMode,
        fontScale: _profileFontScale,
        isActive: true,
        createdAt: '',
        updatedAt: '',
      );
      final planSnapshot = _buildLiveForecast(snapshotSeedProfile);
      final input = StudentProfileInput(
        id: selectedId,
        displayName: displayName,
        targetYear: targetYear,
        studyDaysCsv: studyDaysCsv,
        hoursPerDay: hoursPerDay,
        focusArea: focusArea,
        examDate: examDate,
        plannerContext: plannerContext,
        plannerSnapshotJson: jsonEncode(planSnapshot.toMap()),
        themeMode: _profileThemeMode,
        fontScale: _profileFontScale,
      );
      await _localDatabase.upsertStudentProfile(
        db,
        input,
        makeActive: makeActive,
      );
      await _refreshStats();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Perfil salvo com sucesso.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Falha ao salvar perfil: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _switchStudentProfile(String? profileId) async {
    final normalizedId = (profileId ?? '').trim();
    if (normalizedId.isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Trocando perfil ativo...';
    });
    try {
      final db = await _localDatabase.open();
      await _localDatabase.setActiveStudentProfile(db, normalizedId);
      await _refreshStats();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Perfil ativo atualizado.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Falha ao trocar perfil: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _exportActiveProfile() async {
    final active = _activeStudentProfile;
    if (active == null) {
      setState(() {
        _status = 'Nenhum perfil ativo para exportar.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Exportando perfil...';
    });

    try {
      final db = await _localDatabase.open();
      final payload = await _localDatabase.exportStudentProfileBundle(
        db,
        profileId: active.id,
      );
      if (payload.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _status = 'Falha ao montar pacote de exportação do perfil.';
        });
        return;
      }

      var exportPath = _profileExportPathController.text.trim();
      if (exportPath.isEmpty) {
        exportPath = await _defaultProfileExportPath(active.id);
      }
      if (!exportPath.toLowerCase().endsWith('.zip')) {
        exportPath = '$exportPath.zip';
      }

      final planningPayload = _offlinePlanForecast.toMap();
      final archive = Archive();
      archive.addFile(
        ArchiveFile.string(
          'profile_export.json',
          const JsonEncoder.withIndent('  ').convert(payload),
        ),
      );
      archive.addFile(
        ArchiveFile.string(
          'planning_profile.json',
          const JsonEncoder.withIndent('  ').convert(planningPayload),
        ),
      );

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _status = 'Falha ao gerar pacote ZIP do perfil.';
        });
        return;
      }

      final exportFile = File(exportPath);
      await exportFile.parent.create(recursive: true);
      await exportFile.writeAsBytes(zipBytes, flush: true);

      if (!mounted) {
        return;
      }
      setState(() {
        _profileExportPathController.text = exportPath;
        _status = 'Perfil exportado em pacote ZIP: $exportPath';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Falha ao exportar perfil: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _importProfileFromFile() async {
    final importPath = _profileImportPathController.text.trim();
    if (importPath.isEmpty) {
      setState(() {
        _status = 'Informe o caminho do arquivo de importação.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Importando perfil...';
    });

    try {
      final sourceFile = File(importPath);
      if (!await sourceFile.exists()) {
        if (!mounted) {
          return;
        }
        setState(() {
          _status = 'Arquivo de importação não encontrado: $importPath';
        });
        return;
      }

      Map<String, dynamic>? profilePayload;
      Map<String, dynamic>? planningPayload;

      if (importPath.toLowerCase().endsWith('.zip')) {
        final zipBytes = await sourceFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(zipBytes, verify: true);
        ArchiveFile? profileFile;
        ArchiveFile? planningFile;
        for (final file in archive.files) {
          final name = file.name.toLowerCase();
          if (name.endsWith('profile_export.json')) {
            profileFile = file;
          }
          if (name.endsWith('planning_profile.json')) {
            planningFile = file;
          }
        }
        if (profileFile == null) {
          for (final file in archive.files) {
            if (file.name.toLowerCase().endsWith('.json')) {
              profileFile = file;
              break;
            }
          }
        }
        if (profileFile == null) {
          if (!mounted) {
            return;
          }
          setState(() {
            _status = 'ZIP inválido: profile_export.json não encontrado.';
          });
          return;
        }

        final profileRaw = _archiveFileText(profileFile);
        final profileDecoded = jsonDecode(profileRaw);
        if (profileDecoded is Map<String, dynamic>) {
          profilePayload = profileDecoded;
        }

        if (planningFile != null) {
          final planningRaw = _archiveFileText(planningFile);
          final planningDecoded = jsonDecode(planningRaw);
          if (planningDecoded is Map<String, dynamic>) {
            planningPayload = planningDecoded;
          }
        }
      } else {
        final rawJson = await sourceFile.readAsString();
        final decoded = jsonDecode(rawJson);
        if (decoded is Map<String, dynamic>) {
          profilePayload = decoded;
        }
      }

      if (profilePayload == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _status = 'Arquivo inválido: formato JSON inesperado.';
        });
        return;
      }

      final db = await _localDatabase.open();
      if (planningPayload != null) {
        final currentProfile =
            (profilePayload['profile'] is Map<String, dynamic>)
                ? Map<String, dynamic>.from(
                    profilePayload['profile'] as Map<String, dynamic>,
                  )
                : <String, dynamic>{};
        currentProfile['planner_snapshot_json'] = jsonEncode(planningPayload);
        profilePayload = {
          ...profilePayload,
          'profile': currentProfile,
        };
      }

      final imported = await _localDatabase.importStudentProfileBundle(
        db,
        payload: profilePayload,
        makeActive: true,
      );
      await _refreshStats();
      if (!mounted) {
        return;
      }
      setState(() {
        if (imported.profile == null) {
          _status = 'Importação concluída sem perfil válido.';
          return;
        }
        final migrationNote = imported.migrated
            ? ' (migração v${imported.sourceSchemaVersion}->v${imported.targetSchemaVersion})'
            : '';
        _status =
            'Perfil importado e ativado: ${imported.profile!.displayName}$migrationNote';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Falha ao importar perfil: $error';
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

  Future<void> _applyQuestionFilters() async {
    setState(() {
      _busy = true;
      _status = 'Aplicando filtros de questões...';
    });

    try {
      await _refreshStats();
      if (!mounted) {
        return;
      }
      setState(() {
        _status =
            'Filtro de questões aplicado. ${_filteredQuestions.length} item(ns) exibido(s).';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Falha ao aplicar filtro de questões: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _clearQuestionFilters() async {
    _questionLimitController.text = '20';
    setState(() {
      _questionYearSelecionado = null;
      _questionDaySelecionado = null;
      _questionAreaSelecionada = '';
      _questionDisciplineSelecionada = '';
      _questionMateriaSelecionada = '';
      _questionCompetencySelecionada = '';
      _questionSkillSelecionada = '';
      _questionDifficultySelecionada = '';
      _questionHasImageSelecionado = '';
    });
    await _applyQuestionFilters();
  }

  QuestionCardItem? get _currentTreinoQuestion {
    if (_treinoQuestions.isEmpty) {
      return null;
    }
    if (_treinoCurrentIndex < 0 ||
        _treinoCurrentIndex >= _treinoQuestions.length) {
      return null;
    }
    return _treinoQuestions[_treinoCurrentIndex];
  }

  void _startTreinoSession(
    List<QuestionCardItem> questions, {
    required String statusMessage,
  }) {
    setState(() {
      _treinoQuestions = questions;
      _treinoCurrentIndex = 0;
      _treinoAcertos = 0;
      _treinoErros = 0;
      _treinoRespondida = false;
      _treinoRespostaSelecionada = '';
      _treinoFeedback = '';
      _status = statusMessage;
    });
  }

  Future<void> _iniciarTreino() async {
    setState(() {
      _busy = true;
      _status = 'Montando sessão de treino...';
    });

    try {
      final db = await _localDatabase.open();
      final pool = await _localDatabase.searchQuestions(
        db,
        filter: _buildTreinoPoolFilter(),
      );
      if (pool.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _treinoQuestions = const [];
          _treinoCurrentIndex = 0;
          _treinoAcertos = 0;
          _treinoErros = 0;
          _treinoRespondida = false;
          _treinoRespostaSelecionada = '';
          _treinoFeedback = '';
          _status = 'Sem questões para treino com os filtros atuais.';
        });
        return;
      }

      final quantidade = _readTreinoQuantidade();
      final ordered = List<QuestionCardItem>.from(pool);
      if (_treinoEmbaralhar) {
        ordered.shuffle(Random());
      }
      final selecionadas = ordered.take(quantidade).toList();

      if (!mounted) {
        return;
      }
      _startTreinoSession(
        selecionadas,
        statusMessage:
            'Treino iniciado com ${selecionadas.length} questão(ões).',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Falha ao iniciar treino: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _montarDiagnostico333() async {
    setState(() {
      _busy = true;
      _status = 'Montando diagnóstico por dificuldade (3/3/3)...';
    });

    try {
      final db = await _localDatabase.open();
      final perLevel = _readDiagnosticoPorNivel();
      const levels = ['facil', 'media', 'dificil'];
      final selected = <QuestionCardItem>[];
      final seen = <String>{};
      final perLevelCount = <String, int>{
        'facil': 0,
        'media': 0,
        'dificil': 0,
      };

      for (final level in levels) {
        final pool = await _localDatabase.searchQuestions(
          db,
          filter: _buildDiagnosticoFilter(
            difficulty: level,
            limit: perLevel * 4,
          ),
        );
        for (final item in pool) {
          if (perLevelCount[level]! >= perLevel) {
            break;
          }
          if (!seen.add(item.id)) {
            continue;
          }
          selected.add(item);
          perLevelCount[level] = (perLevelCount[level] ?? 0) + 1;
        }
      }

      if (selected.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _diagnosticoQuestions = const [];
          _status =
              'Sem questões com dificuldade classificada para montar diagnóstico.';
        });
        return;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _diagnosticoQuestions = selected;
        _status =
            'Diagnóstico montado: fácil ${perLevelCount['facil']} | média ${perLevelCount['media']} | difícil ${perLevelCount['dificil']} '
            '| total ${selected.length}.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Falha ao montar diagnóstico: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _iniciarTreinoDiagnostico() {
    if (_diagnosticoQuestions.isEmpty) {
      setState(() {
        _status = 'Monte o diagnóstico antes de iniciar.';
      });
      return;
    }
    _startTreinoSession(
      List<QuestionCardItem>.from(_diagnosticoQuestions),
      statusMessage:
          'Treino diagnóstico iniciado com ${_diagnosticoQuestions.length} questão(ões).',
    );
  }

  Future<void> _responderTreino(String alternativa) async {
    final current = _currentTreinoQuestion;
    if (current == null || _treinoRespondida) {
      return;
    }

    final answer = current.answer.trim().toUpperCase();
    if (answer.isEmpty) {
      setState(() {
        _treinoRespondida = true;
        _treinoRespostaSelecionada = alternativa;
        _treinoFeedback =
            'Gabarito indisponível para esta questão. Tentativa não registrada.';
        _status = 'Questão sem gabarito no banco.';
      });
      return;
    }

    final isCorrect = alternativa.toUpperCase() == answer;
    setState(() {
      _busy = true;
      _status = isCorrect
          ? 'Registrando acerto do treino...'
          : 'Registrando erro do treino...';
    });

    try {
      final db = await _localDatabase.open();
      await _localDatabase.recordAnswer(
        db,
        questionId: current.id,
        isCorrect: isCorrect,
      );
      await _refreshStats();

      if (!mounted) {
        return;
      }
      setState(() {
        _treinoRespondida = true;
        _treinoRespostaSelecionada = alternativa.toUpperCase();
        if (isCorrect) {
          _treinoAcertos += 1;
        } else {
          _treinoErros += 1;
        }
        _treinoFeedback = isCorrect
            ? 'Correto! Resposta: $answer.'
            : 'Incorreto. Sua resposta: ${alternativa.toUpperCase()} | Gabarito: $answer.';
        _status = isCorrect
            ? 'Acerto registrado no treino.'
            : 'Erro registrado no treino.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Falha ao registrar resposta de treino: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _proximaTreino() {
    if (_treinoQuestions.isEmpty) {
      return;
    }
    final nextIndex = _treinoCurrentIndex + 1;
    if (nextIndex >= _treinoQuestions.length) {
      final answered = _treinoAcertos + _treinoErros;
      final accuracy = answered <= 0 ? 0 : (_treinoAcertos / answered) * 100;
      setState(() {
        _status =
            'Treino concluído. Acertos: $_treinoAcertos | Erros: $_treinoErros | Acurácia ${accuracy.toStringAsFixed(1)}%.';
      });
      return;
    }

    setState(() {
      _treinoCurrentIndex = nextIndex;
      _treinoRespondida = false;
      _treinoRespostaSelecionada = '';
      _treinoFeedback = '';
    });
  }

  void _encerrarTreino() {
    setState(() {
      _treinoQuestions = const [];
      _treinoCurrentIndex = 0;
      _treinoAcertos = 0;
      _treinoErros = 0;
      _treinoRespondida = false;
      _treinoRespostaSelecionada = '';
      _treinoFeedback = '';
      _status = 'Sessão de treino encerrada.';
    });
  }

  Future<void> _iniciarBlocoSugestao(StudyBlockSuggestion item) async {
    if (_busy) {
      return;
    }

    setState(() {
      _questionSkillSelecionada = item.skill;
      if (item.area.trim().isNotEmpty) {
        _questionAreaSelecionada = item.area.trim();
      }
      if (item.materia.trim().isNotEmpty) {
        _questionMateriaSelecionada = item.materia.trim();
      }
      _treinoQuantidadeController.text = '${item.recommendedQuestions}';
      _status = 'Aplicando bloco de estudo para ${item.skill}...';
    });

    await _iniciarTreino();
  }

  List<_AdaptiveSlot> _buildAdaptiveSlots({required int totalQuestions}) {
    if (_skillPriorities.isEmpty || totalQuestions <= 0) {
      return const [];
    }

    final focus =
        _skillPriorities.where((item) => item.band == 'foco').toList();
    final maintenance =
        _skillPriorities.where((item) => item.band == 'manutencao').toList();
    final strong =
        _skillPriorities.where((item) => item.band == 'forte').toList();

    int focusTarget = (totalQuestions * 0.6).round();
    int maintenanceTarget = (totalQuestions * 0.3).round();
    int strongTarget = totalQuestions - focusTarget - maintenanceTarget;
    if (strongTarget < 0) {
      strongTarget = 0;
    }

    List<_AdaptiveSlot> allocate({
      required List<SkillPriorityItem> source,
      required int target,
      required String band,
    }) {
      if (target <= 0 || source.isEmpty) {
        return const [];
      }
      final skillCount = min(source.length, target);
      if (skillCount <= 0) {
        return const [];
      }
      final base = target ~/ skillCount;
      final remainder = target % skillCount;
      final slots = <_AdaptiveSlot>[];
      for (var index = 0; index < skillCount; index += 1) {
        final extra = index < remainder ? 1 : 0;
        final questionCount = base + extra;
        if (questionCount <= 0) {
          continue;
        }
        final item = source[index];
        slots.add(
          _AdaptiveSlot(
            skill: item.skill,
            band: band,
            questionCount: questionCount,
            priorityScore: item.priorityScore,
          ),
        );
      }
      return slots;
    }

    final slots = <_AdaptiveSlot>[
      ...allocate(source: focus, target: focusTarget, band: 'foco'),
      ...allocate(
        source: maintenance,
        target: maintenanceTarget,
        band: 'manutencao',
      ),
      ...allocate(source: strong, target: strongTarget, band: 'forte'),
    ];

    final allocated = slots.fold<int>(
      0,
      (sum, slot) => sum + slot.questionCount,
    );
    var remaining = totalQuestions - allocated;
    var fallbackIndex = 0;
    while (remaining > 0 && _skillPriorities.isNotEmpty) {
      final source = _skillPriorities[fallbackIndex % _skillPriorities.length];
      final existingIndex =
          slots.indexWhere((slot) => slot.skill == source.skill);
      if (existingIndex >= 0) {
        final current = slots[existingIndex];
        slots[existingIndex] = _AdaptiveSlot(
          skill: current.skill,
          band: current.band,
          questionCount: current.questionCount + 1,
          priorityScore: current.priorityScore,
        );
      } else {
        slots.add(
          _AdaptiveSlot(
            skill: source.skill,
            band: source.band,
            questionCount: 1,
            priorityScore: source.priorityScore,
          ),
        );
      }
      fallbackIndex += 1;
      remaining -= 1;
    }

    slots.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
    return slots;
  }

  Future<void> _iniciarSlotAdaptativo(_AdaptiveSlot slot) async {
    if (_busy) {
      return;
    }
    setState(() {
      _questionSkillSelecionada = slot.skill;
      _treinoQuantidadeController.text = '${slot.questionCount}';
      _status = 'Aplicando sessão adaptativa para ${slot.skill}...';
    });
    await _iniciarTreino();
  }

  String _buildSimuladoDistribuicaoResumo(List<QuestionCardItem> items) {
    if (items.isEmpty) {
      return '-';
    }
    final counters = <String, int>{};
    for (final item in items) {
      final key = item.area.trim().isEmpty ? 'Sem área' : item.area.trim();
      counters[key] = (counters[key] ?? 0) + 1;
    }
    final entries = counters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((entry) => '${entry.key}: ${entry.value}').join(' | ');
  }

  Future<void> _montarSimulado() async {
    setState(() {
      _busy = true;
      _status = 'Montando simulado...';
    });

    try {
      final db = await _localDatabase.open();
      final pool = await _localDatabase.searchQuestions(
        db,
        filter: _buildSimuladoPoolFilter(),
      );
      if (pool.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _simuladoQuestions = const [];
          _simuladoTempoTotalMinutos = 0;
          _status = 'Sem questões para montar simulado com os filtros atuais.';
        });
        return;
      }

      final quantidade = _readSimuladoQuantidade();
      final tempoPorQuestao = _readSimuladoTempoPorQuestao();
      final ordered = List<QuestionCardItem>.from(pool);
      if (_simuladoEmbaralhar) {
        ordered.shuffle(Random());
      }
      final selecionadas = ordered.take(quantidade).toList();
      final tempoTotal = selecionadas.length * tempoPorQuestao;

      if (!mounted) {
        return;
      }
      setState(() {
        _simuladoQuestions = selecionadas;
        _simuladoTempoTotalMinutos = tempoTotal;
        _status =
            'Simulado pronto: ${selecionadas.length} questão(ões), tempo sugerido $tempoTotal min.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Falha ao montar simulado: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _limparSimulado() {
    setState(() {
      _simuladoQuestions = const [];
      _simuladoTempoTotalMinutos = 0;
      _status = 'Simulado limpo.';
    });
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

  String _inferErrorReasonForSuggestion(
    StudyBlockSuggestion item,
    SkillPriorityItem? priority,
  ) {
    if (item.attempts <= 2) {
      return 'Poucas tentativas ainda; consolidar base da habilidade.';
    }
    if (item.accuracy < 0.45) {
      return 'Acurácia muito baixa com recorrência de erros.';
    }
    if (item.accuracy < 0.65) {
      return 'Acurácia intermediária; precisa reforçar método de resolução.';
    }
    if (priority != null && priority.daysSinceLastSeen >= 10) {
      return 'Bom desempenho, mas com alta recência sem revisão.';
    }
    return 'Manter consistência para estabilizar desempenho.';
  }

  Future<void> _revisarTeoriaSuggestion(StudyBlockSuggestion item) async {
    final hasModule = item.materia.trim().isNotEmpty || item.modulo > 0;
    final message = hasModule
        ? 'Revisar teoria: ${item.materia.isEmpty ? '-' : item.materia}'
            '${item.modulo > 0 ? ' | módulo ${item.modulo}' : ''}'
            '${item.page.isEmpty ? '' : ' | pág. ${item.page}'}'
            '${item.title.isEmpty ? '' : ' | ${item.title}'}'
        : 'Sem módulo exato para ${item.skill}. Revisar conteúdo-base dessa habilidade.';
    setState(() {
      _status = message;
    });
  }

  Future<void> _copyStudyPromptForSuggestion(
    StudyBlockSuggestion item, {
    required String mode,
  }) async {
    SkillPriorityItem? priority;
    for (final entry in _skillPriorities) {
      if (entry.skill == item.skill) {
        priority = entry;
        break;
      }
    }
    final reason = _inferErrorReasonForSuggestion(item, priority);
    final area =
        item.area.trim().isEmpty ? _questionAreaSelecionada : item.area;
    final topicHint = item.title.trim().isNotEmpty ? item.title : item.materia;
    final moduleTitle =
        item.title.trim().isEmpty ? 'Módulo ${item.modulo}' : item.title;

    late final String prompt;
    late final String successMessage;
    if (mode == 'videos') {
      prompt = StudyPromptBuilder.buildVideosPrompt(
        skillCode: item.skill,
        area: area,
        topicHint: topicHint,
      );
      successMessage = 'Prompt de vídeos copiado.';
    } else if (mode == 'treino') {
      prompt = StudyPromptBuilder.buildPracticePrompt(
        skillCode: item.skill,
        area: area,
        topicHint: topicHint,
      );
      successMessage = 'Prompt de treino copiado.';
    } else {
      prompt = StudyPromptBuilder.buildFullLessonPrompt(
        skillCode: item.skill,
        area: area,
        moduleTitle: moduleTitle,
        accuracy: item.accuracy,
        attempts: item.attempts,
        errorReason: reason,
        topicHint: topicHint,
      );
      successMessage = 'Prompt de aula completa copiado.';
    }

    await Clipboard.setData(ClipboardData(text: prompt));
    if (!mounted) {
      return;
    }
    setState(() {
      _studyPromptPreview = prompt;
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

  Future<void> _copyEssayRewritePrompt() async {
    final theme = _essayThemeController.text.trim();
    if (theme.isEmpty) {
      setState(() {
        _status = 'Informe o tema da redação para gerar o prompt de reescrita.';
      });
      return;
    }
    final rawFeedback = _essayFeedbackController.text.trim();
    if (rawFeedback.isEmpty) {
      setState(() {
        _status = 'Cole o feedback da IA para gerar o prompt de reescrita.';
      });
      return;
    }

    final prompt = EssayPromptBuilder.buildRewritePrompt(
      themeTitle: theme,
      studentText: _essayStudentTextController.text.trim(),
      iaFeedback: rawFeedback,
      studentContext: _essayContextController.text.trim(),
    );
    await _copyPrompt(
      prompt: prompt,
      successMessage: 'Prompt de reescrita pós-correção copiado.',
    );
  }

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

  Widget _buildStudentProfileCard() {
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
                            setState(() {
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
                                setState(() {
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
                          setState(() {
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
            ),
            const SizedBox(height: 4),
            Text(plan.note.isEmpty ? '-' : plan.note),
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
      setState(() {
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
                            setState(() {
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
                  child: const Text('Treinar diagnóstico'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Resultado atual | fácil: $easyCount | média: $mediumCount | difícil: $hardCount | total: ${_diagnosticoQuestions.length}',
            ),
            if (_diagnosticoQuestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._diagnosticoQuestions.take(12).map(
                    (item) => Text(
                      'Q ${item.year}/${item.day}/${item.number} '
                      '| ${item.difficulty.isEmpty ? '-' : item.difficulty} '
                      '| ${item.skill.isEmpty ? '-' : item.skill}',
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
                            setState(() {
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
                            setState(() {
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
                            setState(() {
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
                            setState(() {
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
                            setState(() {
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
                            setState(() {
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
                            setState(() {
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
                            setState(() {
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
                            setState(() {
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
                            setState(() {
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
            _buildDiagnosticoCard(),
            const SizedBox(height: 12),
            _buildSkillPriorityCard(),
            const SizedBox(height: 12),
            _buildAdaptiveSessionCard(),
            const SizedBox(height: 12),
            _buildModuleSuggestionsCard(),
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
            const SizedBox(height: 12),
            SelectableText(_status),
          ],
        ),
      ),
    );
  }
}
