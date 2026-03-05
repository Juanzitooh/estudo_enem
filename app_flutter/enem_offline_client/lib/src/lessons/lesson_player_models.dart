class LessonOptionData {
  const LessonOptionData({
    required this.id,
    required this.text,
  });

  final String id;
  final String text;

  factory LessonOptionData.fromJson(Map<String, dynamic> json) {
    return LessonOptionData(
      id: (json['id'] ?? '').toString().trim().toUpperCase(),
      text: (json['text'] ?? '').toString().trim(),
    );
  }
}

class LessonQuestionData {
  const LessonQuestionData({
    required this.id,
    required this.level,
    required this.statement,
    required this.options,
    required this.answer,
    required this.commentary,
    required this.sourceQuestionId,
  });

  final String id;
  final String level;
  final String statement;
  final List<LessonOptionData> options;
  final String answer;
  final String commentary;
  final String sourceQuestionId;

  factory LessonQuestionData.fromJson(Map<String, dynamic> json) {
    final rawOptions = (json['options'] as List<dynamic>? ?? const []);
    return LessonQuestionData(
      id: (json['id'] ?? '').toString().trim(),
      level: (json['level'] ?? '').toString().trim(),
      statement: (json['statement'] ?? '').toString().trim(),
      options: rawOptions
          .whereType<Map<String, dynamic>>()
          .map(LessonOptionData.fromJson)
          .toList(growable: false),
      answer: (json['answer'] ?? '').toString().trim().toUpperCase(),
      commentary: (json['commentary'] ?? '').toString().trim(),
      sourceQuestionId: (json['source_question_id'] ?? '').toString().trim(),
    );
  }
}

class LessonCurrentEventData {
  const LessonCurrentEventData({
    required this.date,
    required this.title,
    required this.description,
  });

  final String date;
  final String title;
  final String description;

  factory LessonCurrentEventData.fromJson(Map<String, dynamic> json) {
    return LessonCurrentEventData(
      date: (json['date'] ?? '').toString().trim(),
      title: (json['title'] ?? '').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
    );
  }
}

class LessonCurrentContextData {
  const LessonCurrentContextData({
    required this.window,
    required this.events,
    required this.connection,
    required this.brazilCut,
  });

  final String window;
  final List<LessonCurrentEventData> events;
  final String connection;
  final String brazilCut;

  factory LessonCurrentContextData.fromJson(Map<String, dynamic> json) {
    final rawEvents = (json['events'] as List<dynamic>? ?? const []);
    return LessonCurrentContextData(
      window: (json['window'] ?? '').toString().trim(),
      events: rawEvents
          .whereType<Map<String, dynamic>>()
          .map(LessonCurrentEventData.fromJson)
          .toList(growable: false),
      connection: (json['connection'] ?? '').toString().trim(),
      brazilCut: (json['brazil_cut'] ?? '').toString().trim(),
    );
  }
}

class LessonPracticalExampleData {
  const LessonPracticalExampleData({
    required this.title,
    required this.kind,
    required this.scenario,
    required this.application,
    required this.conclusion,
  });

  final String title;
  final String kind;
  final String scenario;
  final String application;
  final String conclusion;

  factory LessonPracticalExampleData.fromJson(Map<String, dynamic> json) {
    return LessonPracticalExampleData(
      title: (json['title'] ?? '').toString().trim(),
      kind: (json['kind'] ?? '').toString().trim(),
      scenario: (json['scenario'] ?? '').toString().trim(),
      application: (json['application'] ?? '').toString().trim(),
      conclusion: (json['conclusion'] ?? '').toString().trim(),
    );
  }
}

class LessonCaseStudyData {
  const LessonCaseStudyData({
    required this.situation,
    required this.reflectionQuestions,
  });

  final String situation;
  final List<String> reflectionQuestions;

  factory LessonCaseStudyData.fromJson(Map<String, dynamic> json) {
    final rawQuestions =
        (json['reflection_questions'] as List<dynamic>? ?? const []);
    return LessonCaseStudyData(
      situation: (json['situation'] ?? '').toString().trim(),
      reflectionQuestions: rawQuestions
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class LessonDeepeningData {
  const LessonDeepeningData({
    required this.goal,
    required this.videoKeywords,
  });

  final String goal;
  final List<String> videoKeywords;

  factory LessonDeepeningData.fromJson(Map<String, dynamic> json) {
    final rawKeywords = (json['video_keywords'] as List<dynamic>? ?? const []);
    return LessonDeepeningData(
      goal: (json['goal'] ?? '').toString().trim(),
      videoKeywords: rawKeywords
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class LessonPlayerData {
  const LessonPlayerData({
    required this.id,
    required this.version,
    required this.title,
    required this.area,
    required this.materia,
    required this.volume,
    required this.modulo,
    required this.learningExpectations,
    required this.competencies,
    required this.currentContext,
    required this.concepts,
    required this.resolutionSteps,
    required this.enemPatterns,
    required this.examples,
    required this.caseStudy,
    required this.deepening,
    required this.quickCheck,
    required this.summary,
    required this.questions,
  });

  final String id;
  final String version;
  final String title;
  final String area;
  final String materia;
  final int volume;
  final int modulo;
  final List<String> learningExpectations;
  final List<String> competencies;
  final LessonCurrentContextData? currentContext;
  final List<String> concepts;
  final List<String> resolutionSteps;
  final List<String> enemPatterns;
  final List<LessonPracticalExampleData> examples;
  final LessonCaseStudyData? caseStudy;
  final LessonDeepeningData? deepening;
  final List<String> quickCheck;
  final String summary;
  final List<LessonQuestionData> questions;

  factory LessonPlayerData.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(String key) {
      final values = (json[key] as List<dynamic>? ?? const []);
      return values
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    final rawQuestions = (json['questions'] as List<dynamic>? ?? const []);
    final rawExamples = (json['examples'] as List<dynamic>? ?? const []);
    final contextPayload = json['context_12m'];
    final caseStudyPayload = json['case_study'];
    final deepeningPayload = json['deepening'];

    return LessonPlayerData(
      id: (json['id'] ?? '').toString().trim(),
      version: (json['version'] ?? '1').toString().trim(),
      title: (json['title'] ?? '').toString().trim(),
      area: (json['area'] ?? '').toString().trim(),
      materia: (json['materia'] ?? '').toString().trim(),
      volume: int.tryParse('${json['volume']}') ?? 0,
      modulo: int.tryParse('${json['modulo']}') ?? 0,
      learningExpectations: parseStringList('learning_expectations'),
      competencies: parseStringList('competencies'),
      currentContext: contextPayload is Map<String, dynamic>
          ? LessonCurrentContextData.fromJson(contextPayload)
          : null,
      concepts: parseStringList('concepts'),
      resolutionSteps: parseStringList('resolution_steps'),
      enemPatterns: parseStringList('enem_patterns'),
      examples: rawExamples
          .whereType<Map<String, dynamic>>()
          .map(LessonPracticalExampleData.fromJson)
          .toList(growable: false),
      caseStudy: caseStudyPayload is Map<String, dynamic>
          ? LessonCaseStudyData.fromJson(caseStudyPayload)
          : null,
      deepening: deepeningPayload is Map<String, dynamic>
          ? LessonDeepeningData.fromJson(deepeningPayload)
          : null,
      quickCheck: parseStringList('quick_check'),
      summary: (json['summary'] ?? '').toString().trim(),
      questions: rawQuestions
          .whereType<Map<String, dynamic>>()
          .map(LessonQuestionData.fromJson)
          .toList(growable: false),
    );
  }
}
