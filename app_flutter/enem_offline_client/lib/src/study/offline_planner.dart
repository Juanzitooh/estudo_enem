import '../data/local_database.dart';

class OfflinePlanSlot {
  const OfflinePlanSlot({
    required this.skill,
    required this.band,
    required this.minutes,
    required this.reason,
  });

  final String skill;
  final String band;
  final int minutes;
  final String reason;

  Map<String, dynamic> toMap() {
    return {
      'skill': skill,
      'band': band,
      'minutes': minutes,
      'reason': reason,
    };
  }

  static OfflinePlanSlot fromMap(Map<String, dynamic> map) {
    return OfflinePlanSlot(
      skill: (map['skill'] ?? '').toString(),
      band: (map['band'] ?? '').toString(),
      minutes: int.tryParse('${map['minutes'] ?? 0}') ?? 0,
      reason: (map['reason'] ?? '').toString(),
    );
  }
}

class OfflinePlanDay {
  const OfflinePlanDay({
    required this.dateIso,
    required this.dateLabel,
    required this.totalMinutes,
    required this.slots,
  });

  final String dateIso;
  final String dateLabel;
  final int totalMinutes;
  final List<OfflinePlanSlot> slots;

  Map<String, dynamic> toMap() {
    return {
      'date_iso': dateIso,
      'date_label': dateLabel,
      'total_minutes': totalMinutes,
      'slots': slots.map((item) => item.toMap()).toList(),
    };
  }

  static OfflinePlanDay fromMap(Map<String, dynamic> map) {
    final rawSlots = (map['slots'] as List<dynamic>? ?? const []);
    return OfflinePlanDay(
      dateIso: (map['date_iso'] ?? '').toString(),
      dateLabel: (map['date_label'] ?? '').toString(),
      totalMinutes: int.tryParse('${map['total_minutes'] ?? 0}') ?? 0,
      slots: rawSlots
          .whereType<Map<String, dynamic>>()
          .map(OfflinePlanSlot.fromMap)
          .toList(),
    );
  }
}

class OfflinePlanForecast {
  const OfflinePlanForecast({
    required this.generatedAtIso,
    required this.weeklyCapacityHours,
    required this.weeklyRequiredHours,
    required this.riskLabel,
    required this.note,
    required this.days,
  });

  final String generatedAtIso;
  final double weeklyCapacityHours;
  final double weeklyRequiredHours;
  final String riskLabel;
  final String note;
  final List<OfflinePlanDay> days;

  static const empty = OfflinePlanForecast(
    generatedAtIso: '',
    weeklyCapacityHours: 0,
    weeklyRequiredHours: 0,
    riskLabel: 'n/a',
    note: 'Sem plano calculado.',
    days: <OfflinePlanDay>[],
  );

  Map<String, dynamic> toMap() {
    return {
      'generated_at': generatedAtIso,
      'weekly_capacity_hours': weeklyCapacityHours,
      'weekly_required_hours': weeklyRequiredHours,
      'risk_label': riskLabel,
      'note': note,
      'days': days.map((item) => item.toMap()).toList(),
    };
  }

  static OfflinePlanForecast fromMap(Map<String, dynamic> map) {
    final rawDays = (map['days'] as List<dynamic>? ?? const []);
    return OfflinePlanForecast(
      generatedAtIso: (map['generated_at'] ?? '').toString(),
      weeklyCapacityHours:
          double.tryParse('${map['weekly_capacity_hours'] ?? 0}') ?? 0,
      weeklyRequiredHours:
          double.tryParse('${map['weekly_required_hours'] ?? 0}') ?? 0,
      riskLabel: (map['risk_label'] ?? 'n/a').toString(),
      note: (map['note'] ?? '').toString(),
      days: rawDays
          .whereType<Map<String, dynamic>>()
          .map(OfflinePlanDay.fromMap)
          .toList(),
    );
  }
}

class OfflinePlannerEngine {
  const OfflinePlannerEngine._();

  static OfflinePlanForecast build({
    required DateTime now,
    required StudentProfileRecord? profile,
    required List<SkillPriorityItem> priorities,
    int horizonDays = 7,
  }) {
    if (profile == null) {
      return const OfflinePlanForecast(
        generatedAtIso: '',
        weeklyCapacityHours: 0,
        weeklyRequiredHours: 0,
        riskLabel: 'n/a',
        note: 'Cadastre um perfil para gerar planejamento.',
        days: <OfflinePlanDay>[],
      );
    }

    final hoursPerDay = (profile.hoursPerDay ?? 2).clamp(0.5, 8.0);
    final weekdays = _parseWeekdays(profile.studyDaysCsv);
    final dates = _buildStudyDates(
      from: now,
      weekdays: weekdays,
      maxDays: horizonDays.clamp(1, 14),
    );

    final skillPool = priorities.isEmpty
        ? <SkillPriorityItem>[
            const SkillPriorityItem(
              skill: 'Revisão geral',
              accuracy: 0,
              attempts: 0,
              daysSinceLastSeen: 0,
              deficit: 1,
              recency: 0,
              confidence: 0,
              priorityScore: 1,
              band: 'foco',
            ),
          ]
        : priorities.take(12).toList();

    final planDays = <OfflinePlanDay>[];
    for (var dayIndex = 0; dayIndex < dates.length; dayIndex++) {
      final totalMinutes = (hoursPerDay * 60).round().clamp(30, 360);
      final blockCount = (totalMinutes ~/ 30).clamp(1, 8);
      final slotMinutes = <String, int>{};
      final slotBand = <String, String>{};
      final slotReason = <String, String>{};

      for (var block = 0; block < blockCount; block++) {
        final skillIndex = (dayIndex * 2 + block) % skillPool.length;
        final item = skillPool[skillIndex];
        slotMinutes[item.skill] = (slotMinutes[item.skill] ?? 0) + 30;
        slotBand[item.skill] = item.band;
        slotReason[item.skill] = _reasonForBand(item.band);
      }

      final slots = slotMinutes.entries
          .map(
            (entry) => OfflinePlanSlot(
              skill: entry.key,
              band: slotBand[entry.key] ?? 'foco',
              minutes: entry.value,
              reason: slotReason[entry.key] ?? 'Revisão programada',
            ),
          )
          .toList()
        ..sort((a, b) => b.minutes.compareTo(a.minutes));

      final date = dates[dayIndex];
      planDays.add(
        OfflinePlanDay(
          dateIso: date.toIso8601String(),
          dateLabel:
              '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          totalMinutes: totalMinutes,
          slots: slots,
        ),
      );
    }

    final weeklyCapacityHours = planDays.length * hoursPerDay;
    final weeklyRequiredHours = _estimateWeeklyRequiredHours(skillPool);
    final riskLabel = _riskLabel(
      capacityHours: weeklyCapacityHours,
      requiredHours: weeklyRequiredHours,
    );
    final examNote = _examNote(now: now, examDateIso: profile.examDate);

    return OfflinePlanForecast(
      generatedAtIso: now.toIso8601String(),
      weeklyCapacityHours: weeklyCapacityHours,
      weeklyRequiredHours: weeklyRequiredHours,
      riskLabel: riskLabel,
      note: examNote,
      days: planDays,
    );
  }

  static String _reasonForBand(String band) {
    final normalized = band.trim().toLowerCase();
    if (normalized == 'foco') {
      return 'Prioridade alta por lacuna de desempenho';
    }
    if (normalized == 'manutencao') {
      return 'Consolidar habilidade com prática leve';
    }
    return 'Manter domínio com revisão espaçada';
  }

  static Set<int> _parseWeekdays(String rawCsv) {
    final map = <String, int>{
      'seg': DateTime.monday,
      'segunda': DateTime.monday,
      'ter': DateTime.tuesday,
      'terca': DateTime.tuesday,
      'terça': DateTime.tuesday,
      'qua': DateTime.wednesday,
      'quarta': DateTime.wednesday,
      'qui': DateTime.thursday,
      'quinta': DateTime.thursday,
      'sex': DateTime.friday,
      'sexta': DateTime.friday,
      'sab': DateTime.saturday,
      'sabado': DateTime.saturday,
      'sábado': DateTime.saturday,
      'dom': DateTime.sunday,
      'domingo': DateTime.sunday,
    };

    final normalized = rawCsv.trim().toLowerCase();
    if (normalized.isEmpty) {
      return {1, 2, 3, 4, 5, 6, 7};
    }

    final result = <int>{};
    for (final chunk in normalized.split(',')) {
      final token = chunk.trim();
      if (token.isEmpty) {
        continue;
      }
      final value = map[token] ?? int.tryParse(token);
      if (value == null) {
        continue;
      }
      if (value >= 1 && value <= 7) {
        result.add(value);
      }
    }
    if (result.isEmpty) {
      return {1, 2, 3, 4, 5, 6, 7};
    }
    return result;
  }

  static List<DateTime> _buildStudyDates({
    required DateTime from,
    required Set<int> weekdays,
    required int maxDays,
  }) {
    final result = <DateTime>[];
    var cursor = DateTime(from.year, from.month, from.day).add(
      const Duration(days: 1),
    );
    var guard = 0;
    while (result.length < maxDays && guard < 40) {
      guard++;
      if (weekdays.contains(cursor.weekday)) {
        result.add(cursor);
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return result;
  }

  static double _estimateWeeklyRequiredHours(
      List<SkillPriorityItem> priorities) {
    if (priorities.isEmpty) {
      return 0;
    }
    var total = 0.0;
    for (final item in priorities.take(8)) {
      final normalizedBand = item.band.trim().toLowerCase();
      final baseHours = normalizedBand == 'foco'
          ? 3.0
          : normalizedBand == 'manutencao'
              ? 1.5
              : 0.75;
      final factor = (0.8 + item.priorityScore.clamp(0, 1.2)).toDouble();
      total += baseHours * factor;
    }
    return total;
  }

  static String _riskLabel({
    required double capacityHours,
    required double requiredHours,
  }) {
    if (requiredHours <= 0) {
      return 'baixo';
    }
    if (capacityHours >= requiredHours) {
      return 'baixo';
    }
    if (capacityHours >= requiredHours * 0.75) {
      return 'medio';
    }
    return 'alto';
  }

  static String _examNote({
    required DateTime now,
    required String examDateIso,
  }) {
    final raw = examDateIso.trim();
    if (raw.isEmpty) {
      return 'Sem data de prova informada; previsão calculada por semana.';
    }
    final examDate = DateTime.tryParse(raw);
    if (examDate == null) {
      return 'Data de prova inválida no perfil; use formato YYYY-MM-DD.';
    }
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(examDate.year, examDate.month, examDate.day);
    final days = target.difference(today).inDays;
    if (days < 0) {
      return 'Data da prova está no passado. Atualize para recalcular a previsão.';
    }
    return 'Faltam $days dia(s) até a prova.';
  }
}
