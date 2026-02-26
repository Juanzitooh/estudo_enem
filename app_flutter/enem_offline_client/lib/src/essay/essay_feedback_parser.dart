enum EssayParserMode {
  livre,
  validado;

  static EssayParserMode fromValue(String rawValue) {
    final normalized = rawValue.trim().toLowerCase();
    if (normalized == 'validado') {
      return EssayParserMode.validado;
    }
    return EssayParserMode.livre;
  }

  String get value => this == EssayParserMode.validado ? 'validado' : 'livre';
}

class EssayFeedbackParseResult {
  const EssayFeedbackParseResult({
    required this.mode,
    required this.rawFeedback,
    required this.isValid,
    required this.illegibleCount,
    this.c1,
    this.c2,
    this.c3,
    this.c4,
    this.c5,
    this.finalScore,
  });

  final EssayParserMode mode;
  final String rawFeedback;
  final bool isValid;
  final int illegibleCount;
  final int? c1;
  final int? c2;
  final int? c3;
  final int? c4;
  final int? c5;
  final int? finalScore;

  bool get hasLegibilityWarning => illegibleCount >= 3;
}

class EssayFeedbackParser {
  EssayFeedbackParser._();

  static final RegExp _scoreRegexByCompetency = RegExp(
    r'^\s*C([1-5])\s*[:=-]\s*(\d{1,3})\b',
    caseSensitive: false,
    multiLine: true,
  );
  static final RegExp _finalScoreRegex = RegExp(
    r'^\s*(?:NOTA[_\s-]*FINAL|NOTA\s+TOTAL)\s*[:=-]\s*(\d{1,4})\b',
    caseSensitive: false,
    multiLine: true,
  );
  static final RegExp _illegibleRegex = RegExp(
    r'\[ILEG[IÍ]VEL\]',
    caseSensitive: false,
  );

  static EssayFeedbackParseResult parse({
    required String rawFeedback,
    required EssayParserMode mode,
  }) {
    final cleaned = rawFeedback.trim();
    final illegibleCount = _illegibleRegex.allMatches(cleaned).length;

    final extracted = <int, int>{};
    for (final match in _scoreRegexByCompetency.allMatches(cleaned)) {
      final competency = int.tryParse(match.group(1) ?? '');
      final score = int.tryParse(match.group(2) ?? '');
      if (competency == null || score == null) {
        continue;
      }
      extracted[competency] = _clamp(score, min: 0, max: 200);
    }

    final finalScoreMatch = _finalScoreRegex.firstMatch(cleaned);
    final parsedFinalScore = int.tryParse(finalScoreMatch?.group(1) ?? '');
    final finalScore = parsedFinalScore == null
        ? null
        : _clamp(parsedFinalScore, min: 0, max: 1000);

    final hasAllCompetencies = extracted.containsKey(1) &&
        extracted.containsKey(2) &&
        extracted.containsKey(3) &&
        extracted.containsKey(4) &&
        extracted.containsKey(5);

    final isValid = mode == EssayParserMode.livre
        ? cleaned.isNotEmpty
        : (cleaned.isNotEmpty && hasAllCompetencies);

    return EssayFeedbackParseResult(
      mode: mode,
      rawFeedback: rawFeedback,
      isValid: isValid,
      illegibleCount: illegibleCount,
      c1: extracted[1],
      c2: extracted[2],
      c3: extracted[3],
      c4: extracted[4],
      c5: extracted[5],
      finalScore: finalScore,
    );
  }

  static int _clamp(int value, {required int min, required int max}) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }
}
