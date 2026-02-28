class StudyPromptBuilder {
  StudyPromptBuilder._();

  static String buildFullLessonPrompt({
    required String skillCode,
    required String area,
    required String moduleTitle,
    required double accuracy,
    required int attempts,
    required String errorReason,
    required String topicHint,
    required String pacing,
    required String levelBreak,
    required List<String> topicTags,
    required String pattern,
  }) {
    final safeArea = area.trim().isEmpty ? 'Não informado' : area.trim();
    final safeModule =
        moduleTitle.trim().isEmpty ? 'Não informado' : moduleTitle.trim();
    final safeTopic =
        topicHint.trim().isEmpty ? 'Não informado' : topicHint.trim();
    final safePacing = pacing.trim().isEmpty ? 'indefinido' : pacing.trim();
    final safeLevelBreak =
        levelBreak.trim().isEmpty ? 'indefinido' : levelBreak.trim();
    final safePattern = pattern.trim().isEmpty ? 'aleatorio' : pattern.trim();
    final safeTopicTags =
        topicTags.isEmpty ? 'não identificado' : topicTags.join(', ');
    final accuracyPercent = (accuracy * 100).toStringAsFixed(1);

    return '''
Sou estudante do ENEM e preciso reforçar uma habilidade em déficit.

Habilidade: $skillCode
Área: $safeArea
Módulo sugerido: $safeModule
Desempenho atual: $accuracyPercent% de acerto em $attempts tentativa(s)
Causa provável do erro: $errorReason
Tópico relacionado: $safeTopic

Perfil de erro local:
- pacing: $safePacing
- level_break: $safeLevelBreak
- topic_tags: $safeTopicTags
- pattern: $safePattern

Quero que você:
1) Explique o conteúdo do zero até nível ENEM.
2) Mostre os erros mais comuns e como evitar.
3) Dê uma heurística prática para identificar esse tipo de questão.
4) Resolva 3 exemplos progressivos (fácil, médio, difícil).
5) Monte um plano de revisão de 30 minutos + 3 dias.
6) Gere 10 perguntas de treino sem alternativas.

Observação: não forneça gabarito de questões reais; foque no raciocínio.
'''
        .trim();
  }

  static String buildVideosPrompt({
    required String skillCode,
    required String area,
    required String topicHint,
  }) {
    final safeArea = area.trim().isEmpty ? 'Não informado' : area.trim();
    final safeTopic =
        topicHint.trim().isEmpty ? 'Não informado' : topicHint.trim();
    return '''
Preciso estudar para o ENEM.

Habilidade: $skillCode
Área: $safeArea
Tópico foco: $safeTopic

Me dê:
- 10 palavras-chave específicas para buscar no YouTube
- 8 títulos prováveis de vídeo (sem links)
- ordem sugerida de estudo em 1 hora
- 3 sinais para validar se o vídeo é bom para ENEM
'''
        .trim();
  }

  static String buildPracticePrompt({
    required String skillCode,
    required String area,
    required String topicHint,
  }) {
    final safeArea = area.trim().isEmpty ? 'Não informado' : area.trim();
    final safeTopic =
        topicHint.trim().isEmpty ? 'Não informado' : topicHint.trim();
    return '''
Crie um treino progressivo para ENEM.

Habilidade: $skillCode
Área: $safeArea
Tópico foco: $safeTopic

Requisitos:
- 12 questões autorais sem alternativas (4 fáceis, 4 médias, 4 difíceis)
- cada questão deve focar no mesmo núcleo de habilidade
- após cada questão, inclua critérios de correção (não o gabarito final)
- ao final, crie checklist de revisão em 15 minutos
'''
        .trim();
  }
}
