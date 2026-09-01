import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../config/app_config.dart';

const String profileThemeModeSystem = 'system';
const String profileThemeModeLight = 'light';
const String profileThemeModeDark = 'dark';
const double profileFontScaleMin = 0.85;
const double profileFontScaleMax = 1.40;
const double profileFontScaleDefault = 1.00;

String normalizeProfileThemeMode(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized == profileThemeModeLight) {
    return profileThemeModeLight;
  }
  if (normalized == profileThemeModeDark) {
    return profileThemeModeDark;
  }
  return profileThemeModeSystem;
}

double normalizeProfileFontScale(double? value) {
  final normalized = value ?? profileFontScaleDefault;
  if (!normalized.isFinite) {
    return profileFontScaleDefault;
  }
  return normalized.clamp(profileFontScaleMin, profileFontScaleMax).toDouble();
}

class WeakSkillStat {
  const WeakSkillStat({
    required this.skill,
    required this.correct,
    required this.total,
  });

  final String skill;
  final int correct;
  final int total;

  double get accuracy => total <= 0 ? 0 : correct / total;
}

class SkillPriorityItem {
  const SkillPriorityItem({
    required this.skill,
    required this.accuracy,
    required this.attempts,
    required this.daysSinceLastSeen,
    required this.deficit,
    required this.recency,
    required this.confidence,
    required this.priorityScore,
    required this.band,
  });

  final String skill;
  final double accuracy;
  final int attempts;
  final int daysSinceLastSeen;
  final double deficit;
  final double recency;
  final double confidence;
  final double priorityScore;
  final String band;
}

class ConceptQuestionCandidate {
  const ConceptQuestionCandidate({
    required this.question,
    required this.conceptId,
    required this.conceptWeight,
    required this.conceptPriorityScore,
    required this.score,
  });

  final QuestionCardItem question;
  final String conceptId;
  final double conceptWeight;
  final double conceptPriorityScore;
  final double score;
}

class ConceptDiagnosticSession {
  const ConceptDiagnosticSession({
    required this.conceptId,
    required this.conceptLabel,
    required this.questions,
  });

  final String conceptId;
  final String conceptLabel;
  final List<QuestionCardItem> questions;
}

class _ConceptPriorityItem {
  const _ConceptPriorityItem({
    required this.conceptId,
    required this.priorityScore,
  });

  final String conceptId;
  final double priorityScore;
}

class SkillErrorProfile {
  const SkillErrorProfile({
    required this.skill,
    required this.attempts,
    required this.accuracy,
    required this.pacing,
    required this.levelBreak,
    required this.pattern,
    required this.topicTags,
    required this.averageSeconds,
    required this.highTimeErrorSignal,
    required this.quickErrorSignal,
    required this.repeatedTagErrorSignal,
    required this.easyErrorSignal,
    required this.evidence,
  });

  final String skill;
  final int attempts;
  final double accuracy;
  final String pacing;
  final String levelBreak;
  final String pattern;
  final List<String> topicTags;
  final double averageSeconds;
  final bool highTimeErrorSignal;
  final bool quickErrorSignal;
  final bool repeatedTagErrorSignal;
  final bool easyErrorSignal;
  final List<SkillErrorEvidence> evidence;
}

class SkillErrorEvidence {
  const SkillErrorEvidence({
    required this.signal,
    required this.evidenceType,
    required this.evidenceValue,
    required this.errorCount,
    required this.totalCount,
    required this.errorRate,
  });

  final String signal;
  final String evidenceType;
  final String evidenceValue;
  final int errorCount;
  final int totalCount;
  final double errorRate;
}

class ModuleSuggestion {
  const ModuleSuggestion({
    required this.id,
    required this.volume,
    required this.area,
    required this.materia,
    required this.modulo,
    required this.title,
    required this.page,
    required this.skillsRaw,
    required this.matchedSkill,
  });

  final String id;
  final int volume;
  final String area;
  final String materia;
  final int modulo;
  final String title;
  final String page;
  final String skillsRaw;
  final String matchedSkill;
}

class StudyBlockSuggestion {
  const StudyBlockSuggestion({
    required this.skill,
    required this.accuracy,
    required this.attempts,
    required this.correct,
    required this.questionPool,
    required this.recommendedQuestions,
    required this.recommendedMinutes,
    required this.area,
    required this.materia,
    required this.modulo,
    required this.title,
    required this.page,
  });

  final String skill;
  final double accuracy;
  final int attempts;
  final int correct;
  final int questionPool;
  final int recommendedQuestions;
  final int recommendedMinutes;
  final String area;
  final String materia;
  final int modulo;
  final String title;
  final String page;
}

class ModuleQuestionMatch {
  const ModuleQuestionMatch({
    required this.questionId,
    required this.year,
    required this.day,
    required this.number,
    required this.variation,
    required this.area,
    required this.discipline,
    required this.materia,
    required this.volume,
    required this.modulo,
    required this.competencias,
    required this.habilidades,
    required this.assuntosMatch,
    required this.scoreMatch,
    required this.tipoMatch,
    required this.confianca,
    required this.revisadoManual,
  });

  final String questionId;
  final int year;
  final int day;
  final int number;
  final int variation;
  final String area;
  final String discipline;
  final String materia;
  final int volume;
  final int modulo;
  final String competencias;
  final String habilidades;
  final String assuntosMatch;
  final double scoreMatch;
  final String tipoMatch;
  final String confianca;
  final bool revisadoManual;
}

class ModuleQuestionMatchFilter {
  const ModuleQuestionMatchFilter({
    this.materia = '',
    this.assunto = '',
    this.tipoMatch = '',
    this.minScore = 0,
    this.limit = 20,
  });

  final String materia;
  final String assunto;
  final String tipoMatch;
  final double minScore;
  final int limit;
}

class QuestionFilter {
  const QuestionFilter({
    this.year,
    this.day,
    this.area = '',
    this.discipline = '',
    this.materia = '',
    this.competency = '',
    this.skill = '',
    this.difficulty = '',
    this.hasImage,
    this.limit = 20,
  });

  final int? year;
  final int? day;
  final String area;
  final String discipline;
  final String materia;
  final String competency;
  final String skill;
  final String difficulty;
  final bool? hasImage;
  final int limit;
}

class QuestionFilterOptions {
  const QuestionFilterOptions({
    this.years = const [],
    this.days = const [],
    this.areas = const [],
    this.disciplines = const [],
    this.materias = const [],
    this.competencies = const [],
    this.skills = const [],
    this.difficulties = const [],
  });

  final List<int> years;
  final List<int> days;
  final List<String> areas;
  final List<String> disciplines;
  final List<String> materias;
  final List<String> competencies;
  final List<String> skills;
  final List<String> difficulties;
}

class QuestionCardItem {
  const QuestionCardItem({
    required this.id,
    required this.year,
    required this.day,
    required this.number,
    required this.variation,
    required this.area,
    required this.discipline,
    required this.materia,
    required this.competency,
    required this.skill,
    required this.difficulty,
    required this.hasImage,
    required this.statement,
    required this.answer,
  });

  final String id;
  final int year;
  final int day;
  final int number;
  final int variation;
  final String area;
  final String discipline;
  final String materia;
  final String competency;
  final String skill;
  final String difficulty;
  final bool hasImage;
  final String statement;
  final String answer;
}

class AttemptRecord {
  const AttemptRecord({
    required this.questionId,
    required this.year,
    required this.day,
    required this.number,
    required this.variation,
    required this.skill,
    required this.competency,
    required this.isCorrect,
    required this.answeredAt,
  });

  final String questionId;
  final int year;
  final int day;
  final int number;
  final int variation;
  final String skill;
  final String competency;
  final bool isCorrect;
  final String answeredAt;
}

class EssaySessionInput {
  const EssaySessionInput({
    required this.themeTitle,
    required this.themeSource,
    required this.generatedPrompt,
    required this.correctionPrompt,
    required this.submittedText,
    required this.submittedPhotoPath,
    required this.iaFeedbackRaw,
    required this.parserMode,
    required this.c1Score,
    required this.c2Score,
    required this.c3Score,
    required this.c4Score,
    required this.c5Score,
    required this.finalScore,
    required this.legibilityWarning,
  });

  final String themeTitle;
  final String themeSource;
  final String generatedPrompt;
  final String correctionPrompt;
  final String submittedText;
  final String submittedPhotoPath;
  final String iaFeedbackRaw;
  final String parserMode;
  final int? c1Score;
  final int? c2Score;
  final int? c3Score;
  final int? c4Score;
  final int? c5Score;
  final int? finalScore;
  final bool legibilityWarning;
}

class EssaySessionRecord {
  const EssaySessionRecord({
    required this.id,
    required this.themeTitle,
    required this.themeSource,
    required this.parserMode,
    required this.legibilityWarning,
    required this.createdAt,
    this.c1Score,
    this.c2Score,
    this.c3Score,
    this.c4Score,
    this.c5Score,
    this.finalScore,
  });

  final int id;
  final String themeTitle;
  final String themeSource;
  final String parserMode;
  final bool legibilityWarning;
  final String createdAt;
  final int? c1Score;
  final int? c2Score;
  final int? c3Score;
  final int? c4Score;
  final int? c5Score;
  final int? finalScore;
}

class EssayScoreSummary {
  const EssayScoreSummary({
    required this.scoredSessionCount,
    required this.averageScore,
    this.bestScore,
    this.latestScore,
  });

  final int scoredSessionCount;
  final double averageScore;
  final int? bestScore;
  final int? latestScore;
}

class StudentProfileInput {
  const StudentProfileInput({
    this.id = '',
    required this.displayName,
    this.targetYear,
    this.studyDaysCsv = '',
    this.hoursPerDay,
    this.focusArea = '',
    this.examDate = '',
    this.plannerContext = '',
    this.plannerSnapshotJson = '',
    this.themeMode = profileThemeModeSystem,
    this.fontScale = profileFontScaleDefault,
  });

  final String id;
  final String displayName;
  final int? targetYear;
  final String studyDaysCsv;
  final double? hoursPerDay;
  final String focusArea;
  final String examDate;
  final String plannerContext;
  final String plannerSnapshotJson;
  final String themeMode;
  final double fontScale;
}

class LessonProgressRecord {
  const LessonProgressRecord({
    required this.lessonId,
    required this.lessonVersion,
    required this.answers,
    required this.submitted,
    required this.score,
    required this.totalQuestions,
    required this.updatedAt,
  });

  final String lessonId;
  final String lessonVersion;
  final Map<String, String> answers;
  final bool submitted;
  final int score;
  final int totalQuestions;
  final DateTime updatedAt;
}

class LessonQuestionAttemptInput {
  const LessonQuestionAttemptInput({
    required this.lessonQuestionId,
    required this.selectedOption,
    required this.isCorrect,
    this.sourceQuestionId = '',
  });

  final String lessonQuestionId;
  final String selectedOption;
  final bool isCorrect;
  final String sourceQuestionId;
}

class LessonVersionAttemptSummary {
  const LessonVersionAttemptSummary({
    required this.lessonVersion,
    required this.attemptCount,
    required this.correctCount,
    required this.outdatedCount,
    required this.lastAttemptedAt,
  });

  final String lessonVersion;
  final int attemptCount;
  final int correctCount;
  final int outdatedCount;
  final DateTime lastAttemptedAt;
}

class StudentProfileRecord {
  const StudentProfileRecord({
    required this.id,
    required this.displayName,
    required this.targetYear,
    required this.studyDaysCsv,
    required this.hoursPerDay,
    required this.focusArea,
    required this.examDate,
    required this.plannerContext,
    required this.plannerSnapshotJson,
    required this.themeMode,
    required this.fontScale,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String displayName;
  final int? targetYear;
  final String studyDaysCsv;
  final double? hoursPerDay;
  final String focusArea;
  final String examDate;
  final String plannerContext;
  final String plannerSnapshotJson;
  final String themeMode;
  final double fontScale;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'target_year': targetYear,
      'study_days_csv': studyDaysCsv,
      'hours_per_day': hoursPerDay,
      'focus_area': focusArea,
      'exam_date': examDate,
      'planner_context': plannerContext,
      'planner_snapshot_json': plannerSnapshotJson,
      'theme_mode': normalizeProfileThemeMode(themeMode),
      'font_scale': normalizeProfileFontScale(fontScale),
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class ProfileImportResult {
  const ProfileImportResult({
    required this.profile,
    required this.sourceSchemaVersion,
    required this.targetSchemaVersion,
    required this.migrated,
  });

  final StudentProfileRecord? profile;
  final int sourceSchemaVersion;
  final int targetSchemaVersion;
  final bool migrated;
}

class LocalDatabase {
  LocalDatabase();

  static const int profileBundleSchemaVersion = 3;

  bool _ffiInitialized = false;
  String? _databasePath;

  Future<Database> open() async {
    _ensureDesktopDriver();
    final dbPath = await databasePath();

    return openDatabase(
      dbPath,
      version: 17,
      onCreate: (db, _) async {
        await _createSchemaV17(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createBookModulesTable(db);
        }
        if (oldVersion < 4) {
          await _ensureBookModulesSchemaV4(db);
        }
        if (oldVersion < 5) {
          await _ensureQuestionsSchemaV5(db);
        }
        if (oldVersion < 6) {
          await _createModuleQuestionMatchesTable(db);
        }
        if (oldVersion < 7) {
          await _createEssaySessionsTable(db);
        }
        if (oldVersion < 8) {
          await _ensureQuestionsSchemaV8(db);
        }
        if (oldVersion < 9) {
          await _ensureQuestionsSchemaV9(db);
        }
        if (oldVersion < 10) {
          await _createStudentProfilesTable(db);
        }
        if (oldVersion < 11) {
          await _ensureStudentProfilesSchemaV11(db);
        }
        if (oldVersion < 12) {
          await _ensureStudentProfilesSchemaV12(db);
        }
        if (oldVersion < 13) {
          await _ensureProgressSchemaV13(db);
        }
        if (oldVersion < 14) {
          await _ensureSkillErrorEvidenceSchemaV14(db);
        }
        if (oldVersion < 15) {
          await _createLessonProgressTable(db);
        }
        if (oldVersion < 16) {
          await _createLessonQuestionAttemptsTable(db);
        }
        if (oldVersion < 17) {
          await _createConceptGraphTables(db);
        }
      },
    );
  }

  Future<String> databasePath() async {
    if (_databasePath != null && _databasePath!.trim().isNotEmpty) {
      return _databasePath!;
    }
    _databasePath = await _resolveDatabasePath();
    return _databasePath!;
  }

  Future<String> _resolveDatabasePath() async {
    if (kIsWeb) {
      return AppConfig.linuxDbFileName;
    }
    if (Platform.isLinux) {
      return _resolveLinuxDatabasePath();
    }
    final supportDir = await getApplicationSupportDirectory();
    return path.join(supportDir.path, AppConfig.linuxDbFileName);
  }

  Future<String> _resolveLinuxDatabasePath() async {
    final customDir = AppConfig.linuxDbDir.trim();
    if (customDir.isNotEmpty) {
      await Directory(customDir).create(recursive: true);
      return path.join(customDir, AppConfig.linuxDbFileName);
    }

    final stableHome = _resolveStableHome(Platform.environment);
    final stableDir = path.join(
      stableHome,
      '.local',
      'share',
      AppConfig.linuxStableDataDirName,
    );
    await Directory(stableDir).create(recursive: true);

    final stableDbPath = path.join(stableDir, AppConfig.linuxDbFileName);
    await _migrateLegacyLinuxDbIfNeeded(stableDbPath);
    return stableDbPath;
  }

  String _resolveStableHome(Map<String, String> environment) {
    final snapRealHome = (environment['SNAP_REAL_HOME'] ?? '').trim();
    if (snapRealHome.isNotEmpty) {
      return snapRealHome;
    }

    final home = (environment['HOME'] ?? '').trim();
    if (home.isEmpty) {
      return Directory.current.path;
    }

    // HOME dentro de Snap costuma vir como /home/<user>/snap/<app>/<rev>.
    final snapHomeMatch = RegExp(
      r'^(/home/[^/]+)/snap/[^/]+/[0-9]+$',
    ).firstMatch(home);
    if (snapHomeMatch != null) {
      return snapHomeMatch.group(1) ?? home;
    }

    return home;
  }

  Future<void> _migrateLegacyLinuxDbIfNeeded(String stableDbPath) async {
    final target = File(stableDbPath);
    if (await target.exists()) {
      return;
    }

    final candidates = <String>[];
    final env = Platform.environment;

    final snapRealHome = (env['SNAP_REAL_HOME'] ?? '').trim();
    if (snapRealHome.isNotEmpty) {
      candidates.add(
        path.join(
          snapRealHome,
          '.local',
          'share',
          'com.example.enem_offline_client',
          AppConfig.linuxDbFileName,
        ),
      );
    }

    final home = (env['HOME'] ?? '').trim();
    if (home.isNotEmpty) {
      candidates.add(
        path.join(
          home,
          '.local',
          'share',
          'com.example.enem_offline_client',
          AppConfig.linuxDbFileName,
        ),
      );
    }

    try {
      final supportDir = await getApplicationSupportDirectory();
      candidates.add(path.join(supportDir.path, AppConfig.linuxDbFileName));
    } catch (_) {
      // Sem ação: fallback por variáveis de ambiente acima.
    }

    final seen = <String>{};
    for (final candidatePath in candidates) {
      if (!seen.add(candidatePath)) {
        continue;
      }
      if (candidatePath == stableDbPath) {
        continue;
      }

      final source = File(candidatePath);
      if (!await source.exists()) {
        continue;
      }

      try {
        await source.copy(stableDbPath);
        return;
      } catch (_) {
        // Tenta próximo candidato.
      }
    }
  }

  Future<void> _createSchemaV17(Database db) async {
    await _createSchemaV16(db);
    await _createConceptGraphTables(db);
  }

  Future<void> _createSchemaV16(Database db) async {
    await _createSchemaV15(db);
    await _createLessonQuestionAttemptsTable(db);
  }

  Future<void> _createSchemaV15(Database db) async {
    await _createSchemaV14(db);
    await _createLessonProgressTable(db);
  }

  Future<void> _createSchemaV14(Database db) async {
    await _createSchemaV13(db);
    await _ensureSkillErrorEvidenceSchemaV14(db);
  }

  Future<void> _createSchemaV13(Database db) async {
    await _createSchemaV12(db);
    await _ensureProgressSchemaV13(db);
  }

  Future<void> _createSchemaV12(Database db) async {
    await _createSchemaV11(db);
    await _ensureStudentProfilesSchemaV12(db);
  }

  Future<void> _createSchemaV11(Database db) async {
    await _createSchemaV10(db);
    await _ensureStudentProfilesSchemaV11(db);
  }

  Future<void> _createSchemaV10(Database db) async {
    await _createSchemaV9(db);
    await _createStudentProfilesTable(db);
  }

  Future<void> _createSchemaV9(Database db) async {
    await _createSchemaV8(db);
    await _ensureQuestionsSchemaV9(db);
  }

  Future<void> _createSchemaV8(Database db) async {
    await _createSchemaV7(db);
    await _ensureQuestionsSchemaV8(db);
  }

  Future<void> _createSchemaV7(Database db) async {
    await _createSchemaV6(db);
    await _createEssaySessionsTable(db);
  }

  Future<void> _createSchemaV6(Database db) async {
    await _createSchemaV5(db);
    await _createModuleQuestionMatchesTable(db);
  }

  Future<void> _createSchemaV5(Database db) async {
    await db.execute('''
      CREATE TABLE app_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE questions (
        id TEXT PRIMARY KEY,
        year INTEGER NOT NULL,
        day INTEGER NOT NULL,
        number INTEGER NOT NULL,
        variation INTEGER NOT NULL DEFAULT 1,
        area TEXT NOT NULL,
        discipline TEXT,
        materia TEXT,
        competency TEXT,
        skill TEXT,
        difficulty TEXT,
        has_image INTEGER NOT NULL DEFAULT 0,
        text_empty INTEGER NOT NULL DEFAULT 0,
        statement TEXT NOT NULL,
        fallback_images TEXT,
        answer TEXT,
        source TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id TEXT NOT NULL,
        is_correct INTEGER NOT NULL,
        answered_at TEXT NOT NULL,
        elapsed_seconds INTEGER,
        answer_source TEXT,
        FOREIGN KEY(question_id) REFERENCES questions(id)
      )
    ''');

    await _createBookModulesTable(db);

    await db.insert(
      'app_meta',
      {'key': 'content_version', 'value': '0'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _createBookModulesTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS book_modules (
        id TEXT PRIMARY KEY,
        volume INTEGER NOT NULL,
        area TEXT,
        materia TEXT,
        modulo INTEGER,
        title TEXT,
        page TEXT,
        skills TEXT,
        skills_raw TEXT,
        competencies TEXT,
        competencies_raw TEXT,
        learning_expectations TEXT,
        learning_expectations_raw TEXT,
        description TEXT,
        source TEXT
      )
    ''');
  }

  Future<void> _ensureProgressSchemaV13(Database db) async {
    final progressColumns = await db.rawQuery("PRAGMA table_info('progress')");
    final progressColumnNames =
        progressColumns.map((row) => (row['name'] ?? '').toString()).toSet();

    if (!progressColumnNames.contains('elapsed_seconds')) {
      await db
          .execute('ALTER TABLE progress ADD COLUMN elapsed_seconds INTEGER');
    }
    if (!progressColumnNames.contains('answer_source')) {
      await db.execute('ALTER TABLE progress ADD COLUMN answer_source TEXT');
    }
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_progress_answered_at
      ON progress (answered_at DESC)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_progress_question_answered
      ON progress (question_id, answered_at DESC)
    ''');
  }

  Future<void> _ensureSkillErrorEvidenceSchemaV14(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS skill_error_evidence (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        skill TEXT NOT NULL,
        signal TEXT NOT NULL,
        evidence_type TEXT NOT NULL,
        evidence_value TEXT NOT NULL,
        error_count INTEGER NOT NULL DEFAULT 0,
        total_count INTEGER NOT NULL DEFAULT 0,
        error_rate REAL NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_skill_error_evidence_skill
      ON skill_error_evidence (skill, updated_at DESC)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_skill_error_evidence_signal
      ON skill_error_evidence (signal, error_rate DESC)
    ''');
  }

  Future<void> _createModuleQuestionMatchesTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS module_question_matches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id TEXT NOT NULL,
        year INTEGER NOT NULL,
        day INTEGER NOT NULL,
        number INTEGER NOT NULL,
        variation INTEGER NOT NULL,
        area TEXT,
        discipline TEXT,
        materia TEXT,
        volume INTEGER,
        modulo INTEGER,
        competencias TEXT,
        habilidades TEXT,
        assuntos_match TEXT,
        score_match REAL,
        tipo_match TEXT,
        confianca TEXT,
        revisado_manual INTEGER NOT NULL DEFAULT 0,
        source TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_module_question_matches_question
      ON module_question_matches (question_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_module_question_matches_module
      ON module_question_matches (materia, volume, modulo)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_module_question_matches_score
      ON module_question_matches (tipo_match, score_match DESC)
    ''');
  }

  Future<void> _createEssaySessionsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS essay_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        theme_title TEXT NOT NULL,
        theme_source TEXT NOT NULL,
        generated_prompt TEXT,
        correction_prompt TEXT,
        submitted_text TEXT,
        submitted_photo_path TEXT,
        ia_feedback_raw TEXT,
        parser_mode TEXT NOT NULL DEFAULT 'livre',
        c1_score INTEGER,
        c2_score INTEGER,
        c3_score INTEGER,
        c4_score INTEGER,
        c5_score INTEGER,
        final_score INTEGER,
        legibility_warning INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_essay_sessions_created_at
      ON essay_sessions (created_at DESC)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_essay_sessions_theme_source
      ON essay_sessions (theme_source, parser_mode)
    ''');
  }

  Future<void> _createLessonProgressTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lesson_progress (
        lesson_id TEXT NOT NULL,
        lesson_version TEXT NOT NULL,
        answers_json TEXT NOT NULL DEFAULT '{}',
        submitted INTEGER NOT NULL DEFAULT 0,
        score INTEGER NOT NULL DEFAULT 0,
        total_questions INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (lesson_id, lesson_version)
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_lesson_progress_updated_at
      ON lesson_progress (updated_at DESC)
    ''');
  }

  Future<void> _createLessonQuestionAttemptsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lesson_question_attempts (
        lesson_id TEXT NOT NULL,
        lesson_version TEXT NOT NULL,
        lesson_question_id TEXT NOT NULL,
        source_question_id TEXT,
        selected_option TEXT NOT NULL,
        is_correct INTEGER NOT NULL DEFAULT 0,
        is_outdated INTEGER NOT NULL DEFAULT 0,
        attempted_at TEXT NOT NULL,
        PRIMARY KEY (lesson_id, lesson_version, lesson_question_id)
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_lesson_question_attempts_lesson
      ON lesson_question_attempts (lesson_id, attempted_at DESC)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_lesson_question_attempts_source
      ON lesson_question_attempts (source_question_id, attempted_at DESC)
    ''');
  }

  Future<void> _createStudentProfilesTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS student_profiles (
        id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        target_year INTEGER,
        study_days_csv TEXT,
        hours_per_day REAL,
        focus_area TEXT,
        exam_date TEXT,
        planner_context TEXT,
        planner_snapshot_json TEXT,
        theme_mode TEXT NOT NULL DEFAULT 'system',
        font_scale REAL NOT NULL DEFAULT 1.0,
        is_active INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_student_profiles_active
      ON student_profiles (is_active DESC, updated_at DESC)
    ''');
  }

  Future<void> _createConceptGraphTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS concepts (
        id TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        area TEXT,
        difficulty TEXT,
        source TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS question_concepts (
        question_id TEXT NOT NULL,
        concept_id TEXT NOT NULL,
        weight REAL NOT NULL DEFAULT 0,
        source TEXT,
        PRIMARY KEY (question_id, concept_id),
        FOREIGN KEY(question_id) REFERENCES questions(id),
        FOREIGN KEY(concept_id) REFERENCES concepts(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS concept_dependencies (
        concept_id TEXT NOT NULL,
        depends_on TEXT NOT NULL,
        strength REAL NOT NULL DEFAULT 0,
        source TEXT,
        PRIMARY KEY (concept_id, depends_on),
        FOREIGN KEY(concept_id) REFERENCES concepts(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS concept_priority_weights (
        concept_id TEXT PRIMARY KEY,
        base_weight REAL NOT NULL DEFAULT 1,
        reason TEXT,
        source TEXT,
        FOREIGN KEY(concept_id) REFERENCES concepts(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS concept_mastery (
        profile_id TEXT NOT NULL,
        concept_id TEXT NOT NULL,
        mastery REAL NOT NULL DEFAULT 0.5,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (profile_id, concept_id),
        FOREIGN KEY(profile_id) REFERENCES student_profiles(id),
        FOREIGN KEY(concept_id) REFERENCES concepts(id)
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_question_concepts_question
      ON question_concepts (question_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_question_concepts_concept
      ON question_concepts (concept_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_concept_dependencies_concept
      ON concept_dependencies (concept_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_concept_priority_weights_weight
      ON concept_priority_weights (base_weight DESC)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_concept_mastery_profile
      ON concept_mastery (profile_id, updated_at DESC)
    ''');
  }

  Future<void> _ensureStudentProfilesSchemaV11(Database db) async {
    final columns = await db.rawQuery("PRAGMA table_info('student_profiles')");
    final names = columns
        .map((row) => (row['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toSet();

    if (!names.contains('planner_snapshot_json')) {
      await db.execute(
        'ALTER TABLE student_profiles ADD COLUMN planner_snapshot_json TEXT',
      );
    }
  }

  Future<void> _ensureStudentProfilesSchemaV12(Database db) async {
    final columns = await db.rawQuery("PRAGMA table_info('student_profiles')");
    final names = columns
        .map((row) => (row['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toSet();

    if (!names.contains('theme_mode')) {
      await db.execute(
        "ALTER TABLE student_profiles ADD COLUMN theme_mode TEXT NOT NULL DEFAULT 'system'",
      );
    }
    if (!names.contains('font_scale')) {
      await db.execute(
        'ALTER TABLE student_profiles ADD COLUMN font_scale REAL NOT NULL DEFAULT 1.0',
      );
    }
  }

  Future<void> _ensureBookModulesSchemaV4(Database db) async {
    final columns = await db.rawQuery("PRAGMA table_info('book_modules')");
    final names = columns
        .map((row) => (row['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toSet();

    if (!names.contains('competencies')) {
      await db.execute('ALTER TABLE book_modules ADD COLUMN competencies TEXT');
    }
    if (!names.contains('competencies_raw')) {
      await db.execute(
        'ALTER TABLE book_modules ADD COLUMN competencies_raw TEXT',
      );
    }
    if (!names.contains('learning_expectations')) {
      await db.execute(
        'ALTER TABLE book_modules ADD COLUMN learning_expectations TEXT',
      );
    }
    if (!names.contains('learning_expectations_raw')) {
      await db.execute(
        'ALTER TABLE book_modules ADD COLUMN learning_expectations_raw TEXT',
      );
    }
    if (!names.contains('description')) {
      await db.execute('ALTER TABLE book_modules ADD COLUMN description TEXT');
    }
  }

  Future<void> _ensureQuestionsSchemaV5(Database db) async {
    final columns = await db.rawQuery("PRAGMA table_info('questions')");
    final names = columns
        .map((row) => (row['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toSet();

    if (!names.contains('fallback_images')) {
      await db.execute('ALTER TABLE questions ADD COLUMN fallback_images TEXT');
    }
  }

  Future<void> _ensureQuestionsSchemaV8(Database db) async {
    final columns = await db.rawQuery("PRAGMA table_info('questions')");
    final names = columns
        .map((row) => (row['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toSet();

    if (!names.contains('variation')) {
      await db.execute(
        'ALTER TABLE questions ADD COLUMN variation INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (!names.contains('materia')) {
      await db.execute('ALTER TABLE questions ADD COLUMN materia TEXT');
    }
    if (!names.contains('competency')) {
      await db.execute('ALTER TABLE questions ADD COLUMN competency TEXT');
    }
    if (!names.contains('has_image')) {
      await db.execute(
        'ALTER TABLE questions ADD COLUMN has_image INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (!names.contains('text_empty')) {
      await db.execute(
        'ALTER TABLE questions ADD COLUMN text_empty INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (!names.contains('fallback_images')) {
      await db.execute('ALTER TABLE questions ADD COLUMN fallback_images TEXT');
    }

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_questions_base
      ON questions (year, day, number, variation)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_questions_area
      ON questions (area, discipline, materia)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_questions_skill_competency
      ON questions (skill, competency)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_questions_has_image
      ON questions (has_image)
    ''');
  }

  Future<void> _ensureQuestionsSchemaV9(Database db) async {
    final columns = await db.rawQuery("PRAGMA table_info('questions')");
    final names = columns
        .map((row) => (row['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toSet();

    if (!names.contains('difficulty')) {
      await db.execute('ALTER TABLE questions ADD COLUMN difficulty TEXT');
    }

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_questions_difficulty
      ON questions (difficulty)
    ''');
  }

  void _ensureDesktopDriver() {
    if (kIsWeb) {
      if (_ffiInitialized) {
        return;
      }
      databaseFactory = databaseFactoryFfiWeb;
      _ffiInitialized = true;
      return;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      return;
    }
    if (_ffiInitialized) {
      return;
    }
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _ffiInitialized = true;
  }

  int _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  double _toDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    final normalized = '${value ?? ''}'.trim().replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  bool _toBool(Object? value) {
    final normalized = '${value ?? ''}'.trim().toLowerCase();
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'sim' ||
        normalized == 'yes' ||
        normalized == 'y';
  }

  int? _toOptionalInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    final parsed = int.tryParse('$value'.trim());
    return parsed;
  }

  double? _toOptionalDouble(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    final normalized = '$value'.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  String _normalizeSkillToken(String rawValue) {
    final token = rawValue.trim().toUpperCase().replaceAll(' ', '');
    if (token.isEmpty) {
      return '';
    }
    final composite = RegExp(r'^C(\d+)-H(\d+)$').firstMatch(token);
    if (composite != null) {
      return 'H${int.parse(composite.group(2)!)}';
    }
    if (token.startsWith('H') && int.tryParse(token.substring(1)) != null) {
      return 'H${int.parse(token.substring(1))}';
    }

    const marker = '-H';
    if (token.contains(marker)) {
      final tail = token.split(marker).last;
      final digits = tail.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        return 'H${int.parse(digits)}';
      }
    }

    return '';
  }

  String _normalizeCompetencyToken(String rawValue) {
    final token = rawValue.trim().toUpperCase().replaceAll(' ', '');
    if (token.isEmpty) {
      return '';
    }

    final composite = RegExp(r'^C(\d+)-H(\d+)$').firstMatch(token);
    if (composite != null) {
      return 'C${int.parse(composite.group(1)!)}';
    }
    if (token.startsWith('C') && int.tryParse(token.substring(1)) != null) {
      return 'C${int.parse(token.substring(1))}';
    }

    final prefixed = RegExp(r'^C(\d+)(?:[-:.].*)?$').firstMatch(token);
    if (prefixed != null) {
      return 'C${int.parse(prefixed.group(1)!)}';
    }
    return '';
  }

  String _normalizeDifficultyToken(String rawValue) {
    final token = rawValue.trim().toLowerCase();
    if (token.isEmpty) {
      return '';
    }

    final compact = token.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (compact.isEmpty) {
      return '';
    }

    if (compact == 'facil' || compact == 'easy' || compact == 'f') {
      return 'facil';
    }
    if (compact == 'media' ||
        compact == 'medio' ||
        compact == 'medium' ||
        compact == 'm') {
      return 'media';
    }
    if (compact == 'dificil' || compact == 'hard' || compact == 'd') {
      return 'dificil';
    }
    return '';
  }

  String _normalizeConceptId(String rawValue) {
    final normalized = rawValue
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_:-]'), '');
    if (normalized.isEmpty) {
      return '';
    }
    return normalized;
  }

  String _normalizeTopicTag(String rawValue) {
    final normalized = rawValue.trim().toLowerCase();
    if (normalized.isEmpty) {
      return '';
    }

    final compact = normalized.replaceAll(RegExp(r'\s+'), ' ');
    if (compact.length < 3) {
      return '';
    }
    if (compact == '-' || compact == 'na' || compact == 'n/a') {
      return '';
    }
    return compact;
  }

  Future<bool> _tableExists(Database db, String tableName) async {
    final normalized = tableName.trim();
    if (normalized.isEmpty) {
      return false;
    }
    final rows = await db.rawQuery(
      '''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table' AND name = ?
      LIMIT 1
      ''',
      [normalized],
    );
    return rows.isNotEmpty;
  }

  Future<bool> _hasConceptGraphTables(Database db) async {
    const requiredTables = [
      'concepts',
      'question_concepts',
      'concept_dependencies',
      'concept_priority_weights',
      'concept_mastery',
    ];
    for (final table in requiredTables) {
      if (!await _tableExists(db, table)) {
        return false;
      }
    }
    return true;
  }

  QuestionCardItem? _questionCardFromRow(Map<String, Object?> row) {
    final question = QuestionCardItem(
      id: (row['id'] ?? '').toString(),
      year: _toInt(row['year']),
      day: _toInt(row['day']),
      number: _toInt(row['number']),
      variation: _toInt(row['variation']) <= 0 ? 1 : _toInt(row['variation']),
      area: (row['area'] ?? '').toString(),
      discipline: (row['discipline'] ?? '').toString(),
      materia: (row['materia'] ?? '').toString(),
      competency: (row['competency'] ?? '').toString(),
      skill: (row['skill'] ?? '').toString(),
      difficulty: (row['difficulty'] ?? '').toString(),
      hasImage: _toBool(row['has_image']),
      statement: (row['statement'] ?? '').toString(),
      answer: (row['answer'] ?? '').toString(),
    );
    if (question.id.isEmpty ||
        question.year <= 0 ||
        question.day <= 0 ||
        question.number <= 0) {
      return null;
    }
    return question;
  }

  double _confidenceFromAttempts(int attempts) {
    if (attempts <= 0) {
      return 0;
    }
    final raw = math.log(1 + attempts);
    final normalizer = math.log(1 + 20);
    if (normalizer <= 0) {
      return 0;
    }
    final normalized = raw / normalizer;
    if (normalized < 0) {
      return 0;
    }
    if (normalized > 1) {
      return 1;
    }
    return normalized;
  }

  String _bandFromAccuracy(double accuracy) {
    if (accuracy < 0.55) {
      return 'foco';
    }
    if (accuracy <= 0.75) {
      return 'manutencao';
    }
    return 'forte';
  }

  List<String> _extractSkills(Object? rawSkills, String rawSkillsText) {
    final skills = <String>[];
    final seen = <String>{};

    void addToken(String token) {
      final normalized = _normalizeSkillToken(token);
      if (normalized.isEmpty || seen.contains(normalized)) {
        return;
      }
      seen.add(normalized);
      skills.add(normalized);
    }

    if (rawSkills is List) {
      for (final item in rawSkills) {
        addToken('$item');
      }
    }

    if (skills.isEmpty && rawSkillsText.trim().isNotEmpty) {
      final unified = rawSkillsText.replaceAll(';', ',');
      for (final chunk in unified.split(',')) {
        addToken(chunk);
      }
    }

    return skills;
  }

  String _buildSkillsBlob(List<String> skills) {
    if (skills.isEmpty) {
      return ';';
    }
    return ';${skills.join(';')};';
  }

  List<String> _extractCompetencies(
    Object? rawCompetencies,
    String rawCompetenciesText,
    String rawSkillsText,
  ) {
    final competencies = <String>[];
    final seen = <String>{};

    void addToken(String token) {
      final normalized = _normalizeCompetencyToken(token);
      if (normalized.isEmpty || seen.contains(normalized)) {
        return;
      }
      seen.add(normalized);
      competencies.add(normalized);
    }

    if (rawCompetencies is List) {
      for (final item in rawCompetencies) {
        addToken('$item');
      }
    }

    if (competencies.isEmpty && rawCompetenciesText.trim().isNotEmpty) {
      final unified = rawCompetenciesText.replaceAll(';', ',');
      for (final chunk in unified.split(',')) {
        addToken(chunk);
      }
    }

    if (competencies.isEmpty && rawSkillsText.trim().isNotEmpty) {
      final unified = rawSkillsText.replaceAll(';', ',');
      for (final chunk in unified.split(',')) {
        addToken(chunk);
      }
    }

    return competencies;
  }

  String _buildCompetenciesBlob(List<String> competencies) {
    if (competencies.isEmpty) {
      return ';';
    }
    return ';${competencies.join(';')};';
  }

  List<String> _extractLearningExpectations(
    Object? rawLearningExpectations,
    String rawLearningExpectationsText,
    String fallbackDescription,
  ) {
    final expectations = <String>[];
    final seen = <String>{};

    void addToken(String token) {
      final normalized = token.trim();
      if (normalized.isEmpty) {
        return;
      }
      final dedupeKey = normalized.toLowerCase();
      if (seen.contains(dedupeKey)) {
        return;
      }
      seen.add(dedupeKey);
      expectations.add(normalized);
    }

    void parseAndAdd(String text) {
      final unified = text
          .replaceAll('\\n', '\n')
          .replaceAll('\r', '\n')
          .replaceAll(';', '\n');
      for (final chunk in unified.split('\n')) {
        final cleaned =
            chunk.replaceFirst(RegExp(r'^\s*(?:[-*•]+|\d+[.)])\s*'), '').trim();
        if (cleaned.isEmpty) {
          continue;
        }
        addToken(cleaned);
      }
    }

    if (rawLearningExpectations is List) {
      for (final item in rawLearningExpectations) {
        addToken('$item');
      }
    }

    if (expectations.isEmpty && rawLearningExpectationsText.trim().isNotEmpty) {
      parseAndAdd(rawLearningExpectationsText);
    }

    if (expectations.isEmpty && fallbackDescription.trim().isNotEmpty) {
      parseAndAdd(fallbackDescription);
    }

    return expectations;
  }

  List<String> _extractFallbackImagePaths(Object? rawPaths) {
    final result = <String>[];
    final seen = <String>{};

    void addToken(String token) {
      final cleaned = token.trim().replaceAll('\\', '/');
      if (cleaned.isEmpty || seen.contains(cleaned)) {
        return;
      }
      seen.add(cleaned);
      result.add(cleaned);
    }

    if (rawPaths is List) {
      for (final item in rawPaths) {
        addToken('$item');
      }
      return result;
    }

    final text = '${rawPaths ?? ''}'.trim();
    if (text.isEmpty) {
      return result;
    }
    for (final chunk in text.split(';')) {
      addToken(chunk);
    }
    return result;
  }

  String _buildFallbackImagesBlob(List<String> paths) {
    if (paths.isEmpty) {
      return '';
    }
    return ';${paths.join(';')};';
  }

  String _buildLearningExpectationsBlob(List<String> expectations) {
    if (expectations.isEmpty) {
      return ';';
    }
    return ';${expectations.join(';')};';
  }

  Future<int> countQuestions(Database db) async {
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM questions');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countBookModules(Database db) async {
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM book_modules');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countModuleQuestionMatches(Database db) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM module_question_matches',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countEssaySessions(Database db) async {
    final result =
        await db.rawQuery('SELECT COUNT(*) AS c FROM essay_sessions');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countAttempts(Database db) async {
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM progress');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countStudentProfiles(Database db) async {
    final result =
        await db.rawQuery('SELECT COUNT(*) AS c FROM student_profiles');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  String _buildProfileId(String displayName) {
    final seed = displayName.trim().toLowerCase();
    final slug = seed.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(
          RegExp(r'^_+|_+$'),
          '',
        );
    final prefix = slug.isEmpty ? 'perfil' : slug;
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}';
  }

  StudentProfileRecord _profileFromRow(Map<String, Object?> row) {
    return StudentProfileRecord(
      id: (row['id'] ?? '').toString(),
      displayName: (row['display_name'] ?? '').toString(),
      targetYear: _toOptionalInt(row['target_year']),
      studyDaysCsv: (row['study_days_csv'] ?? '').toString(),
      hoursPerDay: _toOptionalDouble(row['hours_per_day']),
      focusArea: (row['focus_area'] ?? '').toString(),
      examDate: (row['exam_date'] ?? '').toString(),
      plannerContext: (row['planner_context'] ?? '').toString(),
      plannerSnapshotJson: (row['planner_snapshot_json'] ?? '').toString(),
      themeMode:
          normalizeProfileThemeMode((row['theme_mode'] ?? '').toString()),
      fontScale:
          normalizeProfileFontScale(_toOptionalDouble(row['font_scale'])),
      isActive: _toBool(row['is_active']),
      createdAt: (row['created_at'] ?? '').toString(),
      updatedAt: (row['updated_at'] ?? '').toString(),
    );
  }

  Future<List<StudentProfileRecord>> loadStudentProfiles(Database db) async {
    final rows = await db.query(
      'student_profiles',
      orderBy:
          'is_active DESC, updated_at DESC, display_name COLLATE NOCASE ASC',
    );
    return rows
        .map(_profileFromRow)
        .where((profile) => profile.id.isNotEmpty)
        .toList();
  }

  Future<StudentProfileRecord?> loadActiveStudentProfile(Database db) async {
    final rows = await db.query(
      'student_profiles',
      where: 'is_active = 1',
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _profileFromRow(rows.first);
  }

  Future<StudentProfileRecord> ensureDefaultStudentProfile(
    Database db, {
    String defaultName = 'Perfil principal',
  }) async {
    final active = await loadActiveStudentProfile(db);
    if (active != null) {
      return active;
    }

    final profiles = await loadStudentProfiles(db);
    if (profiles.isNotEmpty) {
      final first = profiles.first;
      await setActiveStudentProfile(db, first.id);
      return first;
    }

    final profile = StudentProfileInput(
      id: _buildProfileId(defaultName),
      displayName: defaultName,
    );
    await upsertStudentProfile(db, profile, makeActive: true);
    return (await loadActiveStudentProfile(db))!;
  }

  Future<void> upsertStudentProfile(
    Database db,
    StudentProfileInput input, {
    bool makeActive = true,
  }) async {
    final displayName = input.displayName.trim();
    if (displayName.isEmpty) {
      return;
    }
    final profileId = input.id.trim().isEmpty
        ? _buildProfileId(displayName)
        : input.id.trim();
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      if (makeActive) {
        await txn.update('student_profiles', {'is_active': 0});
      }

      final existing = await txn.query(
        'student_profiles',
        columns: ['created_at'],
        where: 'id = ?',
        whereArgs: [profileId],
        limit: 1,
      );
      final createdAt = existing.isEmpty
          ? now
          : (existing.first['created_at'] ?? '').toString().trim().isEmpty
              ? now
              : (existing.first['created_at'] ?? '').toString();

      await txn.insert(
        'student_profiles',
        {
          'id': profileId,
          'display_name': displayName,
          'target_year': input.targetYear,
          'study_days_csv': input.studyDaysCsv.trim(),
          'hours_per_day': input.hoursPerDay,
          'focus_area': input.focusArea.trim(),
          'exam_date': input.examDate.trim(),
          'planner_context': input.plannerContext.trim(),
          'planner_snapshot_json': input.plannerSnapshotJson.trim(),
          'theme_mode': normalizeProfileThemeMode(input.themeMode),
          'font_scale': normalizeProfileFontScale(input.fontScale),
          'is_active': makeActive ? 1 : 0,
          'created_at': createdAt,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> setActiveStudentProfile(Database db, String profileId) async {
    final normalizedId = profileId.trim();
    if (normalizedId.isEmpty) {
      return;
    }
    await db.transaction((txn) async {
      await txn.update('student_profiles', {'is_active': 0});
      await txn.update(
        'student_profiles',
        {
          'is_active': 1,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [normalizedId],
      );
    });
  }

  Future<Map<String, dynamic>> exportStudentProfileBundle(
    Database db, {
    required String profileId,
  }) async {
    final normalizedId = profileId.trim();
    if (normalizedId.isEmpty) {
      return const {};
    }
    final rows = await db.query(
      'student_profiles',
      where: 'id = ?',
      whereArgs: [normalizedId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return const {};
    }
    final profile = _profileFromRow(rows.first);
    final attempts = await countAttempts(db);
    final essays = await countEssaySessions(db);
    final accuracy = await globalAccuracy(db);
    final contentVersion = await getContentVersion(db);

    return {
      'schema_version': profileBundleSchemaVersion,
      'bundle_type': 'student_profile',
      'exported_at': DateTime.now().toIso8601String(),
      'profile': profile.toMap(),
      'snapshot': {
        'content_version': contentVersion,
        'attempt_count': attempts,
        'essay_session_count': essays,
        'global_accuracy': accuracy,
      },
    };
  }

  Future<ProfileImportResult> importStudentProfileBundle(
    Database db, {
    required Map<String, dynamic> payload,
    bool makeActive = true,
  }) async {
    final sourceVersion = _toInt(payload['schema_version']);
    if (sourceVersion <= 0) {
      throw const FormatException(
          'Arquivo de perfil sem schema_version válido.');
    }
    if (sourceVersion > profileBundleSchemaVersion) {
      throw FormatException(
        'schema_version $sourceVersion não suportado nesta versão do app.',
      );
    }

    final normalizedPayload = sourceVersion == 1
        ? <String, dynamic>{
            ...payload,
            'schema_version': profileBundleSchemaVersion,
            'bundle_type': 'student_profile',
          }
        : payload;
    final migrated = sourceVersion < profileBundleSchemaVersion;

    final bundleType =
        (normalizedPayload['bundle_type'] ?? 'student_profile').toString();
    if (bundleType != 'student_profile') {
      throw FormatException('bundle_type inválido: $bundleType');
    }

    final rawProfile = normalizedPayload['profile'];
    if (rawProfile is! Map<String, dynamic>) {
      return ProfileImportResult(
        profile: null,
        sourceSchemaVersion: sourceVersion,
        targetSchemaVersion: profileBundleSchemaVersion,
        migrated: migrated,
      );
    }

    final displayName = (rawProfile['display_name'] ?? '').toString().trim();
    if (displayName.isEmpty) {
      return ProfileImportResult(
        profile: null,
        sourceSchemaVersion: sourceVersion,
        targetSchemaVersion: profileBundleSchemaVersion,
        migrated: migrated,
      );
    }

    final rawId = (rawProfile['id'] ?? '').toString().trim();
    final input = StudentProfileInput(
      id: rawId.isEmpty ? _buildProfileId(displayName) : rawId,
      displayName: displayName,
      targetYear: _toOptionalInt(rawProfile['target_year']),
      studyDaysCsv: (rawProfile['study_days_csv'] ?? '').toString(),
      hoursPerDay: _toOptionalDouble(rawProfile['hours_per_day']),
      focusArea: (rawProfile['focus_area'] ?? '').toString(),
      examDate: (rawProfile['exam_date'] ?? '').toString(),
      plannerContext: (rawProfile['planner_context'] ?? '').toString(),
      plannerSnapshotJson:
          (rawProfile['planner_snapshot_json'] ?? '').toString(),
      themeMode: normalizeProfileThemeMode(
          (rawProfile['theme_mode'] ?? '').toString()),
      fontScale: normalizeProfileFontScale(
        _toOptionalDouble(rawProfile['font_scale']),
      ),
    );

    await upsertStudentProfile(db, input, makeActive: makeActive);

    final rows = await db.query(
      'student_profiles',
      where: 'id = ?',
      whereArgs: [input.id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return ProfileImportResult(
        profile: null,
        sourceSchemaVersion: sourceVersion,
        targetSchemaVersion: profileBundleSchemaVersion,
        migrated: migrated,
      );
    }
    return ProfileImportResult(
      profile: _profileFromRow(rows.first),
      sourceSchemaVersion: sourceVersion,
      targetSchemaVersion: profileBundleSchemaVersion,
      migrated: migrated,
    );
  }

  Future<List<AttemptRecord>> loadRecentAttempts(
    Database db, {
    int limit = 10,
  }) async {
    final safeLimit = limit <= 0 ? 10 : limit.clamp(1, 200);
    final rows = await db.rawQuery(
      '''
      SELECT
        p.question_id AS question_id,
        q.year AS year,
        q.day AS day,
        q.number AS number,
        COALESCE(q.variation, 1) AS variation,
        COALESCE(q.skill, '') AS skill,
        COALESCE(q.competency, '') AS competency,
        p.is_correct AS is_correct,
        p.answered_at AS answered_at
      FROM progress p
      LEFT JOIN questions q ON q.id = p.question_id
      ORDER BY p.answered_at DESC, p.id DESC
      LIMIT ?
      ''',
      [safeLimit],
    );

    return rows
        .map(
          (row) => AttemptRecord(
            questionId: (row['question_id'] ?? '').toString(),
            year: _toInt(row['year']),
            day: _toInt(row['day']),
            number: _toInt(row['number']),
            variation:
                _toInt(row['variation']) <= 0 ? 1 : _toInt(row['variation']),
            skill: (row['skill'] ?? '').toString(),
            competency: (row['competency'] ?? '').toString(),
            isCorrect: _toBool(row['is_correct']),
            answeredAt: (row['answered_at'] ?? '').toString(),
          ),
        )
        .where((item) => item.questionId.isNotEmpty)
        .toList();
  }

  Future<QuestionFilterOptions> loadQuestionFilterOptions(Database db) async {
    final yearRows = await db.rawQuery('''
      SELECT DISTINCT year AS value
      FROM questions
      WHERE year > 0
      ORDER BY year DESC
    ''');
    final dayRows = await db.rawQuery('''
      SELECT DISTINCT day AS value
      FROM questions
      WHERE day > 0
      ORDER BY day ASC
    ''');
    final areaRows = await db.rawQuery('''
      SELECT DISTINCT TRIM(area) AS value
      FROM questions
      WHERE TRIM(COALESCE(area, '')) <> ''
      ORDER BY value COLLATE NOCASE
    ''');
    final disciplineRows = await db.rawQuery('''
      SELECT DISTINCT TRIM(discipline) AS value
      FROM questions
      WHERE TRIM(COALESCE(discipline, '')) <> ''
      ORDER BY value COLLATE NOCASE
    ''');
    final materiaRows = await db.rawQuery('''
      SELECT value
      FROM (
        SELECT DISTINCT TRIM(materia) AS value
        FROM questions
        WHERE TRIM(COALESCE(materia, '')) <> ''
        UNION
        SELECT DISTINCT TRIM(materia) AS value
        FROM module_question_matches
        WHERE TRIM(COALESCE(materia, '')) <> ''
      )
      ORDER BY value COLLATE NOCASE
    ''');
    final competencyRows = await db.rawQuery('''
      SELECT DISTINCT TRIM(competency) AS value
      FROM questions
      WHERE TRIM(COALESCE(competency, '')) <> ''
      ORDER BY value COLLATE NOCASE
    ''');
    final skillRows = await db.rawQuery('''
      SELECT DISTINCT TRIM(skill) AS value
      FROM questions
      WHERE TRIM(COALESCE(skill, '')) <> ''
      ORDER BY value COLLATE NOCASE
    ''');
    final difficultyRows = await db.rawQuery('''
      SELECT DISTINCT TRIM(difficulty) AS value
      FROM questions
      WHERE TRIM(COALESCE(difficulty, '')) <> ''
      ORDER BY value COLLATE NOCASE
    ''');

    List<String> toStringList(List<Map<String, Object?>> rows) {
      final seen = <String>{};
      final values = <String>[];
      for (final row in rows) {
        final value = (row['value'] ?? '').toString().trim();
        if (value.isEmpty || !seen.add(value)) {
          continue;
        }
        values.add(value);
      }
      return values;
    }

    List<int> toIntList(List<Map<String, Object?>> rows) {
      final seen = <int>{};
      final values = <int>[];
      for (final row in rows) {
        final value = _toInt(row['value']);
        if (value <= 0 || !seen.add(value)) {
          continue;
        }
        values.add(value);
      }
      return values;
    }

    return QuestionFilterOptions(
      years: toIntList(yearRows),
      days: toIntList(dayRows),
      areas: toStringList(areaRows),
      disciplines: toStringList(disciplineRows),
      materias: toStringList(materiaRows),
      competencies: toStringList(competencyRows),
      skills: toStringList(skillRows),
      difficulties: toStringList(difficultyRows),
    );
  }

  Future<List<QuestionCardItem>> searchQuestions(
    Database db, {
    required QuestionFilter filter,
  }) async {
    final whereClauses = <String>[];
    final args = <Object>[];

    if (filter.year != null && filter.year! > 0) {
      whereClauses.add('q.year = ?');
      args.add(filter.year!);
    }
    if (filter.day != null && filter.day! > 0) {
      whereClauses.add('q.day = ?');
      args.add(filter.day!);
    }

    final area = filter.area.trim();
    if (area.isNotEmpty) {
      whereClauses.add('LOWER(COALESCE(q.area, \'\')) = LOWER(?)');
      args.add(area);
    }

    final discipline = filter.discipline.trim();
    if (discipline.isNotEmpty) {
      whereClauses.add('LOWER(COALESCE(q.discipline, \'\')) = LOWER(?)');
      args.add(discipline);
    }

    final materia = filter.materia.trim();
    if (materia.isNotEmpty) {
      whereClauses.add('''
        (
          LOWER(COALESCE(q.materia, q.discipline, '')) = LOWER(?)
          OR EXISTS (
            SELECT 1
            FROM module_question_matches mm
            WHERE mm.question_id = q.id
              AND LOWER(COALESCE(mm.materia, '')) = LOWER(?)
          )
        )
      ''');
      args.add(materia);
      args.add(materia);
    }

    final competency = _normalizeCompetencyToken(filter.competency);
    if (competency.isNotEmpty) {
      whereClauses.add('''
        (
          LOWER(COALESCE(q.competency, '')) = LOWER(?)
          OR EXISTS (
            SELECT 1
            FROM module_question_matches mm
            WHERE mm.question_id = q.id
              AND LOWER(COALESCE(mm.competencias, '')) LIKE ?
          )
        )
      ''');
      args.add(competency);
      args.add('%${competency.toLowerCase()}%');
    }

    final skill = _normalizeSkillToken(filter.skill);
    if (skill.isNotEmpty) {
      whereClauses.add('''
        (
          LOWER(COALESCE(q.skill, '')) = LOWER(?)
          OR EXISTS (
            SELECT 1
            FROM module_question_matches mm
            WHERE mm.question_id = q.id
              AND LOWER(COALESCE(mm.habilidades, '')) LIKE ?
          )
        )
      ''');
      args.add(skill);
      args.add('%${skill.toLowerCase()}%');
    }

    final difficulty = _normalizeDifficultyToken(filter.difficulty);
    if (difficulty.isNotEmpty) {
      whereClauses.add('LOWER(COALESCE(q.difficulty, \'\')) = LOWER(?)');
      args.add(difficulty);
    }

    if (filter.hasImage != null) {
      if (filter.hasImage == true) {
        whereClauses.add(
            '(COALESCE(q.has_image, 0) = 1 OR COALESCE(q.fallback_images, \'\') <> \'\')');
      } else {
        whereClauses.add(
            '(COALESCE(q.has_image, 0) = 0 AND COALESCE(q.fallback_images, \'\') = \'\')');
      }
    }

    final sqlBuffer = StringBuffer()
      ..writeln('SELECT')
      ..writeln('  q.id AS id,')
      ..writeln('  q.year AS year,')
      ..writeln('  q.day AS day,')
      ..writeln('  q.number AS number,')
      ..writeln('  COALESCE(q.variation, 1) AS variation,')
      ..writeln("  COALESCE(q.area, '') AS area,")
      ..writeln("  COALESCE(q.discipline, '') AS discipline,")
      ..writeln(
        "  COALESCE(NULLIF(q.materia, ''), NULLIF(mq.materias, ''), COALESCE(q.discipline, '')) AS materia,",
      )
      ..writeln("  COALESCE(q.competency, '') AS competency,")
      ..writeln("  COALESCE(q.skill, '') AS skill,")
      ..writeln("  COALESCE(q.difficulty, '') AS difficulty,")
      ..writeln(
        "  CASE WHEN COALESCE(q.has_image, 0) = 1 OR COALESCE(q.fallback_images, '') <> '' THEN 1 ELSE 0 END AS has_image,",
      )
      ..writeln("  COALESCE(q.statement, '') AS statement,")
      ..writeln("  COALESCE(q.answer, '') AS answer")
      ..writeln('FROM questions q')
      ..writeln('LEFT JOIN (')
      ..writeln('  SELECT')
      ..writeln('    question_id,')
      ..writeln('    GROUP_CONCAT(DISTINCT TRIM(materia)) AS materias')
      ..writeln('  FROM module_question_matches')
      ..writeln("  WHERE TRIM(COALESCE(materia, '')) <> ''")
      ..writeln('  GROUP BY question_id')
      ..writeln(') mq ON mq.question_id = q.id');

    if (whereClauses.isNotEmpty) {
      sqlBuffer.writeln('WHERE ${whereClauses.join(' AND ')}');
    }

    sqlBuffer
        .writeln('ORDER BY q.year DESC, q.day ASC, q.number ASC, q.id ASC');
    sqlBuffer.writeln('LIMIT ?');

    final safeLimit = filter.limit <= 0 ? 20 : filter.limit.clamp(1, 200);
    args.add(safeLimit);

    final rows = await db.rawQuery(sqlBuffer.toString(), args);
    return rows
        .map(
          (row) => QuestionCardItem(
            id: (row['id'] ?? '').toString(),
            year: _toInt(row['year']),
            day: _toInt(row['day']),
            number: _toInt(row['number']),
            variation:
                _toInt(row['variation']) <= 0 ? 1 : _toInt(row['variation']),
            area: (row['area'] ?? '').toString(),
            discipline: (row['discipline'] ?? '').toString(),
            materia: (row['materia'] ?? '').toString(),
            competency: (row['competency'] ?? '').toString(),
            skill: (row['skill'] ?? '').toString(),
            difficulty: (row['difficulty'] ?? '').toString(),
            hasImage: _toBool(row['has_image']),
            statement: (row['statement'] ?? '').toString(),
            answer: (row['answer'] ?? '').toString(),
          ),
        )
        .where(
          (item) =>
              item.id.isNotEmpty &&
              item.year > 0 &&
              item.day > 0 &&
              item.number > 0,
        )
        .toList();
  }

  Future<void> insertEssaySession(
    Database db, {
    required EssaySessionInput input,
  }) async {
    final now = DateTime.now().toIso8601String();
    final normalizedTheme = input.themeTitle.trim().isEmpty
        ? 'Tema não informado'
        : input.themeTitle.trim();
    final normalizedThemeSource =
        input.themeSource.trim().isEmpty ? 'ia' : input.themeSource.trim();
    final normalizedParserMode =
        input.parserMode.trim().isEmpty ? 'livre' : input.parserMode.trim();

    await db.insert(
      'essay_sessions',
      {
        'theme_title': normalizedTheme,
        'theme_source': normalizedThemeSource,
        'generated_prompt': input.generatedPrompt.trim(),
        'correction_prompt': input.correctionPrompt.trim(),
        'submitted_text': input.submittedText.trim(),
        'submitted_photo_path': input.submittedPhotoPath.trim(),
        'ia_feedback_raw': input.iaFeedbackRaw,
        'parser_mode': normalizedParserMode,
        'c1_score': input.c1Score,
        'c2_score': input.c2Score,
        'c3_score': input.c3Score,
        'c4_score': input.c4Score,
        'c5_score': input.c5Score,
        'final_score': input.finalScore,
        'legibility_warning': input.legibilityWarning ? 1 : 0,
        'created_at': now,
        'updated_at': now,
      },
    );
  }

  Future<List<EssaySessionRecord>> loadRecentEssaySessions(
    Database db, {
    int limit = 5,
  }) async {
    final rows = await db.query(
      'essay_sessions',
      columns: [
        'id',
        'theme_title',
        'theme_source',
        'parser_mode',
        'c1_score',
        'c2_score',
        'c3_score',
        'c4_score',
        'c5_score',
        'final_score',
        'legibility_warning',
        'created_at',
      ],
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return rows
        .map(
          (row) => EssaySessionRecord(
            id: _toInt(row['id']),
            themeTitle: (row['theme_title'] ?? '').toString(),
            themeSource: (row['theme_source'] ?? '').toString(),
            parserMode: (row['parser_mode'] ?? '').toString(),
            c1Score: _toOptionalInt(row['c1_score']),
            c2Score: _toOptionalInt(row['c2_score']),
            c3Score: _toOptionalInt(row['c3_score']),
            c4Score: _toOptionalInt(row['c4_score']),
            c5Score: _toOptionalInt(row['c5_score']),
            finalScore: _toOptionalInt(row['final_score']),
            legibilityWarning: _toBool(row['legibility_warning']),
            createdAt: (row['created_at'] ?? '').toString(),
          ),
        )
        .where((item) => item.id > 0)
        .toList();
  }

  Future<EssayScoreSummary> loadEssayScoreSummary(Database db) async {
    final aggregateRows = await db.rawQuery('''
      SELECT
        COUNT(final_score) AS scored_count,
        MAX(final_score) AS best_score,
        AVG(final_score) AS avg_score
      FROM essay_sessions
      WHERE final_score IS NOT NULL
    ''');

    final aggregate =
        aggregateRows.isEmpty ? const <String, Object?>{} : aggregateRows.first;
    final latestRows = await db.query(
      'essay_sessions',
      columns: ['final_score'],
      where: 'final_score IS NOT NULL',
      orderBy: 'created_at DESC',
      limit: 1,
    );
    final latest =
        latestRows.isEmpty ? const <String, Object?>{} : latestRows.first;

    return EssayScoreSummary(
      scoredSessionCount: _toInt(aggregate['scored_count']),
      averageScore: _toDouble(aggregate['avg_score']),
      bestScore: _toOptionalInt(aggregate['best_score']),
      latestScore: _toOptionalInt(latest['final_score']),
    );
  }

  Future<double> globalAccuracy(Database db) async {
    final rows = await db.rawQuery('''
      SELECT
        SUM(CASE WHEN is_correct = 1 THEN 1 ELSE 0 END) AS hits,
        COUNT(*) AS total
      FROM progress
    ''');

    if (rows.isEmpty) {
      return 0;
    }
    final hits = _toInt(rows.first['hits']);
    final total = _toInt(rows.first['total']);
    if (total <= 0) {
      return 0;
    }
    return hits / total;
  }

  Future<String> getContentVersion(Database db) async {
    final rows = await db.query(
      'app_meta',
      where: 'key = ?',
      whereArgs: ['content_version'],
      limit: 1,
    );
    if (rows.isEmpty) {
      return '0';
    }
    return (rows.first['value'] as String?) ?? '0';
  }

  Future<void> setContentVersion(Database db, String version) async {
    await db.insert(
      'app_meta',
      {'key': 'content_version', 'value': version},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertBundle(Database db, Map<String, dynamic> bundle) async {
    await upsertQuestionsFromBundle(db, bundle);
    await upsertBookModulesFromBundle(db, bundle);
    await upsertModuleQuestionMatchesFromBundle(db, bundle);
    await upsertConceptsFromBundle(db, bundle);
    await upsertQuestionConceptsFromBundle(db, bundle);
    await upsertConceptDependenciesFromBundle(db, bundle);
    await upsertConceptPriorityWeightsFromBundle(db, bundle);
  }

  Future<void> upsertQuestionsFromBundle(
    Database db,
    Map<String, dynamic> bundle,
  ) async {
    final rawQuestions = (bundle['questions'] as List<dynamic>? ?? const []);

    await db.transaction((txn) async {
      for (final item in rawQuestions) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final questionId = (item['id'] ?? '').toString().trim();
        final rawSkill = (item['skill'] ?? '').toString();
        final normalizedSkill = _normalizeSkillToken(rawSkill);
        var normalizedCompetency = _normalizeCompetencyToken(
          (item['competency'] ?? item['competencia'] ?? '').toString(),
        );
        if (normalizedCompetency.isEmpty) {
          normalizedCompetency = _normalizeCompetencyToken(rawSkill);
        }
        final normalizedDiscipline =
            (item['discipline'] ?? '').toString().trim();
        final normalizedMateria =
            (item['materia'] ?? normalizedDiscipline).toString().trim();
        final normalizedDifficulty = _normalizeDifficultyToken(
          (item['difficulty'] ?? item['dificuldade'] ?? '').toString(),
        );
        final fallbackImagePaths = _extractFallbackImagePaths(
          item['fallback_image_paths'],
        );
        var statement = (item['statement'] ?? '').toString().trim();
        var textEmpty = _toBool(item['text_empty']);
        if (statement.isEmpty && fallbackImagePaths.isNotEmpty) {
          statement = 'Texto OCR indisponível (usar imagem fallback).';
          textEmpty = true;
        }
        if (questionId.isEmpty || statement.isEmpty) {
          continue;
        }

        final hasImage =
            _toBool(item['has_image']) || fallbackImagePaths.isNotEmpty;

        await txn.insert(
          'questions',
          {
            'id': questionId,
            'year': int.tryParse('${item['year']}') ?? 0,
            'day': int.tryParse('${item['day']}') ?? 0,
            'number': int.tryParse('${item['number']}') ?? 0,
            'variation': int.tryParse('${item['variation']}') ?? 1,
            'area': (item['area'] ?? '').toString(),
            'discipline': normalizedDiscipline,
            'materia': normalizedMateria,
            'competency': normalizedCompetency,
            'skill': normalizedSkill,
            'difficulty': normalizedDifficulty,
            'has_image': hasImage ? 1 : 0,
            'text_empty': textEmpty ? 1 : 0,
            'statement': statement,
            'fallback_images': _buildFallbackImagesBlob(fallbackImagePaths),
            'answer': (item['answer'] ?? '').toString(),
            'source': (item['source'] ?? '').toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> upsertBookModulesFromBundle(
    Database db,
    Map<String, dynamic> bundle,
  ) async {
    final rawModules = (bundle['book_modules'] as List<dynamic>? ?? const []);

    await db.transaction((txn) async {
      for (final item in rawModules) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final moduleId = (item['id'] ?? '').toString().trim();
        if (moduleId.isEmpty) {
          continue;
        }

        final rawSkillsText = (item['skills_raw'] ?? '').toString();
        final skills = _extractSkills(item['skills'], rawSkillsText);
        final skillsBlob = _buildSkillsBlob(skills);
        final rawCompetenciesText = (item['competencies_raw'] ?? '').toString();
        final competencies = _extractCompetencies(
          item['competencies'],
          rawCompetenciesText,
          rawSkillsText,
        );
        final competenciesBlob = _buildCompetenciesBlob(competencies);
        final normalizedCompetenciesRaw = rawCompetenciesText.trim().isNotEmpty
            ? rawCompetenciesText
            : competencies.join('; ');
        final moduleDescription = (item['description'] ?? '').toString();
        final rawLearningExpectationsText =
            (item['learning_expectations_raw'] ??
                    item['expectativas_aprendizagem'] ??
                    '')
                .toString();
        final learningExpectations = _extractLearningExpectations(
          item['learning_expectations'],
          rawLearningExpectationsText,
          moduleDescription,
        );
        final learningExpectationsBlob =
            _buildLearningExpectationsBlob(learningExpectations);
        final normalizedLearningExpectationsRaw =
            rawLearningExpectationsText.trim().isNotEmpty
                ? rawLearningExpectationsText
                : learningExpectations.join('; ');
        final normalizedDescription = moduleDescription.trim().isNotEmpty
            ? moduleDescription
            : normalizedLearningExpectationsRaw;

        await txn.insert(
          'book_modules',
          {
            'id': moduleId,
            'volume': int.tryParse('${item['volume']}') ?? 0,
            'area': (item['area'] ?? '').toString(),
            'materia': (item['materia'] ?? '').toString(),
            'modulo': int.tryParse('${item['modulo']}') ?? 0,
            'title': (item['title'] ?? '').toString(),
            'page': (item['page'] ?? '').toString(),
            'skills': skillsBlob,
            'skills_raw': rawSkillsText,
            'competencies': competenciesBlob,
            'competencies_raw': normalizedCompetenciesRaw,
            'learning_expectations': learningExpectationsBlob,
            'learning_expectations_raw': normalizedLearningExpectationsRaw,
            'description': normalizedDescription,
            'source': (item['source'] ?? '').toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> upsertModuleQuestionMatchesFromBundle(
    Database db,
    Map<String, dynamic> bundle,
  ) async {
    final rawMatches =
        (bundle['module_question_matches'] as List<dynamic>? ?? const []);

    await db.transaction((txn) async {
      await txn.delete('module_question_matches');
      for (final item in rawMatches) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final questionId = (item['question_id'] ?? '').toString().trim();
        final year = int.tryParse('${item['year']}') ?? 0;
        final day = int.tryParse('${item['day']}') ?? 0;
        final number = int.tryParse('${item['number']}') ?? 0;
        final variation = int.tryParse('${item['variation']}') ?? 1;
        if (questionId.isEmpty || year <= 0 || day <= 0 || number <= 0) {
          continue;
        }

        await txn.insert(
          'module_question_matches',
          {
            'question_id': questionId,
            'year': year,
            'day': day,
            'number': number,
            'variation': variation,
            'area': (item['area'] ?? '').toString(),
            'discipline': (item['discipline'] ?? '').toString(),
            'materia': (item['materia'] ?? '').toString(),
            'volume': int.tryParse('${item['volume']}') ?? 0,
            'modulo': int.tryParse('${item['modulo']}') ?? 0,
            'competencias': (item['competencias'] ?? '').toString(),
            'habilidades': (item['habilidades'] ?? '').toString(),
            'assuntos_match': (item['assuntos_match'] ?? '').toString(),
            'score_match': _toDouble(item['score_match']),
            'tipo_match': (item['tipo_match'] ?? '').toString(),
            'confianca': (item['confianca'] ?? '').toString(),
            'revisado_manual': _toBool(item['revisado_manual']) ? 1 : 0,
            'source': (item['source'] ?? '').toString(),
          },
        );
      }
    });
  }

  Future<void> upsertConceptsFromBundle(
    Database db,
    Map<String, dynamic> bundle,
  ) async {
    if (!await _hasConceptGraphTables(db)) {
      return;
    }
    final rawConcepts = (bundle['concepts'] as List<dynamic>? ?? const []);
    if (rawConcepts.isEmpty) {
      return;
    }

    await db.transaction((txn) async {
      await txn.delete('concepts');
      for (final item in rawConcepts) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final conceptId = _normalizeConceptId('${item['id'] ?? ''}');
        final label = ('${item['label'] ?? ''}').trim();
        if (conceptId.isEmpty || label.isEmpty) {
          continue;
        }
        await txn.insert(
          'concepts',
          {
            'id': conceptId,
            'label': label,
            'area': ('${item['area'] ?? ''}').trim(),
            'difficulty': ('${item['difficulty'] ?? ''}').trim(),
            'source': ('${item['source'] ?? ''}').trim(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> upsertQuestionConceptsFromBundle(
    Database db,
    Map<String, dynamic> bundle,
  ) async {
    if (!await _hasConceptGraphTables(db)) {
      return;
    }
    final rawMappings =
        (bundle['question_concepts'] as List<dynamic>? ?? const []);
    if (rawMappings.isEmpty) {
      return;
    }

    await db.transaction((txn) async {
      await txn.delete('question_concepts');
      for (final item in rawMappings) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final questionId = ('${item['question_id'] ?? ''}').trim();
        final conceptId = _normalizeConceptId('${item['concept_id'] ?? ''}');
        final weight = _toDouble(item['weight']).clamp(0, 1).toDouble();
        if (questionId.isEmpty || conceptId.isEmpty || weight <= 0) {
          continue;
        }
        await txn.insert(
          'question_concepts',
          {
            'question_id': questionId,
            'concept_id': conceptId,
            'weight': weight,
            'source': ('${item['source'] ?? ''}').trim(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> upsertConceptDependenciesFromBundle(
    Database db,
    Map<String, dynamic> bundle,
  ) async {
    if (!await _hasConceptGraphTables(db)) {
      return;
    }
    final rawDependencies =
        (bundle['concept_dependencies'] as List<dynamic>? ?? const []);
    if (rawDependencies.isEmpty) {
      return;
    }

    await db.transaction((txn) async {
      await txn.delete('concept_dependencies');
      for (final item in rawDependencies) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final conceptId = _normalizeConceptId('${item['concept_id'] ?? ''}');
        final dependsOn = _normalizeConceptId('${item['depends_on'] ?? ''}');
        final strength = _toDouble(item['strength']).clamp(0, 1).toDouble();
        if (conceptId.isEmpty || dependsOn.isEmpty || strength <= 0) {
          continue;
        }
        await txn.insert(
          'concept_dependencies',
          {
            'concept_id': conceptId,
            'depends_on': dependsOn,
            'strength': strength,
            'source': ('${item['source'] ?? ''}').trim(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> upsertConceptPriorityWeightsFromBundle(
    Database db,
    Map<String, dynamic> bundle,
  ) async {
    if (!await _hasConceptGraphTables(db)) {
      return;
    }
    final rawWeights =
        (bundle['concept_priority_weights'] as List<dynamic>? ?? const []);
    if (rawWeights.isEmpty) {
      return;
    }

    await db.transaction((txn) async {
      await txn.delete('concept_priority_weights');
      for (final item in rawWeights) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final conceptId = _normalizeConceptId('${item['concept_id'] ?? ''}');
        final baseWeight = _toDouble(item['base_weight']).clamp(0.1, 5);
        if (conceptId.isEmpty || baseWeight <= 0) {
          continue;
        }
        await txn.insert(
          'concept_priority_weights',
          {
            'concept_id': conceptId,
            'base_weight': baseWeight.toDouble(),
            'reason': ('${item['reason'] ?? ''}').trim(),
            'source': ('${item['source'] ?? ''}').trim(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> recordAnswer(
    Database db, {
    required String questionId,
    required bool isCorrect,
    DateTime? answeredAt,
    int? elapsedSeconds,
    String answerSource = '',
  }) async {
    final normalizedElapsed =
        elapsedSeconds == null || elapsedSeconds <= 0 ? null : elapsedSeconds;
    final normalizedSource = answerSource.trim();
    await db.insert(
      'progress',
      {
        'question_id': questionId,
        'is_correct': isCorrect ? 1 : 0,
        'answered_at': (answeredAt ?? DateTime.now()).toIso8601String(),
        'elapsed_seconds': normalizedElapsed,
        'answer_source': normalizedSource.isEmpty ? null : normalizedSource,
      },
    );
  }

  Future<LessonProgressRecord?> loadLessonProgress(
    Database db, {
    required String lessonId,
    required String lessonVersion,
  }) async {
    final normalizedLessonId = lessonId.trim();
    final normalizedVersion = lessonVersion.trim();
    if (normalizedLessonId.isEmpty || normalizedVersion.isEmpty) {
      return null;
    }

    final rows = await db.query(
      'lesson_progress',
      where: 'lesson_id = ? AND lesson_version = ?',
      whereArgs: [normalizedLessonId, normalizedVersion],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    final answersJson = (row['answers_json'] ?? '{}').toString();
    final answers = <String, String>{};
    try {
      final decoded = jsonDecode(answersJson);
      if (decoded is Map<String, dynamic>) {
        for (final entry in decoded.entries) {
          final key = entry.key.trim();
          final value = entry.value.toString().trim().toUpperCase();
          if (key.isEmpty || value.isEmpty) {
            continue;
          }
          answers[key] = value;
        }
      }
    } catch (_) {
      // Ignora payload inválido e segue com mapa vazio.
    }

    final updatedAtRaw = (row['updated_at'] ?? '').toString();
    final updatedAt = DateTime.tryParse(updatedAtRaw) ?? DateTime.now();
    return LessonProgressRecord(
      lessonId: normalizedLessonId,
      lessonVersion: normalizedVersion,
      answers: answers,
      submitted: _toBool(row['submitted']),
      score: _toInt(row['score']),
      totalQuestions: _toInt(row['total_questions']),
      updatedAt: updatedAt,
    );
  }

  Future<void> upsertLessonProgress(
    Database db, {
    required String lessonId,
    required String lessonVersion,
    required Map<String, String> answers,
    required bool submitted,
    required int score,
    required int totalQuestions,
  }) async {
    final normalizedLessonId = lessonId.trim();
    final normalizedVersion = lessonVersion.trim();
    if (normalizedLessonId.isEmpty || normalizedVersion.isEmpty) {
      return;
    }

    final normalizedAnswers = <String, String>{};
    for (final entry in answers.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim().toUpperCase();
      if (key.isEmpty || value.isEmpty) {
        continue;
      }
      normalizedAnswers[key] = value;
    }

    await db.insert(
      'lesson_progress',
      {
        'lesson_id': normalizedLessonId,
        'lesson_version': normalizedVersion,
        'answers_json': jsonEncode(normalizedAnswers),
        'submitted': submitted ? 1 : 0,
        'score': math.max(0, score),
        'total_questions': math.max(0, totalQuestions),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteLessonProgress(
    Database db, {
    required String lessonId,
    required String lessonVersion,
  }) async {
    final normalizedLessonId = lessonId.trim();
    final normalizedVersion = lessonVersion.trim();
    if (normalizedLessonId.isEmpty || normalizedVersion.isEmpty) {
      return;
    }
    await db.delete(
      'lesson_progress',
      where: 'lesson_id = ? AND lesson_version = ?',
      whereArgs: [normalizedLessonId, normalizedVersion],
    );
  }

  Future<void> markLessonAttemptsOutdated(
    Database db, {
    required String lessonId,
    required String keepLessonVersion,
  }) async {
    final normalizedLessonId = lessonId.trim();
    final normalizedKeepVersion = keepLessonVersion.trim();
    if (normalizedLessonId.isEmpty || normalizedKeepVersion.isEmpty) {
      return;
    }
    await db.update(
      'lesson_question_attempts',
      {'is_outdated': 1},
      where: 'lesson_id = ? AND lesson_version <> ? AND is_outdated = 0',
      whereArgs: [normalizedLessonId, normalizedKeepVersion],
    );
  }

  Future<void> upsertLessonQuestionAttempts(
    Database db, {
    required String lessonId,
    required String lessonVersion,
    required List<LessonQuestionAttemptInput> attempts,
  }) async {
    final normalizedLessonId = lessonId.trim();
    final normalizedVersion = lessonVersion.trim();
    if (normalizedLessonId.isEmpty || normalizedVersion.isEmpty) {
      return;
    }
    if (attempts.isEmpty) {
      return;
    }

    await db.transaction((txn) async {
      for (final input in attempts) {
        final questionId = input.lessonQuestionId.trim();
        final selected = input.selectedOption.trim().toUpperCase();
        final sourceId = input.sourceQuestionId.trim();
        if (questionId.isEmpty || selected.isEmpty) {
          continue;
        }
        await txn.insert(
          'lesson_question_attempts',
          {
            'lesson_id': normalizedLessonId,
            'lesson_version': normalizedVersion,
            'lesson_question_id': questionId,
            'source_question_id': sourceId.isEmpty ? null : sourceId,
            'selected_option': selected,
            'is_correct': input.isCorrect ? 1 : 0,
            'is_outdated': 0,
            'attempted_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<int> countOutdatedLessonAttempts(
    Database db, {
    required String lessonId,
  }) async {
    final normalizedLessonId = lessonId.trim();
    if (normalizedLessonId.isEmpty) {
      return 0;
    }
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS c
      FROM lesson_question_attempts
      WHERE lesson_id = ? AND is_outdated = 1
      ''',
      [normalizedLessonId],
    );
    if (rows.isEmpty) {
      return 0;
    }
    return _toInt(rows.first['c']);
  }

  Future<List<LessonVersionAttemptSummary>> loadLessonAttemptSummaries(
    Database db, {
    required String lessonId,
    int limit = 12,
  }) async {
    final normalizedLessonId = lessonId.trim();
    if (normalizedLessonId.isEmpty) {
      return const [];
    }
    final safeLimit = limit <= 0 ? 12 : limit.clamp(1, 50);
    final rows = await db.rawQuery(
      '''
      SELECT
        lesson_version,
        COUNT(*) AS attempt_count,
        SUM(CASE WHEN is_correct = 1 THEN 1 ELSE 0 END) AS correct_count,
        SUM(CASE WHEN is_outdated = 1 THEN 1 ELSE 0 END) AS outdated_count,
        MAX(attempted_at) AS last_attempted_at
      FROM lesson_question_attempts
      WHERE lesson_id = ?
      GROUP BY lesson_version
      ORDER BY last_attempted_at DESC
      LIMIT ?
      ''',
      [normalizedLessonId, safeLimit],
    );
    return rows.map((row) {
      final lastAttemptedRaw = (row['last_attempted_at'] ?? '').toString();
      final lastAttemptedAt = DateTime.tryParse(lastAttemptedRaw) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return LessonVersionAttemptSummary(
        lessonVersion: (row['lesson_version'] ?? '').toString(),
        attemptCount: _toInt(row['attempt_count']),
        correctCount: _toInt(row['correct_count']),
        outdatedCount: _toInt(row['outdated_count']),
        lastAttemptedAt: lastAttemptedAt,
      );
    }).toList(growable: false);
  }

  Future<String?> firstQuestionId(Database db) async {
    final rows = await db.query(
      'questions',
      columns: ['id'],
      orderBy: 'year DESC, day DESC, number ASC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return (rows.first['id'] ?? '').toString();
  }

  Future<void> recordDemoAttempt(Database db, {required bool isCorrect}) async {
    final questionId = await firstQuestionId(db);
    if (questionId == null || questionId.isEmpty) {
      return;
    }
    await recordAnswer(
      db,
      questionId: questionId,
      isCorrect: isCorrect,
      answerSource: 'demo',
    );
  }

  Future<List<WeakSkillStat>> loadWeakSkills(Database db,
      {int limit = 5}) async {
    final rows = await db.rawQuery(
      '''
      SELECT
        q.skill AS skill,
        SUM(CASE WHEN p.is_correct = 1 THEN 1 ELSE 0 END) AS correct_count,
        COUNT(*) AS total_count
      FROM progress p
      JOIN questions q ON q.id = p.question_id
      WHERE q.skill IS NOT NULL AND TRIM(q.skill) <> ''
      GROUP BY q.skill
      ORDER BY
        (1.0 * SUM(CASE WHEN p.is_correct = 1 THEN 1 ELSE 0 END) / COUNT(*)) ASC,
        COUNT(*) DESC
      LIMIT ?
      ''',
      [limit],
    );

    return rows
        .map(
          (row) => WeakSkillStat(
            skill: (row['skill'] ?? '').toString(),
            correct: _toInt(row['correct_count']),
            total: _toInt(row['total_count']),
          ),
        )
        .where((item) => item.skill.isNotEmpty && item.total > 0)
        .toList();
  }

  Future<SkillErrorProfile?> loadSkillErrorProfile(
    Database db, {
    required String skill,
    int topicLimit = 5,
  }) async {
    final normalizedSkill = _normalizeSkillToken(skill);
    if (normalizedSkill.isEmpty) {
      return null;
    }

    final summaryRows = await db.rawQuery(
      '''
      SELECT
        SUM(CASE WHEN p.is_correct = 1 THEN 1 ELSE 0 END) AS correct_count,
        SUM(CASE WHEN p.is_correct = 0 THEN 1 ELSE 0 END) AS error_count,
        COUNT(*) AS total_count,
        SUM(
          CASE
            WHEN p.is_correct = 0
             AND p.elapsed_seconds IS NOT NULL
             AND p.elapsed_seconds >= 120
            THEN 1
            ELSE 0
          END
        ) AS high_time_error_count,
        SUM(
          CASE
            WHEN p.is_correct = 0
             AND p.elapsed_seconds IS NOT NULL
             AND p.elapsed_seconds <= 30
            THEN 1
            ELSE 0
          END
        ) AS quick_error_count,
        SUM(
          CASE
            WHEN p.is_correct = 0
             AND LOWER(TRIM(COALESCE(q.difficulty, ''))) IN ('facil', 'fácil', 'easy', 'f')
            THEN 1
            ELSE 0
          END
        ) AS easy_error_count,
        AVG(
          CASE
            WHEN p.elapsed_seconds IS NOT NULL AND p.elapsed_seconds > 0
            THEN p.elapsed_seconds
            ELSE NULL
          END
        ) AS avg_seconds,
        AVG(
          CASE
            WHEN p.is_correct = 0
             AND p.elapsed_seconds IS NOT NULL
             AND p.elapsed_seconds > 0
            THEN p.elapsed_seconds
            ELSE NULL
          END
        ) AS avg_error_seconds
      FROM progress p
      JOIN questions q ON q.id = p.question_id
      WHERE LOWER(COALESCE(q.skill, '')) = LOWER(?)
      ''',
      [normalizedSkill],
    );
    if (summaryRows.isEmpty) {
      return null;
    }

    final summary = summaryRows.first;
    final attempts = _toInt(summary['total_count']);
    if (attempts <= 0) {
      return null;
    }
    final correct = _toInt(summary['correct_count']);
    final errorCount = _toInt(summary['error_count']);
    final highTimeErrorCount = _toInt(summary['high_time_error_count']);
    final quickErrorCount = _toInt(summary['quick_error_count']);
    final easyErrorCount = _toInt(summary['easy_error_count']);
    final accuracy = correct / attempts;
    final averageSeconds = _toDouble(summary['avg_seconds']);
    final averageErrorSeconds = _toDouble(summary['avg_error_seconds']);
    final highTimeErrorRate =
        (errorCount <= 0 ? 0.0 : highTimeErrorCount / errorCount).toDouble();
    final quickErrorRate =
        (errorCount <= 0 ? 0.0 : quickErrorCount / errorCount).toDouble();
    final easyErrorRate =
        (errorCount <= 0 ? 0.0 : easyErrorCount / errorCount).toDouble();

    final levelRows = await db.rawQuery(
      '''
      SELECT
        LOWER(COALESCE(q.difficulty, '')) AS difficulty,
        SUM(CASE WHEN p.is_correct = 0 THEN 1 ELSE 0 END) AS error_count,
        COUNT(*) AS total_count
      FROM progress p
      JOIN questions q ON q.id = p.question_id
      WHERE LOWER(COALESCE(q.skill, '')) = LOWER(?)
      GROUP BY LOWER(COALESCE(q.difficulty, ''))
      ''',
      [normalizedSkill],
    );

    String levelBreak = 'media';
    int bestErrorCount = -1;
    double bestErrorRate = -1;
    for (final row in levelRows) {
      final difficulty =
          _normalizeDifficultyToken((row['difficulty'] ?? '').toString());
      if (difficulty.isEmpty) {
        continue;
      }
      final errorCount = _toInt(row['error_count']);
      final totalCount = _toInt(row['total_count']);
      if (totalCount <= 0) {
        continue;
      }
      final errorRate = errorCount / totalCount;
      final isBetter = errorCount > bestErrorCount ||
          (errorCount == bestErrorCount && errorRate > bestErrorRate);
      if (!isBetter) {
        continue;
      }
      bestErrorCount = errorCount;
      bestErrorRate = errorRate;
      levelBreak = difficulty;
    }

    String pacing = 'equilibrado';
    final paceReference =
        averageErrorSeconds > 0 ? averageErrorSeconds : averageSeconds;
    if (paceReference > 0) {
      if (paceReference <= 40) {
        pacing = 'rapido';
      } else if (paceReference >= 120) {
        pacing = 'lento';
      }
    }

    final topicRows = await db.rawQuery(
      '''
      SELECT
        COALESCE(m.assuntos_match, '') AS assuntos_match,
        COALESCE(q.materia, '') AS materia,
        COALESCE(q.discipline, '') AS discipline
      FROM progress p
      JOIN questions q ON q.id = p.question_id
      LEFT JOIN module_question_matches m ON m.question_id = q.id
      WHERE LOWER(COALESCE(q.skill, '')) = LOWER(?)
        AND p.is_correct = 0
      ''',
      [normalizedSkill],
    );

    final topicCounts = <String, int>{};
    for (final row in topicRows) {
      final rawAssuntos = (row['assuntos_match'] ?? '').toString();
      final rawMateria = (row['materia'] ?? '').toString();
      final rawDiscipline = (row['discipline'] ?? '').toString();
      final rawTokens = <String>[];

      if (rawAssuntos.trim().isNotEmpty) {
        rawTokens.addAll(rawAssuntos.split(RegExp(r'[;,|/]')));
      }
      if (rawTokens.isEmpty && rawMateria.trim().isNotEmpty) {
        rawTokens.add(rawMateria);
      }
      if (rawTokens.isEmpty && rawDiscipline.trim().isNotEmpty) {
        rawTokens.add(rawDiscipline);
      }

      for (final token in rawTokens) {
        final normalized = _normalizeTopicTag(token);
        if (normalized.isEmpty) {
          continue;
        }
        topicCounts[normalized] = (topicCounts[normalized] ?? 0) + 1;
      }
    }

    final sortedTopics = topicCounts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) {
          return byCount;
        }
        return a.key.compareTo(b.key);
      });
    final safeLimit = topicLimit.clamp(1, 12).toInt();
    final topicTags =
        sortedTopics.take(safeLimit).map((entry) => entry.key).toList();
    final totalTagMentions = sortedTopics.fold<int>(
      0,
      (sum, entry) => sum + entry.value,
    );
    final topTagMentions = sortedTopics.isEmpty ? 0 : sortedTopics.first.value;
    final topTagRate =
        totalTagMentions <= 0 ? 0 : topTagMentions / totalTagMentions;

    final highTimeErrorSignal =
        highTimeErrorCount >= 2 || highTimeErrorRate >= 0.45;
    final quickErrorSignal = quickErrorCount >= 2 || quickErrorRate >= 0.45;
    final easyErrorSignal = easyErrorCount >= 2 || easyErrorRate >= 0.35;
    final repeatedTagErrorSignal =
        topTagMentions >= 2 && (topTagRate >= 0.5 || topTagMentions >= 3);

    String pattern = 'aleatorio';
    if (repeatedTagErrorSignal) {
      pattern = 'repetido';
    } else if (bestErrorRate >= 0.6) {
      pattern = 'repetido';
    }

    final evidence = <SkillErrorEvidence>[];
    if (errorCount > 0) {
      evidence.add(
        SkillErrorEvidence(
          signal: 'erro_tempo_alto',
          evidenceType: 'tempo',
          evidenceValue: '>=120s',
          errorCount: highTimeErrorCount,
          totalCount: errorCount,
          errorRate: highTimeErrorRate,
        ),
      );
      evidence.add(
        SkillErrorEvidence(
          signal: 'erro_rapido',
          evidenceType: 'tempo',
          evidenceValue: '<=30s',
          errorCount: quickErrorCount,
          totalCount: errorCount,
          errorRate: quickErrorRate,
        ),
      );
      evidence.add(
        SkillErrorEvidence(
          signal: 'erro_questao_facil',
          evidenceType: 'difficulty',
          evidenceValue: 'facil',
          errorCount: easyErrorCount,
          totalCount: errorCount,
          errorRate: easyErrorRate,
        ),
      );
    }

    for (final row in levelRows) {
      final difficulty =
          _normalizeDifficultyToken((row['difficulty'] ?? '').toString());
      final levelErrorCount = _toInt(row['error_count']);
      final levelTotalCount = _toInt(row['total_count']);
      if (difficulty.isEmpty || levelErrorCount <= 0 || levelTotalCount <= 0) {
        continue;
      }
      evidence.add(
        SkillErrorEvidence(
          signal: 'erro_por_dificuldade',
          evidenceType: 'difficulty',
          evidenceValue: difficulty,
          errorCount: levelErrorCount,
          totalCount: levelTotalCount,
          errorRate: levelErrorCount / levelTotalCount,
        ),
      );
    }

    if (totalTagMentions > 0) {
      for (final entry in sortedTopics.take(safeLimit)) {
        evidence.add(
          SkillErrorEvidence(
            signal: 'erro_recorrente_tag',
            evidenceType: 'tag',
            evidenceValue: entry.key,
            errorCount: entry.value,
            totalCount: totalTagMentions,
            errorRate: entry.value / totalTagMentions,
          ),
        );
      }
    }
    await _persistSkillErrorEvidence(
      db,
      skill: normalizedSkill,
      evidence: evidence,
    );

    return SkillErrorProfile(
      skill: normalizedSkill,
      attempts: attempts,
      accuracy: accuracy,
      pacing: pacing,
      levelBreak: levelBreak,
      pattern: pattern,
      topicTags: topicTags,
      averageSeconds: averageSeconds,
      highTimeErrorSignal: highTimeErrorSignal,
      quickErrorSignal: quickErrorSignal,
      repeatedTagErrorSignal: repeatedTagErrorSignal,
      easyErrorSignal: easyErrorSignal,
      evidence: evidence,
    );
  }

  Future<void> _persistSkillErrorEvidence(
    Database db, {
    required String skill,
    required List<SkillErrorEvidence> evidence,
  }) async {
    final normalizedSkill = _normalizeSkillToken(skill);
    if (normalizedSkill.isEmpty) {
      return;
    }

    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete(
        'skill_error_evidence',
        where: 'LOWER(skill) = LOWER(?)',
        whereArgs: [normalizedSkill],
      );

      for (final item in evidence) {
        final signal = item.signal.trim().toLowerCase();
        final evidenceType = item.evidenceType.trim().toLowerCase();
        final evidenceValue = item.evidenceValue.trim().toLowerCase();
        if (signal.isEmpty || evidenceType.isEmpty || evidenceValue.isEmpty) {
          continue;
        }
        if (item.totalCount <= 0 || item.errorCount <= 0) {
          continue;
        }

        await txn.insert(
          'skill_error_evidence',
          {
            'skill': normalizedSkill,
            'signal': signal,
            'evidence_type': evidenceType,
            'evidence_value': evidenceValue,
            'error_count': item.errorCount,
            'total_count': item.totalCount,
            'error_rate': item.errorRate.clamp(0, 1).toDouble(),
            'updated_at': now,
          },
        );
      }
    });
  }

  Future<List<SkillPriorityItem>> loadSkillPriorities(
    Database db, {
    int limit = 10,
  }) async {
    final safeLimit = limit <= 0 ? 10 : limit.clamp(1, 50);
    final rows = await db.rawQuery('''
      SELECT
        q.skill AS skill,
        SUM(CASE WHEN p.is_correct = 1 THEN 1 ELSE 0 END) AS correct_count,
        COUNT(*) AS total_count,
        MAX(p.answered_at) AS last_answered_at
      FROM progress p
      JOIN questions q ON q.id = p.question_id
      WHERE q.skill IS NOT NULL AND TRIM(q.skill) <> ''
      GROUP BY q.skill
    ''');

    if (rows.isEmpty) {
      return const [];
    }

    final now = DateTime.now();
    final priorities = <SkillPriorityItem>[];
    for (final row in rows) {
      final skill = (row['skill'] ?? '').toString().trim();
      final attempts = _toInt(row['total_count']);
      final correct = _toInt(row['correct_count']);
      if (skill.isEmpty || attempts <= 0) {
        continue;
      }

      final accuracy = correct / attempts;
      final deficit = 1 - accuracy;
      final lastAnsweredRaw = (row['last_answered_at'] ?? '').toString().trim();
      final lastAnswered = DateTime.tryParse(lastAnsweredRaw)?.toLocal();
      final daysSinceLastSeen = lastAnswered == null
          ? 30
          : now.difference(lastAnswered).inDays.clamp(0, 365);
      final recency = (daysSinceLastSeen * 0.02).clamp(0, 0.3).toDouble();
      final confidence = _confidenceFromAttempts(attempts);
      final priorityScore = deficit + recency + (1 - confidence);

      priorities.add(
        SkillPriorityItem(
          skill: skill,
          accuracy: accuracy,
          attempts: attempts,
          daysSinceLastSeen: daysSinceLastSeen,
          deficit: deficit,
          recency: recency,
          confidence: confidence,
          priorityScore: priorityScore,
          band: _bandFromAccuracy(accuracy),
        ),
      );
    }

    priorities.sort((a, b) {
      final scoreCompare = b.priorityScore.compareTo(a.priorityScore);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return b.attempts.compareTo(a.attempts);
    });

    return priorities.take(safeLimit).toList();
  }

  Future<List<_ConceptPriorityItem>> _loadConceptPriorities(
    Database db, {
    int limit = 8,
  }) async {
    final safeLimit = limit <= 0 ? 8 : limit.clamp(1, 24).toInt();
    if (!await _hasConceptGraphTables(db)) {
      return const [];
    }

    final rows = await db.rawQuery('''
      WITH active_profile AS (
        SELECT id
        FROM student_profiles
        WHERE is_active = 1
        ORDER BY updated_at DESC
        LIMIT 1
      )
      SELECT
        qc.concept_id AS concept_id,
        COUNT(*) AS attempts,
        SUM(CASE WHEN p.is_correct = 1 THEN qc.weight ELSE 0 END) AS weighted_correct,
        SUM(qc.weight) AS weighted_total,
        cm.mastery AS stored_mastery,
        COALESCE(MAX(cpw.base_weight), 1) AS base_weight,
        MAX(p.answered_at) AS last_answered_at
      FROM progress p
      JOIN question_concepts qc ON qc.question_id = p.question_id
      LEFT JOIN concept_priority_weights cpw
        ON LOWER(cpw.concept_id) = LOWER(qc.concept_id)
      LEFT JOIN active_profile ap ON 1 = 1
      LEFT JOIN concept_mastery cm
        ON cm.profile_id = ap.id
       AND LOWER(cm.concept_id) = LOWER(qc.concept_id)
      GROUP BY qc.concept_id
      HAVING COUNT(*) > 0
    ''');

    if (rows.isEmpty) {
      return const [];
    }

    final now = DateTime.now();
    final priorities = <_ConceptPriorityItem>[];
    for (final row in rows) {
      final conceptId = _normalizeConceptId('${row['concept_id'] ?? ''}');
      if (conceptId.isEmpty) {
        continue;
      }

      final attempts = _toInt(row['attempts']);
      final weightedTotal = _toDouble(row['weighted_total']);
      final weightedCorrect = _toDouble(row['weighted_correct']);
      if (attempts <= 0 || weightedTotal <= 0) {
        continue;
      }

      final observedMastery =
          (weightedCorrect / weightedTotal).clamp(0, 1).toDouble();
      final storedMastery = _toOptionalDouble(row['stored_mastery']);
      final mastery = storedMastery == null
          ? observedMastery
          : ((observedMastery * 0.35) +
                  (storedMastery.clamp(0, 1).toDouble() * 0.65))
              .clamp(0, 1)
              .toDouble();
      final weakness = 1 - mastery;
      final confidence = _confidenceFromAttempts(attempts);
      final baseWeight = _toDouble(row['base_weight']).clamp(0.5, 3).toDouble();
      final lastAnsweredRaw = ('${row['last_answered_at'] ?? ''}').trim();
      final lastAnswered = DateTime.tryParse(lastAnsweredRaw)?.toLocal();
      final daysSinceLastSeen = lastAnswered == null
          ? 30
          : now.difference(lastAnswered).inDays.clamp(0, 365);
      final recencyBoost = (daysSinceLastSeen * 0.01).clamp(0, 0.2).toDouble();
      final priorityScore =
          (weakness * baseWeight) + ((1 - confidence) * 0.25) + recencyBoost;

      priorities.add(
        _ConceptPriorityItem(
          conceptId: conceptId,
          priorityScore: priorityScore,
        ),
      );
    }

    priorities.sort(
      (a, b) => b.priorityScore.compareTo(a.priorityScore),
    );
    return priorities.take(safeLimit).toList();
  }

  Future<List<ConceptQuestionCandidate>> loadConceptQuestionCandidates(
    Database db, {
    int conceptLimit = 8,
    int perConceptQuestionLimit = 12,
    int maxQuestions = 30,
  }) async {
    final safeQuestionLimit =
        maxQuestions <= 0 ? 30 : maxQuestions.clamp(1, 90).toInt();
    final safePerConceptLimit = perConceptQuestionLimit <= 0
        ? 12
        : perConceptQuestionLimit.clamp(1, 60).toInt();
    final conceptPriorities = await _loadConceptPriorities(
      db,
      limit: conceptLimit,
    );
    if (conceptPriorities.isEmpty) {
      return const [];
    }

    final byQuestion = <String, ConceptQuestionCandidate>{};
    final now = DateTime.now();

    for (final concept in conceptPriorities) {
      final rows = await db.rawQuery(
        '''
        SELECT
          q.id AS id,
          q.year AS year,
          q.day AS day,
          q.number AS number,
          COALESCE(q.variation, 1) AS variation,
          COALESCE(q.area, '') AS area,
          COALESCE(q.discipline, '') AS discipline,
          COALESCE(q.materia, '') AS materia,
          COALESCE(q.competency, '') AS competency,
          COALESCE(q.skill, '') AS skill,
          COALESCE(q.difficulty, '') AS difficulty,
          CASE
            WHEN COALESCE(q.has_image, 0) = 1 OR COALESCE(q.fallback_images, '') <> ''
            THEN 1 ELSE 0
          END AS has_image,
          COALESCE(q.statement, '') AS statement,
          COALESCE(q.answer, '') AS answer,
          qc.weight AS concept_weight,
          COALESCE(qp.attempt_count, 0) AS attempt_count,
          COALESCE(qp.correct_count, 0) AS correct_count,
          COALESCE(qp.last_answered_at, '') AS last_answered_at
        FROM question_concepts qc
        JOIN questions q ON q.id = qc.question_id
        LEFT JOIN (
          SELECT
            question_id,
            COUNT(*) AS attempt_count,
            SUM(CASE WHEN is_correct = 1 THEN 1 ELSE 0 END) AS correct_count,
            MAX(answered_at) AS last_answered_at
          FROM progress
          GROUP BY question_id
        ) qp ON qp.question_id = q.id
        WHERE LOWER(qc.concept_id) = LOWER(?)
        ORDER BY qc.weight DESC, q.year DESC, q.day ASC, q.number ASC
        LIMIT ?
        ''',
        [concept.conceptId, safePerConceptLimit],
      );

      for (final row in rows) {
        final question = _questionCardFromRow(row);
        if (question == null) {
          continue;
        }

        final conceptWeight =
            _toDouble(row['concept_weight']).clamp(0, 1).toDouble();
        if (conceptWeight <= 0) {
          continue;
        }
        final attempts = _toInt(row['attempt_count']);
        final correct = _toInt(row['correct_count']);
        final questionWeakness = attempts <= 0
            ? 0.12
            : (1 - (correct / attempts)).clamp(0, 1).toDouble();
        final lastAnsweredRaw = ('${row['last_answered_at'] ?? ''}').trim();
        final lastAnswered = DateTime.tryParse(lastAnsweredRaw)?.toLocal();
        final recencyBoost = lastAnswered == null
            ? 0.08
            : (now.difference(lastAnswered).inDays * 0.004)
                .clamp(0, 0.12)
                .toDouble();
        final score = (concept.priorityScore * conceptWeight) +
            (questionWeakness * 0.22) +
            recencyBoost;

        final previous = byQuestion[question.id];
        if (previous == null || score > previous.score) {
          byQuestion[question.id] = ConceptQuestionCandidate(
            question: question,
            conceptId: concept.conceptId,
            conceptWeight: conceptWeight.toDouble(),
            conceptPriorityScore: concept.priorityScore,
            score: score,
          );
        }
      }
    }

    if (byQuestion.isEmpty) {
      return const [];
    }

    final ordered = byQuestion.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return ordered.take(safeQuestionLimit).toList();
  }

  Future<ConceptDiagnosticSession?> loadConceptDiagnosticSession(
    Database db, {
    required String sourceQuestionId,
    int questionLimit = 3,
  }) async {
    final normalizedSourceQuestionId = sourceQuestionId.trim();
    if (normalizedSourceQuestionId.isEmpty) {
      return null;
    }
    final safeLimit =
        questionLimit <= 0 ? 3 : questionLimit.clamp(1, 5).toInt();
    if (!await _hasConceptGraphTables(db)) {
      return null;
    }

    final conceptRows = await db.rawQuery(
      '''
      SELECT
        qc.concept_id AS concept_id,
        COALESCE(c.label, qc.concept_id) AS concept_label
      FROM question_concepts qc
      LEFT JOIN concepts c ON LOWER(c.id) = LOWER(qc.concept_id)
      WHERE qc.question_id = ?
      ORDER BY qc.weight DESC, qc.concept_id ASC
      LIMIT 1
      ''',
      [normalizedSourceQuestionId],
    );
    if (conceptRows.isEmpty) {
      return null;
    }

    final conceptId =
        _normalizeConceptId('${conceptRows.first['concept_id'] ?? ''}');
    final conceptLabel = ('${conceptRows.first['concept_label'] ?? ''}').trim();
    if (conceptId.isEmpty) {
      return null;
    }

    const questionProjection = '''
      q.id AS id,
      q.year AS year,
      q.day AS day,
      q.number AS number,
      COALESCE(q.variation, 1) AS variation,
      COALESCE(q.area, '') AS area,
      COALESCE(q.discipline, '') AS discipline,
      COALESCE(q.materia, '') AS materia,
      COALESCE(q.competency, '') AS competency,
      COALESCE(q.skill, '') AS skill,
      COALESCE(q.difficulty, '') AS difficulty,
      CASE
        WHEN COALESCE(q.has_image, 0) = 1 OR COALESCE(q.fallback_images, '') <> ''
        THEN 1 ELSE 0
      END AS has_image,
      COALESCE(q.statement, '') AS statement,
      COALESCE(q.answer, '') AS answer
    ''';

    final selectedQuestions = <QuestionCardItem>[];
    final seenIds = <String>{};

    final sourceRows = await db.rawQuery(
      '''
      SELECT $questionProjection
      FROM questions q
      WHERE q.id = ?
      LIMIT 1
      ''',
      [normalizedSourceQuestionId],
    );
    final sourceQuestion =
        sourceRows.isEmpty ? null : _questionCardFromRow(sourceRows.first);
    final sourceSkill = sourceQuestion?.skill.trim() ?? '';

    final conceptQuestionRows = await db.rawQuery(
      '''
      SELECT
        $questionProjection,
        COALESCE(qp.attempt_count, 0) AS attempt_count,
        qc.weight AS concept_weight
      FROM question_concepts qc
      JOIN questions q ON q.id = qc.question_id
      LEFT JOIN (
        SELECT
          question_id,
          COUNT(*) AS attempt_count
        FROM progress
        GROUP BY question_id
      ) qp ON qp.question_id = q.id
      WHERE LOWER(qc.concept_id) = LOWER(?)
      ORDER BY
        CASE WHEN q.id = ? THEN 0 ELSE 1 END ASC,
        COALESCE(qp.attempt_count, 0) ASC,
        qc.weight DESC,
        q.year DESC,
        q.day ASC,
        q.number ASC
      LIMIT ?
      ''',
      [conceptId, normalizedSourceQuestionId, safeLimit * 6],
    );

    for (final row in conceptQuestionRows) {
      final question = _questionCardFromRow(row);
      if (question == null || !seenIds.add(question.id)) {
        continue;
      }
      selectedQuestions.add(question);
      if (selectedQuestions.length >= safeLimit) {
        break;
      }
    }

    if (selectedQuestions.length < safeLimit && sourceSkill.isNotEmpty) {
      final skillRows = await db.rawQuery(
        '''
        SELECT $questionProjection
        FROM questions q
        WHERE LOWER(COALESCE(q.skill, '')) = LOWER(?)
        ORDER BY q.year DESC, q.day ASC, q.number ASC
        LIMIT ?
        ''',
        [sourceSkill, safeLimit * 6],
      );
      for (final row in skillRows) {
        final question = _questionCardFromRow(row);
        if (question == null || !seenIds.add(question.id)) {
          continue;
        }
        selectedQuestions.add(question);
        if (selectedQuestions.length >= safeLimit) {
          break;
        }
      }
    }

    if (selectedQuestions.length < safeLimit) {
      final fallbackRows = await db.rawQuery(
        '''
        SELECT $questionProjection
        FROM questions q
        ORDER BY q.year DESC, q.day ASC, q.number ASC
        LIMIT ?
        ''',
        [safeLimit * 8],
      );
      for (final row in fallbackRows) {
        final question = _questionCardFromRow(row);
        if (question == null || !seenIds.add(question.id)) {
          continue;
        }
        selectedQuestions.add(question);
        if (selectedQuestions.length >= safeLimit) {
          break;
        }
      }
    }

    if (selectedQuestions.isEmpty) {
      return null;
    }

    return ConceptDiagnosticSession(
      conceptId: conceptId,
      conceptLabel: conceptLabel.isEmpty ? conceptId : conceptLabel,
      questions: selectedQuestions.take(safeLimit).toList(),
    );
  }

  Future<double?> applyConceptDiagnosticResult(
    Database db, {
    required String profileId,
    required String conceptId,
    required int correctCount,
    required int totalCount,
  }) async {
    if (!await _hasConceptGraphTables(db)) {
      return null;
    }
    final normalizedConceptId = _normalizeConceptId(conceptId);
    if (normalizedConceptId.isEmpty || totalCount <= 0) {
      return null;
    }

    var normalizedProfileId = profileId.trim();
    if (normalizedProfileId.isEmpty) {
      final rows = await db.query(
        'student_profiles',
        columns: ['id'],
        where: 'is_active = 1',
        orderBy: 'updated_at DESC',
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      normalizedProfileId = ('${rows.first['id'] ?? ''}').trim();
      if (normalizedProfileId.isEmpty) {
        return null;
      }
    }

    final sessionMastery = (correctCount / totalCount).clamp(0, 1).toDouble();
    final existingRows = await db.query(
      'concept_mastery',
      columns: ['mastery'],
      where: 'profile_id = ? AND LOWER(concept_id) = LOWER(?)',
      whereArgs: [normalizedProfileId, normalizedConceptId],
      limit: 1,
    );
    final existingMastery = existingRows.isEmpty
        ? null
        : _toOptionalDouble(existingRows.first['mastery']);
    final blendedMastery = existingMastery == null
        ? sessionMastery
        : ((existingMastery.clamp(0, 1).toDouble() * 0.7) +
                (sessionMastery * 0.3))
            .clamp(0, 1)
            .toDouble();

    await db.insert(
      'concept_mastery',
      {
        'profile_id': normalizedProfileId,
        'concept_id': normalizedConceptId,
        'mastery': blendedMastery,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return blendedMastery;
  }

  Future<List<ModuleSuggestion>> recommendModulesByWeakSkills(
    Database db, {
    int weakSkillLimit = 3,
    int modulePerSkill = 2,
    int maxTotal = 8,
  }) async {
    final weakSkills = await loadWeakSkills(db, limit: weakSkillLimit);
    if (weakSkills.isEmpty) {
      return _fallbackModuleSuggestions(db, limit: maxTotal);
    }

    final suggestions = <ModuleSuggestion>[];
    final seen = <String>{};

    for (final weak in weakSkills) {
      final rows = await db.query(
        'book_modules',
        where: 'skills LIKE ?',
        whereArgs: ['%;${weak.skill};%'],
        orderBy: 'volume ASC, materia ASC, modulo ASC',
        limit: modulePerSkill,
      );

      for (final row in rows) {
        final moduleId = (row['id'] ?? '').toString();
        if (moduleId.isEmpty || seen.contains(moduleId)) {
          continue;
        }
        seen.add(moduleId);

        suggestions.add(
          ModuleSuggestion(
            id: moduleId,
            volume: _toInt(row['volume']),
            area: (row['area'] ?? '').toString(),
            materia: (row['materia'] ?? '').toString(),
            modulo: _toInt(row['modulo']),
            title: (row['title'] ?? '').toString(),
            page: (row['page'] ?? '').toString(),
            skillsRaw: (row['skills_raw'] ?? '').toString(),
            matchedSkill: weak.skill,
          ),
        );

        if (suggestions.length >= maxTotal) {
          return suggestions;
        }
      }
    }

    return suggestions;
  }

  Future<List<ModuleSuggestion>> _fallbackModuleSuggestions(
    Database db, {
    int limit = 8,
  }) async {
    final safeLimit = limit <= 0 ? 8 : limit.clamp(1, 20);
    final rows = await db.query(
      'book_modules',
      columns: [
        'id',
        'volume',
        'area',
        'materia',
        'modulo',
        'title',
        'page',
        'skills',
        'skills_raw',
      ],
      where: "TRIM(COALESCE(title, '')) <> ''",
      orderBy: 'volume ASC, materia ASC, modulo ASC',
      limit: safeLimit,
    );

    if (rows.isEmpty) {
      return const [];
    }

    return rows.map((row) {
      final moduleSkill = _extractModulePrimarySkill(row);
      return ModuleSuggestion(
        id: (row['id'] ?? '').toString(),
        volume: _toInt(row['volume']),
        area: (row['area'] ?? '').toString(),
        materia: (row['materia'] ?? '').toString(),
        modulo: _toInt(row['modulo']),
        title: (row['title'] ?? '').toString(),
        page: (row['page'] ?? '').toString(),
        skillsRaw: (row['skills_raw'] ?? '').toString(),
        matchedSkill: moduleSkill,
      );
    }).toList();
  }

  String _extractModulePrimarySkill(Map<String, Object?> row) {
    final skillsRaw = (row['skills_raw'] ?? '').toString();
    final normalizedRaw = skillsRaw.replaceAll(';', ',');
    for (final chunk in normalizedRaw.split(',')) {
      final skill = _normalizeSkillToken(chunk);
      if (skill.isNotEmpty) {
        return skill;
      }
    }

    final skillsBlob = (row['skills'] ?? '').toString();
    final normalizedBlob = skillsBlob.replaceAll(';', ',');
    for (final chunk in normalizedBlob.split(',')) {
      final skill = _normalizeSkillToken(chunk);
      if (skill.isNotEmpty) {
        return skill;
      }
    }

    return '';
  }

  Future<List<StudyBlockSuggestion>> suggestStudyBlocks(
    Database db, {
    int limit = 4,
  }) async {
    final safeLimit = limit <= 0 ? 4 : limit.clamp(1, 20);
    final weakSkills = await loadWeakSkills(db, limit: safeLimit * 3);
    if (weakSkills.isEmpty) {
      return const [];
    }

    final suggestions = <StudyBlockSuggestion>[];
    final seenSkills = <String>{};

    for (final weak in weakSkills) {
      if (!seenSkills.add(weak.skill)) {
        continue;
      }

      final countRows = await db.rawQuery(
        '''
        SELECT COUNT(*) AS c
        FROM questions
        WHERE LOWER(COALESCE(skill, '')) = LOWER(?)
        ''',
        [weak.skill],
      );
      final questionPool = _toInt(
        countRows.isEmpty ? 0 : countRows.first['c'],
      );

      final moduleRows = await db.query(
        'book_modules',
        columns: ['area', 'materia', 'modulo', 'title', 'page'],
        where: 'skills LIKE ?',
        whereArgs: ['%;${weak.skill};%'],
        orderBy: 'volume ASC, materia ASC, modulo ASC',
        limit: 1,
      );

      final module =
          moduleRows.isEmpty ? const <String, Object?>{} : moduleRows.first;
      final accuracy = weak.accuracy;
      int recommendedQuestions;
      int minutesPerQuestion;

      if (accuracy < 0.45) {
        recommendedQuestions = 14;
        minutesPerQuestion = 4;
      } else if (accuracy < 0.65) {
        recommendedQuestions = 10;
        minutesPerQuestion = 3;
      } else {
        recommendedQuestions = 8;
        minutesPerQuestion = 3;
      }

      if (questionPool > 0 && recommendedQuestions > questionPool) {
        recommendedQuestions = questionPool;
      }
      if (recommendedQuestions <= 0) {
        recommendedQuestions = 6;
      }

      suggestions.add(
        StudyBlockSuggestion(
          skill: weak.skill,
          accuracy: accuracy,
          attempts: weak.total,
          correct: weak.correct,
          questionPool: questionPool,
          recommendedQuestions: recommendedQuestions,
          recommendedMinutes: recommendedQuestions * minutesPerQuestion,
          area: (module['area'] ?? '').toString(),
          materia: (module['materia'] ?? '').toString(),
          modulo: _toInt(module['modulo']),
          title: (module['title'] ?? '').toString(),
          page: (module['page'] ?? '').toString(),
        ),
      );

      if (suggestions.length >= safeLimit) {
        break;
      }
    }

    return suggestions;
  }

  Future<List<ModuleQuestionMatch>> searchModuleQuestionMatches(
    Database db, {
    required ModuleQuestionMatchFilter filter,
  }) async {
    final whereClauses = <String>[];
    final args = <Object>[];

    final materia = filter.materia.trim();
    if (materia.isNotEmpty) {
      whereClauses.add('LOWER(m.materia) = LOWER(?)');
      args.add(materia);
    }

    final assunto = filter.assunto.trim().toLowerCase();
    if (assunto.isNotEmpty) {
      whereClauses.add('LOWER(m.assuntos_match) LIKE ?');
      args.add('%$assunto%');
    }

    final tipoMatch = filter.tipoMatch.trim();
    if (tipoMatch.isNotEmpty) {
      whereClauses.add('LOWER(m.tipo_match) = LOWER(?)');
      args.add(tipoMatch);
    }

    if (filter.minScore > 0) {
      whereClauses.add('m.score_match >= ?');
      args.add(filter.minScore);
    }

    final sqlBuffer = StringBuffer()
      ..writeln('SELECT')
      ..writeln('  m.question_id AS question_id,')
      ..writeln('  COALESCE(q.year, m.year) AS year,')
      ..writeln('  COALESCE(q.day, m.day) AS day,')
      ..writeln('  COALESCE(q.number, m.number) AS number,')
      ..writeln('  m.variation AS variation,')
      ..writeln("  COALESCE(q.area, m.area, '') AS area,")
      ..writeln("  COALESCE(q.discipline, m.discipline, '') AS discipline,")
      ..writeln("  COALESCE(m.materia, '') AS materia,")
      ..writeln('  COALESCE(m.volume, 0) AS volume,')
      ..writeln('  COALESCE(m.modulo, 0) AS modulo,')
      ..writeln("  COALESCE(m.competencias, '') AS competencias,")
      ..writeln("  COALESCE(m.habilidades, '') AS habilidades,")
      ..writeln("  COALESCE(m.assuntos_match, '') AS assuntos_match,")
      ..writeln('  COALESCE(m.score_match, 0) AS score_match,')
      ..writeln("  COALESCE(m.tipo_match, '') AS tipo_match,")
      ..writeln("  COALESCE(m.confianca, '') AS confianca,")
      ..writeln('  COALESCE(m.revisado_manual, 0) AS revisado_manual')
      ..writeln('FROM module_question_matches m')
      ..writeln('LEFT JOIN questions q ON q.id = m.question_id');

    if (whereClauses.isNotEmpty) {
      sqlBuffer.writeln('WHERE ${whereClauses.join(' AND ')}');
    }

    sqlBuffer.writeln(
      'ORDER BY m.score_match DESC, m.year DESC, m.day DESC, m.number ASC',
    );
    sqlBuffer.writeln('LIMIT ?');
    args.add(filter.limit <= 0 ? 20 : filter.limit);

    final rows = await db.rawQuery(sqlBuffer.toString(), args);
    return rows
        .map(
          (row) => ModuleQuestionMatch(
            questionId: (row['question_id'] ?? '').toString(),
            year: _toInt(row['year']),
            day: _toInt(row['day']),
            number: _toInt(row['number']),
            variation: _toInt(row['variation']),
            area: (row['area'] ?? '').toString(),
            discipline: (row['discipline'] ?? '').toString(),
            materia: (row['materia'] ?? '').toString(),
            volume: _toInt(row['volume']),
            modulo: _toInt(row['modulo']),
            competencias: (row['competencias'] ?? '').toString(),
            habilidades: (row['habilidades'] ?? '').toString(),
            assuntosMatch: (row['assuntos_match'] ?? '').toString(),
            scoreMatch: _toDouble(row['score_match']),
            tipoMatch: (row['tipo_match'] ?? '').toString(),
            confianca: (row['confianca'] ?? '').toString(),
            revisadoManual: _toBool(row['revisado_manual']),
          ),
        )
        .where((item) => item.questionId.isNotEmpty)
        .toList();
  }

  Future<void> seedLocalDemoIfEmpty(Database db) async {
    if (await countQuestions(db) == 0) {
      const demoBundle = {
        'questions': [
          {
            'id': 'demo_2025_1_001',
            'year': 2025,
            'day': 1,
            'number': 1,
            'variation': 1,
            'area': 'Linguagens',
            'discipline': 'Língua Portuguesa',
            'materia': 'Língua Portuguesa',
            'competency': 'C8',
            'skill': 'H18',
            'difficulty': 'media',
            'has_image': false,
            'text_empty': false,
            'statement':
                'Texto curto de demonstração para validar fluxo offline.',
            'answer': 'B',
            'source': 'demo_local'
          },
          {
            'id': 'demo_2025_2_120',
            'year': 2025,
            'day': 2,
            'number': 120,
            'variation': 1,
            'area': 'Matemática',
            'discipline': 'Matemática',
            'materia': 'Matemática 1',
            'competency': 'C4',
            'skill': 'H16',
            'difficulty': 'dificil',
            'has_image': false,
            'text_empty': false,
            'statement': 'Questão de demonstração para treino de matemática.',
            'answer': 'D',
            'source': 'demo_local'
          },
        ],
        'book_modules': [
          {
            'id': 'demo_mod_1',
            'volume': 1,
            'area': 'Linguagens, Códigos e suas Tecnologias',
            'materia': 'Língua Portuguesa',
            'modulo': 1,
            'title': 'Coesão e coerência',
            'page': '12',
            'skills': ['H18'],
            'skills_raw': 'H18',
            'competencies': ['C8'],
            'competencies_raw': 'C8',
            'learning_expectations': [
              'Compreender mecanismos de coesão textual.',
              'Aplicar estratégias de coerência em produção de texto.'
            ],
            'learning_expectations_raw':
                'Compreender mecanismos de coesão textual.; Aplicar estratégias de coerência em produção de texto.',
            'description':
                'Compreender e aplicar coesão e coerência em textos do cotidiano.',
            'source': 'demo_local'
          },
          {
            'id': 'demo_mod_2',
            'volume': 1,
            'area': 'Matemática e suas Tecnologias',
            'materia': 'Matemática 1',
            'modulo': 2,
            'title': 'Razão e proporção',
            'page': '45',
            'skills': ['H16'],
            'skills_raw': 'H16',
            'competencies': ['C4'],
            'competencies_raw': 'C4',
            'learning_expectations': [
              'Identificar relações de proporcionalidade direta e inversa.',
              'Resolver problemas cotidianos com razão e proporção.'
            ],
            'learning_expectations_raw':
                'Identificar relações de proporcionalidade direta e inversa.; Resolver problemas cotidianos com razão e proporção.',
            'description':
                'Resolver situações-problema com proporcionalidade direta e inversa.',
            'source': 'demo_local'
          },
        ],
        'module_question_matches': [
          {
            'question_id': 'demo_2025_1_001',
            'year': 2025,
            'day': 1,
            'number': 1,
            'variation': 1,
            'area': 'Linguagens',
            'discipline': 'Língua Portuguesa',
            'materia': 'Língua Portuguesa',
            'volume': 1,
            'modulo': 1,
            'competencias': 'C8',
            'habilidades': 'H18',
            'assuntos_match': 'coesao; coerencia',
            'score_match': 0.82,
            'tipo_match': 'direto',
            'confianca': 'alta',
            'revisado_manual': true,
            'source': 'demo_local'
          },
          {
            'question_id': 'demo_2025_2_120',
            'year': 2025,
            'day': 2,
            'number': 120,
            'variation': 1,
            'area': 'Matemática',
            'discipline': 'Matemática',
            'materia': 'Matemática 1',
            'volume': 1,
            'modulo': 2,
            'competencias': 'C4',
            'habilidades': 'H16',
            'assuntos_match': 'razao; proporcao',
            'score_match': 0.79,
            'tipo_match': 'direto',
            'confianca': 'alta',
            'revisado_manual': true,
            'source': 'demo_local'
          },
        ],
        'concepts': [
          {
            'id': 'geral_leitura_comando',
            'label': 'Leitura de comando',
            'area': 'Transversal',
            'difficulty': 'basico',
            'source': 'demo_local'
          },
          {
            'id': 'mat_razao_proporcao',
            'label': 'Razão e proporção',
            'area': 'Matemática',
            'difficulty': 'basico',
            'source': 'demo_local'
          },
        ],
        'question_concepts': [
          {
            'question_id': 'demo_2025_1_001',
            'concept_id': 'geral_leitura_comando',
            'weight': 0.7,
            'source': 'demo_local'
          },
          {
            'question_id': 'demo_2025_2_120',
            'concept_id': 'mat_razao_proporcao',
            'weight': 0.9,
            'source': 'demo_local'
          },
        ],
        'concept_dependencies': [
          {
            'concept_id': 'mat_razao_proporcao',
            'depends_on': 'geral_leitura_comando',
            'strength': 0.4,
            'source': 'demo_local'
          },
        ],
        'concept_priority_weights': [
          {
            'concept_id': 'geral_leitura_comando',
            'base_weight': 1.5,
            'reason': 'fundacional_transversal',
            'source': 'demo_local'
          },
          {
            'concept_id': 'mat_razao_proporcao',
            'base_weight': 1.3,
            'reason': 'fundacional_matematica',
            'source': 'demo_local'
          },
        ],
      };

      await upsertBundle(db, demoBundle);
      await setContentVersion(db, 'demo-local');
    }
  }
}
