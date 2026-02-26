class EssayPromptBuilder {
  EssayPromptBuilder._();

  static const List<String> officialThemes2015To2025 = [
    'A persistência da violência contra a mulher na sociedade brasileira',
    'Caminhos para combater a intolerância religiosa no Brasil',
    'Desafios para a formação educacional de surdos no Brasil',
    'Manipulação do comportamento do usuário pelo controle de dados na internet',
    'Democratização do acesso ao cinema no Brasil',
    'O estigma associado às doenças mentais na sociedade brasileira',
    'Invisibilidade e registro civil: garantia de acesso à cidadania no Brasil',
    'Desafios para a valorização de comunidades e povos tradicionais no Brasil',
    'Desafios para o enfrentamento da invisibilidade do trabalho de cuidado realizado pela mulher no Brasil',
    'Desafios para a valorização da herança africana no Brasil',
    'Perspectivas acerca do envelhecimento na sociedade brasileira',
  ];

  static String buildThemeGenerationPrompt({
    String focusHint = '',
    List<String> blockedThemes = officialThemes2015To2025,
  }) {
    final focus = focusHint.trim();
    final blockedList = blockedThemes
        .where((item) => item.trim().isNotEmpty)
        .map((item) => '- ${item.trim()}')
        .join('\n');

    return '''
Crie 1 tema inédito de redação no estilo ENEM.

Regras:
- O tema deve tratar de problema social brasileiro atual.
- Deve permitir proposta de intervenção.
- Não repetir nem parafrasear temas oficiais listados abaixo.
- Linguagem clara e nível ENEM.
- Entregue no formato:
1) Tema (título)
2) Texto motivador 1 (informativo)
3) Texto motivador 2 (opinião crítica)
4) Dado/exemplo contextual
5) Proposta de redação para o candidato

Temas oficiais para bloquear:
$blockedList

${focus.isEmpty ? '' : 'Preferência de recorte temático do aluno: $focus'}
'''
        .trim();
  }

  static String buildCorrectionPrompt({
    required String themeTitle,
    String studentContext = '',
  }) {
    final normalizedTheme = themeTitle.trim();
    final context = studentContext.trim();

    return '''
Você é corretor no estilo ENEM.

Vou enviar a foto de uma redação manuscrita.

Tema da redação:
$normalizedTheme

${context.isEmpty ? '' : 'Contexto do aluno: $context\n'}
Tarefas:
1) Transcreva o texto fielmente. Marque trechos ilegíveis como [ILEGÍVEL].
2) Avalie as 5 competências (C1 a C5), com nota de 0 a 200 cada.
3) Justifique objetivamente cada competência.
4) Liste 5 melhorias prioritárias.
5) Liste 5 erros gramaticais detectados (quando houver).
6) Reescreva a introdução e a proposta de intervenção mantendo a ideia do aluno.
7) Informe a nota final estimada (0 a 1000).

Formato obrigatório da saída:
C1: <nota> - <justificativa>
C2: <nota> - <justificativa>
C3: <nota> - <justificativa>
C4: <nota> - <justificativa>
C5: <nota> - <justificativa>
NOTA_FINAL: <0-1000>
MELHORIAS:
- ...
ERROS_GRAMATICAIS:
- ...
'''
        .trim();
  }
}
