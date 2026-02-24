import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

class LocalDatabase {
  LocalDatabase();

  bool _ffiInitialized = false;

  Future<Database> open() async {
    _ensureDesktopDriver();
    final supportDir = await getApplicationSupportDirectory();
    final dbPath = path.join(supportDir.path, 'enem_offline.db');

    return openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, _) async {
        await _createSchemaV2(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
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
              source TEXT
            )
          ''');
        }
      },
    );
  }

  Future<void> _createSchemaV2(Database db) async {
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

    await db.execute('''
      CREATE TABLE book_modules (
        id TEXT PRIMARY KEY,
        volume INTEGER NOT NULL,
        area TEXT,
        materia TEXT,
        modulo INTEGER,
        title TEXT,
        page TEXT,
        skills TEXT,
        skills_raw TEXT,
        source TEXT
      )
    ''');

    await db.insert(
      'app_meta',
      {'key': 'content_version', 'value': '0'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

  String _normalizeSkillToken(String rawValue) {
    final token = rawValue.trim().toUpperCase().replaceAll(' ', '');
    if (token.isEmpty) {
      return '';
    }
    if (token.startsWith('H') && int.tryParse(token.substring(1)) != null) {
      return 'H${int.parse(token.substring(1))}';
    }

    final marker = '-H';
    if (token.contains(marker)) {
      final tail = token.split(marker).last;
      final digits = tail.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        return 'H${int.parse(digits)}';
      }
    }

    return token;
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

  Future<int> countQuestions(Database db) async {
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM questions');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countBookModules(Database db) async {
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM book_modules');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countAttempts(Database db) async {
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM progress');
    return Sqflite.firstIntValue(result) ?? 0;
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
        final statement = (item['statement'] ?? '').toString().trim();
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
            'source': (item['source'] ?? '').toString(),
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

  Future<List<WeakSkillStat>> loadWeakSkills(Database db, {int limit = 5}) async {
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
            'statement': 'Texto curto de demonstração para validar fluxo offline.',
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
            'source': 'demo_local'
          },
        ]
      };

      await upsertBundle(db, demoBundle);
      await setContentVersion(db, 'demo-local');
    }
  }
}
