import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../config/app_config.dart';
import '../data/local_database.dart';
import '../essay/essay_feedback_parser.dart';
import '../essay/essay_prompt_builder.dart';
import '../study/offline_planner.dart';
import '../study/study_prompt_builder.dart';
import 'app_theme.dart';
import '../update/content_updater.dart';

part 'home_page_tabs_profile.dart';
part 'home_page_advanced_cards.dart';

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

class _ReelQuestionEntry {
  const _ReelQuestionEntry({
    required this.question,
    required this.skill,
    required this.band,
    required this.priorityScore,
  });

  final QuestionCardItem question;
  final String skill;
  final String band;
  final double priorityScore;
}

class _DiagnosticAnswerEntry {
  const _DiagnosticAnswerEntry({
    required this.question,
    required this.selectedAlternative,
    required this.isCorrect,
    required this.elapsedSeconds,
  });

  final QuestionCardItem question;
  final String selectedAlternative;
  final bool isCorrect;
  final int elapsedSeconds;
}

class _DiagnosticSubjectScore {
  const _DiagnosticSubjectScore({
    required this.subject,
    required this.correct,
    required this.total,
  });

  final String subject;
  final int correct;
  final int total;

  double get accuracy => total <= 0 ? 0 : correct / total;
}

class _DiagnosticSkillDeficit {
  const _DiagnosticSkillDeficit({
    required this.skill,
    required this.correct,
    required this.total,
  });

  final String skill;
  final int correct;
  final int total;

  double get accuracy => total <= 0 ? 0 : correct / total;
  double get deficit => 1 - accuracy;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onAppearanceChanged});

  final void Function(String themeMode, double fontScale)? onAppearanceChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const Duration _autoUpdateInterval = Duration(minutes: 5);
  static const Duration _autoUpdateResumeDebounce = Duration(minutes: 1);
  static const int _tabAulas = 0;
  static const int _tabQuestoes = 1;
  static const int _tabPerfil = 2;

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
  final Map<String, String> _reelMarkedAnswers = <String, String>{};
  final Map<String, String> _reelFeedbackByQuestion = <String, String>{};
  Timer? _autoUpdateTimer;
  bool _autoUpdateInProgress = false;

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
  DateTime? _treinoQuestionStartedAt;
  List<QuestionCardItem> _diagnosticoQuestions = const [];
  List<QuestionCardItem> _diagnosticoSessionQuestions = const [];
  int _diagnosticoCurrentIndex = 0;
  int _diagnosticoAcertos = 0;
  int _diagnosticoErros = 0;
  bool _diagnosticoRespondida = false;
  String _diagnosticoRespostaSelecionada = '';
  String _diagnosticoFeedback = '';
  DateTime? _diagnosticoQuestionStartedAt;
  List<_DiagnosticAnswerEntry> _diagnosticoAnswerEntries = const [];
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
  DateTime? _lastAutoUpdateCheckAt;
  int _selectedTabIndex = _tabQuestoes;
  int _reelCurrentIndex = 0;
  List<_ReelQuestionEntry> _plannerReels = const [];
  DateTime? _reelQuestionStartedAt;
  String _focusedStudySkill = '';
  String _focusedStudyMateria = '';
  int _focusedStudyModulo = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStats();
    _scheduleAutoUpdateChecks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoUpdateTimer?.cancel();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    final lastCheck = _lastAutoUpdateCheckAt;
    if (lastCheck != null &&
        DateTime.now().difference(lastCheck) < _autoUpdateResumeDebounce) {
      return;
    }
    _runAutoUpdateCheck();
  }

  void _scheduleAutoUpdateChecks() {
    _autoUpdateTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runAutoUpdateCheck(onStartup: true);
    });
    _autoUpdateTimer = Timer.periodic(
      _autoUpdateInterval,
      (_) => _runAutoUpdateCheck(),
    );
  }

  Future<void> _runAutoUpdateCheck({bool onStartup = false}) async {
    if (!mounted || _busy || _autoUpdateInProgress) {
      return;
    }
    final manifestText = _manifestController.text.trim();
    if (manifestText.isEmpty) {
      return;
    }
    final manifestUri = Uri.tryParse(manifestText);
    if (manifestUri == null || !manifestUri.hasScheme) {
      return;
    }

    _autoUpdateInProgress = true;
    try {
      final updater = ContentUpdater(
        localDatabase: _localDatabase,
        manifestUri: manifestUri,
      );
      final result = await updater.checkAndUpdate();
      final now = DateTime.now();
      if (result.updated) {
        await _refreshStats();
        if (!mounted) {
          return;
        }
        _updateState(() {
          _lastAutoUpdateCheckAt = now;
          _status =
              'Atualização automática aplicada (${result.currentVersion}).';
        });
        return;
      }
      if (!mounted) {
        return;
      }
      _updateState(() {
        _lastAutoUpdateCheckAt = now;
        if (onStartup) {
          _status = result.message;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _updateState(() {
        _lastAutoUpdateCheckAt = DateTime.now();
        if (onStartup) {
          _status = 'Falha na verificação automática: $error';
        }
      });
    } finally {
      _autoUpdateInProgress = false;
    }
  }

  void _updateState(VoidCallback fn) {
    setState(fn);
  }

  String _autoUpdateStatusLabel() {
    final lastCheck = _lastAutoUpdateCheckAt;
    if (lastCheck == null) {
      return 'Verificação automática: ao abrir + a cada 5 min + ao retornar ao app (ainda sem checagem).';
    }
    final dd = lastCheck.day.toString().padLeft(2, '0');
    final mm = lastCheck.month.toString().padLeft(2, '0');
    final hh = lastCheck.hour.toString().padLeft(2, '0');
    final min = lastCheck.minute.toString().padLeft(2, '0');
    return 'Verificação automática: ao abrir + a cada 5 min + ao retornar ao app | última: $dd/$mm $hh:$min';
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

  String _tabTitle() {
    if (_selectedTabIndex == _tabQuestoes) {
      return 'Questões para você';
    }
    if (_selectedTabIndex == _tabAulas) {
      return 'Aulas e módulos';
    }
    if (_selectedTabIndex == _tabPerfil) {
      return 'Perfil e configurações';
    }
    return 'Enem Questões';
  }

  String _bandLabel(String band) {
    if (band == 'foco') {
      return 'Foco';
    }
    if (band == 'manutencao') {
      return 'Manutenção';
    }
    if (band == 'forte') {
      return 'Forte';
    }
    return 'Recomendado';
  }

  _ReelQuestionEntry? get _currentReelEntry {
    if (_plannerReels.isEmpty) {
      return null;
    }
    if (_reelCurrentIndex < 0 || _reelCurrentIndex >= _plannerReels.length) {
      return null;
    }
    return _plannerReels[_reelCurrentIndex];
  }

  Future<List<_ReelQuestionEntry>> _buildPlannerReels(
    Database db, {
    required List<SkillPriorityItem> priorities,
    int totalQuestions = 18,
  }) async {
    if (priorities.isEmpty || totalQuestions <= 0) {
      final fallback = await _localDatabase.searchQuestions(
        db,
        filter: const QuestionFilter(limit: 18),
      );
      return fallback
          .map(
            (item) => _ReelQuestionEntry(
              question: item,
              skill: item.skill,
              band: 'forte',
              priorityScore: 0,
            ),
          )
          .toList();
    }

    final slots = _buildAdaptiveSlots(
      totalQuestions: totalQuestions,
      priorities: priorities,
    );
    final entries = <_ReelQuestionEntry>[];
    final seenIds = <String>{};
    final random = Random();

    for (final slot in slots) {
      final pool = await _localDatabase.searchQuestions(
        db,
        filter: QuestionFilter(
          skill: slot.skill,
          limit: max(8, slot.questionCount * 4),
        ),
      );
      if (pool.isEmpty) {
        continue;
      }
      final ordered = List<QuestionCardItem>.from(pool)..shuffle(random);
      for (final item in ordered) {
        if (!seenIds.add(item.id)) {
          continue;
        }
        entries.add(
          _ReelQuestionEntry(
            question: item,
            skill: slot.skill,
            band: slot.band,
            priorityScore: slot.priorityScore,
          ),
        );
        if (entries.length >= totalQuestions) {
          return entries;
        }
        final perSkillCount =
            entries.where((entry) => entry.skill == slot.skill);
        if (perSkillCount.length >= slot.questionCount) {
          break;
        }
      }
    }

    if (entries.length < totalQuestions) {
      final fallback = await _localDatabase.searchQuestions(
        db,
        filter: QuestionFilter(limit: totalQuestions * 2),
      );
      for (final item in fallback) {
        if (!seenIds.add(item.id)) {
          continue;
        }
        entries.add(
          _ReelQuestionEntry(
            question: item,
            skill: item.skill,
            band: 'manutencao',
            priorityScore: 0,
          ),
        );
        if (entries.length >= totalQuestions) {
          break;
        }
      }
    }

    return entries;
  }

  Color _statusColor(BuildContext context) {
    final palette = context.appPalette;
    if (_busy) {
      return palette.accent;
    }
    final normalized = _status.trim().toLowerCase();
    if (normalized.contains('falha') ||
        normalized.contains('inválido') ||
        normalized.contains('erro')) {
      return palette.error;
    }
    if (normalized.contains('alerta') ||
        normalized.contains('atenção') ||
        normalized.contains('pendente')) {
      return palette.warning;
    }
    if (normalized.contains('sucesso') ||
        normalized.contains('conclu') ||
        normalized.contains('salvo') ||
        normalized.contains('importado') ||
        normalized.contains('exportado')) {
      return palette.success;
    }
    return palette.muted;
  }

  Color _riskColor(BuildContext context, String riskLabel) {
    final palette = context.appPalette;
    if (riskLabel == 'alto') {
      return palette.error;
    }
    if (riskLabel == 'medio') {
      return palette.warning;
    }
    if (riskLabel == 'baixo') {
      return palette.success;
    }
    return palette.muted;
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

  Future<void> _refreshStats({bool refreshReels = true}) async {
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
    final plannerReels = refreshReels
        ? await _buildPlannerReels(
            db,
            priorities: skillPriorities,
            totalQuestions: 18,
          )
        : _plannerReels;
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
      _plannerReels = plannerReels;
      if (_plannerReels.isEmpty) {
        _reelCurrentIndex = 0;
      } else if (_reelCurrentIndex >= _plannerReels.length) {
        _reelCurrentIndex = _plannerReels.length - 1;
      }
      if (refreshReels) {
        _reelQuestionStartedAt = _plannerReels.isEmpty ? null : DateTime.now();
        final ids = _plannerReels.map((entry) => entry.question.id).toSet();
        _reelMarkedAnswers.removeWhere((key, _) => !ids.contains(key));
        _reelFeedbackByQuestion.removeWhere((key, _) => !ids.contains(key));
      }
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

  Future<void> _responderReel(String alternativa) async {
    final current = _currentReelEntry;
    if (current == null) {
      return;
    }
    final question = current.question;
    if (_reelMarkedAnswers.containsKey(question.id)) {
      return;
    }
    final answer = question.answer.trim().toUpperCase();
    if (answer.isEmpty) {
      setState(() {
        _reelMarkedAnswers[question.id] = alternativa.toUpperCase();
        _reelFeedbackByQuestion[question.id] =
            'Questão sem gabarito no banco. Resposta não registrada.';
        _status = 'Questão sem gabarito para registrar resposta.';
      });
      return;
    }

    final marked = alternativa.toUpperCase();
    final isCorrect = marked == answer;
    final now = DateTime.now();
    final elapsedSeconds = max(
      1,
      now.difference(_reelQuestionStartedAt ?? now).inSeconds,
    );
    setState(() {
      _busy = true;
      _status = isCorrect
          ? 'Registrando acerto no reels...'
          : 'Registrando erro no reels...';
    });

    try {
      final db = await _localDatabase.open();
      await _localDatabase.recordAnswer(
        db,
        questionId: question.id,
        isCorrect: isCorrect,
        elapsedSeconds: elapsedSeconds,
        answerSource: 'reels',
      );
      await _refreshStats(refreshReels: false);
      if (!mounted) {
        return;
      }
      setState(() {
        _reelMarkedAnswers[question.id] = marked;
        _reelFeedbackByQuestion[question.id] = isCorrect
            ? 'Correto! Gabarito: $answer.'
            : 'Incorreto. Marcada: $marked | Gabarito: $answer.';
        _status = isCorrect
            ? 'Acerto registrado no reels.'
            : 'Erro registrado no reels.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Falha ao registrar resposta do reels: $error';
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
      _treinoQuestionStartedAt = DateTime.now();
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
          _diagnosticoSessionQuestions = const [];
          _diagnosticoCurrentIndex = 0;
          _diagnosticoAcertos = 0;
          _diagnosticoErros = 0;
          _diagnosticoRespondida = false;
          _diagnosticoRespostaSelecionada = '';
          _diagnosticoFeedback = '';
          _diagnosticoQuestionStartedAt = null;
          _diagnosticoAnswerEntries = const [];
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
        _diagnosticoSessionQuestions = const [];
        _diagnosticoCurrentIndex = 0;
        _diagnosticoAcertos = 0;
        _diagnosticoErros = 0;
        _diagnosticoRespondida = false;
        _diagnosticoRespostaSelecionada = '';
        _diagnosticoFeedback = '';
        _diagnosticoQuestionStartedAt = null;
        _diagnosticoAnswerEntries = const [];
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
    setState(() {
      _diagnosticoSessionQuestions = List<QuestionCardItem>.from(
        _diagnosticoQuestions,
      );
      _diagnosticoCurrentIndex = 0;
      _diagnosticoAcertos = 0;
      _diagnosticoErros = 0;
      _diagnosticoRespondida = false;
      _diagnosticoRespostaSelecionada = '';
      _diagnosticoFeedback = '';
      _diagnosticoQuestionStartedAt = DateTime.now();
      _diagnosticoAnswerEntries = const [];
      _status =
          'Diagnóstico iniciado com ${_diagnosticoSessionQuestions.length} questão(ões).';
    });
  }

  QuestionCardItem? get _currentDiagnosticoQuestion {
    if (_diagnosticoSessionQuestions.isEmpty) {
      return null;
    }
    if (_diagnosticoCurrentIndex < 0 ||
        _diagnosticoCurrentIndex >= _diagnosticoSessionQuestions.length) {
      return null;
    }
    return _diagnosticoSessionQuestions[_diagnosticoCurrentIndex];
  }

  String _diagnosticoSubjectKey(QuestionCardItem item) {
    final materia = item.materia.trim();
    if (materia.isNotEmpty) {
      return materia;
    }
    final discipline = item.discipline.trim();
    if (discipline.isNotEmpty) {
      return discipline;
    }
    final area = item.area.trim();
    if (area.isNotEmpty) {
      return area;
    }
    return 'Sem matéria';
  }

  List<_DiagnosticSubjectScore> _diagnosticoSubjectScores() {
    final counters = <String, List<int>>{};
    for (final entry in _diagnosticoAnswerEntries) {
      final subject = _diagnosticoSubjectKey(entry.question);
      final pair = counters.putIfAbsent(subject, () => <int>[0, 0]);
      pair[1] += 1;
      if (entry.isCorrect) {
        pair[0] += 1;
      }
    }
    final result = counters.entries
        .map(
          (entry) => _DiagnosticSubjectScore(
            subject: entry.key,
            correct: entry.value[0],
            total: entry.value[1],
          ),
        )
        .toList();
    result.sort((a, b) {
      final byAccuracy = a.accuracy.compareTo(b.accuracy);
      if (byAccuracy != 0) {
        return byAccuracy;
      }
      return a.subject.compareTo(b.subject);
    });
    return result;
  }

  List<_DiagnosticSkillDeficit> _diagnosticoTopSkillDeficits({int limit = 5}) {
    final counters = <String, List<int>>{};
    for (final entry in _diagnosticoAnswerEntries) {
      final skill = entry.question.skill.trim().toUpperCase();
      if (skill.isEmpty) {
        continue;
      }
      final pair = counters.putIfAbsent(skill, () => <int>[0, 0]);
      pair[1] += 1;
      if (entry.isCorrect) {
        pair[0] += 1;
      }
    }
    final deficits = counters.entries
        .map(
          (entry) => _DiagnosticSkillDeficit(
            skill: entry.key,
            correct: entry.value[0],
            total: entry.value[1],
          ),
        )
        .toList();
    deficits.sort((a, b) {
      final byDeficit = b.deficit.compareTo(a.deficit);
      if (byDeficit != 0) {
        return byDeficit;
      }
      final byTotal = b.total.compareTo(a.total);
      if (byTotal != 0) {
        return byTotal;
      }
      return a.skill.compareTo(b.skill);
    });
    return deficits.take(limit).toList();
  }

  String _diagnosticoErroDominante() {
    final errors =
        _diagnosticoAnswerEntries.where((entry) => !entry.isCorrect).toList();
    if (errors.isEmpty) {
      return 'Sem erro dominante: sem erros no diagnóstico atual.';
    }

    final fastErrors =
        errors.where((entry) => entry.elapsedSeconds <= 30).length;
    final slowErrors =
        errors.where((entry) => entry.elapsedSeconds >= 120).length;
    final easyErrors = errors
        .where(
          (entry) => entry.question.difficulty.trim().toLowerCase() == 'facil',
        )
        .length;

    final skillErrorCounts = <String, int>{};
    for (final entry in errors) {
      final skill = entry.question.skill.trim().toUpperCase();
      if (skill.isEmpty) {
        continue;
      }
      skillErrorCounts[skill] = (skillErrorCounts[skill] ?? 0) + 1;
    }
    String repeatedSkill = '';
    var repeatedSkillCount = 0;
    for (final pair in skillErrorCounts.entries) {
      if (pair.value > repeatedSkillCount) {
        repeatedSkill = pair.key;
        repeatedSkillCount = pair.value;
      }
    }

    final patternScores = <String, int>{
      'base_fraca': easyErrors,
      'lacuna_especifica': repeatedSkillCount >= 2 ? repeatedSkillCount : 0,
      'metodo_lento': slowErrors,
      'chute_rapido': fastErrors,
    };
    final dominant = patternScores.entries.reduce(
      (best, current) => current.value > best.value ? current : best,
    );

    if (dominant.value <= 0) {
      return 'Padrão misto de erro: revisar resolução passo a passo da habilidade.';
    }

    if (dominant.key == 'base_fraca') {
      return 'Erro dominante: base fraca (erros em questões fáceis).';
    }
    if (dominant.key == 'lacuna_especifica') {
      final suffix = repeatedSkill.isEmpty ? '' : ' em $repeatedSkill';
      return 'Erro dominante: lacuna específica$suffix (erro recorrente).';
    }
    if (dominant.key == 'metodo_lento') {
      return 'Erro dominante: método/insegurança (erro com tempo alto).';
    }
    return 'Erro dominante: chute/falta de base (erro rápido).';
  }

  Future<void> _responderDiagnostico(String alternativa) async {
    final current = _currentDiagnosticoQuestion;
    if (current == null || _diagnosticoRespondida) {
      return;
    }

    final answer = current.answer.trim().toUpperCase();
    if (answer.isEmpty) {
      setState(() {
        _diagnosticoRespondida = true;
        _diagnosticoRespostaSelecionada = alternativa.toUpperCase();
        _diagnosticoFeedback =
            'Gabarito indisponível para esta questão. Tentativa não registrada.';
        _status = 'Questão do diagnóstico sem gabarito.';
      });
      return;
    }

    final now = DateTime.now();
    final elapsedSeconds = max(
      1,
      now.difference(_diagnosticoQuestionStartedAt ?? now).inSeconds,
    );
    final isCorrect = alternativa.toUpperCase() == answer;

    setState(() {
      _busy = true;
      _status = isCorrect
          ? 'Registrando acerto do diagnóstico...'
          : 'Registrando erro do diagnóstico...';
    });

    try {
      final db = await _localDatabase.open();
      await _localDatabase.recordAnswer(
        db,
        questionId: current.id,
        isCorrect: isCorrect,
        elapsedSeconds: elapsedSeconds,
        answerSource: 'diagnostico',
      );
      await _refreshStats(refreshReels: false);

      if (!mounted) {
        return;
      }
      setState(() {
        _diagnosticoRespondida = true;
        _diagnosticoRespostaSelecionada = alternativa.toUpperCase();
        _diagnosticoAnswerEntries = <_DiagnosticAnswerEntry>[
          ..._diagnosticoAnswerEntries,
          _DiagnosticAnswerEntry(
            question: current,
            selectedAlternative: alternativa.toUpperCase(),
            isCorrect: isCorrect,
            elapsedSeconds: elapsedSeconds,
          ),
        ];
        if (isCorrect) {
          _diagnosticoAcertos += 1;
        } else {
          _diagnosticoErros += 1;
        }
        _diagnosticoFeedback = isCorrect
            ? 'Correto! Resposta: $answer.'
            : 'Incorreto. Sua resposta: ${alternativa.toUpperCase()} | Gabarito: $answer.';
        _status = isCorrect
            ? 'Acerto registrado no diagnóstico.'
            : 'Erro registrado no diagnóstico.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Falha ao registrar resposta do diagnóstico: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _proximaDiagnostico() {
    if (_diagnosticoSessionQuestions.isEmpty) {
      return;
    }
    final nextIndex = _diagnosticoCurrentIndex + 1;
    if (nextIndex >= _diagnosticoSessionQuestions.length) {
      final answered = _diagnosticoAcertos + _diagnosticoErros;
      final accuracy =
          answered <= 0 ? 0 : (_diagnosticoAcertos / answered) * 100;
      setState(() {
        _status =
            'Diagnóstico concluído. Acertos: $_diagnosticoAcertos | Erros: $_diagnosticoErros | Acurácia ${accuracy.toStringAsFixed(1)}%.';
        _diagnosticoQuestionStartedAt = null;
      });
      return;
    }

    setState(() {
      _diagnosticoCurrentIndex = nextIndex;
      _diagnosticoRespondida = false;
      _diagnosticoRespostaSelecionada = '';
      _diagnosticoFeedback = '';
      _diagnosticoQuestionStartedAt = DateTime.now();
    });
  }

  void _encerrarDiagnostico() {
    setState(() {
      _diagnosticoSessionQuestions = const [];
      _diagnosticoCurrentIndex = 0;
      _diagnosticoAcertos = 0;
      _diagnosticoErros = 0;
      _diagnosticoRespondida = false;
      _diagnosticoRespostaSelecionada = '';
      _diagnosticoFeedback = '';
      _diagnosticoQuestionStartedAt = null;
      _diagnosticoAnswerEntries = const [];
      _status = 'Sessão de diagnóstico encerrada.';
    });
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
    final now = DateTime.now();
    final elapsedSeconds = max(
      1,
      now.difference(_treinoQuestionStartedAt ?? now).inSeconds,
    );
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
        elapsedSeconds: elapsedSeconds,
        answerSource: 'treino',
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
      _treinoQuestionStartedAt = DateTime.now();
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
      _treinoQuestionStartedAt = null;
      _status = 'Sessão de treino encerrada.';
    });
  }

  Future<void> _iniciarBlocoSugestao(StudyBlockSuggestion item) async {
    if (_busy) {
      return;
    }

    setState(() {
      _selectedTabIndex = _tabQuestoes;
      _questionSkillSelecionada = item.skill;
      if (item.area.trim().isNotEmpty) {
        _questionAreaSelecionada = item.area.trim();
      }
      if (item.materia.trim().isNotEmpty) {
        _questionMateriaSelecionada = item.materia.trim();
      }
      _focusedStudySkill = item.skill.trim();
      _focusedStudyMateria = item.materia.trim();
      _focusedStudyModulo = item.modulo;
      _treinoQuantidadeController.text = '${item.recommendedQuestions}';
      _status = 'Abrindo treino recomendado para ${item.skill}...';
    });

    await _iniciarTreino();
  }

  List<_AdaptiveSlot> _buildAdaptiveSlots({
    required int totalQuestions,
    List<SkillPriorityItem>? priorities,
  }) {
    final sourcePriorities = priorities ?? _skillPriorities;
    if (sourcePriorities.isEmpty || totalQuestions <= 0) {
      return const [];
    }

    final focus =
        sourcePriorities.where((item) => item.band == 'foco').toList();
    final maintenance =
        sourcePriorities.where((item) => item.band == 'manutencao').toList();
    final strong =
        sourcePriorities.where((item) => item.band == 'forte').toList();

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
    while (remaining > 0 && sourcePriorities.isNotEmpty) {
      final source = sourcePriorities[fallbackIndex % sourcePriorities.length];
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
        ? 'Aba Aulas aberta para revisar: ${item.materia.isEmpty ? '-' : item.materia}'
            '${item.modulo > 0 ? ' | módulo ${item.modulo}' : ''}'
            '${item.page.isEmpty ? '' : ' | pág. ${item.page}'}'
            '${item.title.isEmpty ? '' : ' | ${item.title}'}'
        : 'Aba Aulas aberta. Sem módulo exato para ${item.skill}; revisar conteúdo-base dessa habilidade.';
    setState(() {
      _selectedTabIndex = _tabAulas;
      _focusedStudySkill = item.skill.trim();
      _focusedStudyMateria = item.materia.trim();
      _focusedStudyModulo = item.modulo;
      _status = message;
    });
  }

  Future<void> _iniciarTreinoModuloSuggestion(ModuleSuggestion item) async {
    if (_busy) {
      return;
    }

    setState(() {
      _selectedTabIndex = _tabQuestoes;
      _questionSkillSelecionada = item.matchedSkill.trim();
      if (item.area.trim().isNotEmpty) {
        _questionAreaSelecionada = item.area.trim();
      }
      if (item.materia.trim().isNotEmpty) {
        _questionMateriaSelecionada = item.materia.trim();
      }
      _focusedStudySkill = item.matchedSkill.trim();
      _focusedStudyMateria = item.materia.trim();
      _focusedStudyModulo = item.modulo;
      _status = 'Abrindo treino para ${item.matchedSkill}...';
    });

    await _iniciarTreino();
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
    SkillErrorProfile? errorProfile;
    try {
      final db = await _localDatabase.open();
      errorProfile = await _localDatabase.loadSkillErrorProfile(
        db,
        skill: item.skill,
        topicLimit: 5,
      );
    } catch (_) {
      errorProfile = null;
    }

    final pacing = errorProfile?.pacing ?? 'equilibrado';
    final levelBreak = errorProfile?.levelBreak ?? 'media';
    final pattern = errorProfile?.pattern ?? 'aleatorio';
    final topicTags = errorProfile?.topicTags ?? <String>[];

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
        pacing: pacing,
        levelBreak: levelBreak,
        topicTags: topicTags,
        pattern: pattern,
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

  @override
  Widget build(BuildContext context) {
    final tabBody = _selectedTabIndex == _tabAulas
        ? _buildAulasTab()
        : _selectedTabIndex == _tabQuestoes
            ? _buildReelsTab()
            : _selectedTabIndex == _tabPerfil
                ? _buildPerfilTab()
                : _buildReelsTab();

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabTitle()),
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          Expanded(child: tabBody),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Aulas',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_display_outlined),
            selectedIcon: Icon(Icons.smart_display),
            label: 'Questões',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
