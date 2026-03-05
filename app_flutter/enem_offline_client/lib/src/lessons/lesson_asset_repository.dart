import 'dart:convert';

import 'package:flutter/services.dart';

import 'lesson_player_models.dart';

class LessonAssetRepository {
  const LessonAssetRepository();

  Future<LessonPlayerData> loadLesson(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final payload = jsonDecode(raw);
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Payload de aula inválido.');
    }
    return LessonPlayerData.fromJson(payload);
  }
}
