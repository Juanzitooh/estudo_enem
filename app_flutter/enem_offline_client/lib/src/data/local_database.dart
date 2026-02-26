import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../config/app_config.dart';

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

class LocalDatabase {
  LocalDatabase();

  bool _ffiInitialized = false;
  String? _databasePath;

  Future<Database> open() async {
    _ensureDesktopDriver();
    final dbPath = await databasePath();

    return openDatabase(
      dbPath,
      version: 7,
      onCreate: (db, _) async {
        await _createSchemaV7(db);
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
        area TEXT NOT NULL,
        discipline TEXT,
        skill TEXT,
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

  void _ensureDesktopDriver() {
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
        final fallbackImagePaths = _extractFallbackImagePaths(
          item['fallback_image_paths'],
        );
        var statement = (item['statement'] ?? '').toString().trim();
        if (statement.isEmpty && fallbackImagePaths.isNotEmpty) {
          statement = 'Texto OCR indisponível (usar imagem fallback).';
        }
        if (questionId.isEmpty || statement.isEmpty) {
          continue;
        }

        await txn.insert(
          'questions',
          {
            'id': questionId,
            'year': int.tryParse('${item['year']}') ?? 0,
            'day': int.tryParse('${item['day']}') ?? 0,
            'number': int.tryParse('${item['number']}') ?? 0,
            'area': (item['area'] ?? '').toString(),
            'discipline': (item['discipline'] ?? '').toString(),
            'skill': _normalizeSkillToken((item['skill'] ?? '').toString()),
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

  Future<void> recordAnswer(
    Database db, {
    required String questionId,
    required bool isCorrect,
    DateTime? answeredAt,
  }) async {
    await db.insert(
      'progress',
      {
        'question_id': questionId,
        'is_correct': isCorrect ? 1 : 0,
        'answered_at': (answeredAt ?? DateTime.now()).toIso8601String(),
      },
    );
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
    await recordAnswer(db, questionId: questionId, isCorrect: isCorrect);
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

  Future<List<ModuleSuggestion>> recommendModulesByWeakSkills(
    Database db, {
    int weakSkillLimit = 3,
    int modulePerSkill = 2,
    int maxTotal = 8,
  }) async {
    final weakSkills = await loadWeakSkills(db, limit: weakSkillLimit);
    if (weakSkills.isEmpty) {
      return const [];
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
            'area': 'Linguagens',
            'discipline': 'Língua Portuguesa',
            'skill': 'H18',
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
            'area': 'Matemática',
            'discipline': 'Matemática',
            'skill': 'H16',
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
      };

      await upsertBundle(db, demoBundle);
      await setContentVersion(db, 'demo-local');
    }
  }
}
