# Decisions (ADR leve)

## D-001 - Planejamento canônico em `docs/roadmap`
Data: 2026-03-04
Status: aceito
Contexto: roadmap estava distribuído em arquivos de `plano/` sem camada canônica para execução por agentes.
Decisão: adotar protocolo global com arquivos canônicos em `docs/roadmap/` e manter `plano/` como histórico detalhado.
Impacto: execução mais previsível por milestone/task, sem perda de contexto legado.

## D-002 - Preservar `plano/` como fonte histórica
Data: 2026-03-04
Status: aceito
Contexto: existe histórico consolidado em `plano/roadmap_geral.md` e `plano/roadmap_proximos_passos.md`.
Decisão: não migrar/apagar histórico; usar `docs/roadmap/` como ponte operacional e manter links bidirecionais.
Impacto: evita retrabalho documental e mantém rastreabilidade de decisões antigas.

## D-003 - Priorização atual em M3
Data: 2026-03-04
Status: aceito
Contexto: bloco 7 está operacionalmente mais próximo de fechamento sem depender de release.
Decisão: definir `CURRENT_MILESTONE=M3` e `NEXT_TASK=T3.1`.
Impacto: foco em qualidade pedagógica e redução de retrabalho antes de avançar para vídeo/Android.

## D-004 - Trilha incremental de feed por conceito (grafo)
Data: 2026-03-05
Status: aceito
Contexto: o feed atual já prioriza habilidades, mas ainda sem camada conceitual explícita (Q-matrix + dependências + domínio por conceito).
Decisão:
- incorporar a trilha de grafo como extensão de M2 (`T2.4` a `T2.8`) em rollout incremental;
- manter `M3/T3.1` como tarefa atual para não quebrar o foco operacional vigente;
- preservar o canvas original como referência em `docs/roadmap/references/aprendizado_grafo.md`.
Impacto: evolução do feed para modelo híbrido (`habilidade + conceito`) sem bloquear o trabalho atual de aulas e revisão editorial.

## D-005 - Modelo pedagógico com 3 tipos de aula + roteamento pós-erro
Data: 2026-03-05
Status: aceito
Contexto: o fluxo por grafo exige separar primeiro contato de recuperação curta para evitar retrabalho e reduzir tempo de intervenção após erro no feed.
Decisão:
- manter aula por habilidade como eixo canônico de cobertura da Matriz INEP (não remover);
- adotar 3 modelos de aula no fluxo: `habilidade`, `módulo completo` e `recuperação rápida`;
- definir política de roteamento `reels -> rápida/completa` baseada em contato prévio e domínio estimado;
- introduzir pesos estruturais para conceitos fundacionais (ex.: interpretação/compreensão e matemática básica).
Impacto: fluxo de estudo mais adaptativo, com recuperação mais curta quando possível e reforço completo quando necessário.

## D-006 - Dois modos de sessão (`adaptativo` e `prova oficial`)
Data: 2026-03-05
Status: aceito
Contexto: parte dos usuários precisa treinar por fluxo inteligente contínuo, enquanto outra parte quer simular prova ENEM real por ano/dia sem interrupções pedagógicas durante o caderno.
Decisão:
- manter `adaptativo` como modo padrão de estudo no feed;
- incluir modo `prova_oficial` com seleção por `ano/dia`, ordem fechada e sem roteamento pós-erro durante a sessão;
- aplicar diagnóstico/recomendação adaptativa somente após encerramento da prova oficial.
Impacto: o produto passa a atender treino direcionado e simulação fiel de prova no mesmo app, sem misturar comportamentos durante a sessão oficial.

## D-007 - Aula no app com payload derivado e aprofundamento por gatilho de tentativa
Data: 2026-03-05
Status: aceito
Contexto: o markdown completo de aula contém instruções editoriais úteis para autoria, mas não é ideal como experiência final do estudante.
Decisão:
- manter `md` como fonte editorial e gerar `lesson_payload_aluno` para o app;
- exibir questões interativas com gabarito oculto até finalização;
- desbloquear aprofundamento apenas após tentativa mínima de questões na própria aula;
- versionar relação `aula <-> questão` para controlar atualização e revalidação de tentativas.
Impacto: experiência do aluno fica mais objetiva e mensurável, preservando qualidade editorial no fluxo interno de geração/revisão.

## D-008 - Aprovação parcial do template e decisão final pós-catalogação
Data: 2026-03-05
Status: aceito
Contexto: existe validação positiva do formato inicial da aula no app, porém ainda sem visão completa de todos os módulos enquanto a catalogação total dos 6 volumes não foi finalizada.
Decisão:
- tratar o template/player como aprovado parcialmente para avanço técnico;
- priorizar próximas tarefas de implementação no app (`T3.8+`) sem fechar decisão editorial definitiva;
- consolidar decisão final de template apenas após a catalogação completa, com revisão global.
Impacto: o time avança execução sem travar o roadmap e preserva espaço para ajustes finais com base no catálogo completo.

## D-009 - Contrato formal `lesson_payload_aluno`
Data: 2026-03-05
Status: aceito
Contexto: após validar o player no app, faltava formalizar o contrato de publicação para separar estrutura editorial de autoria e payload final para estudante.
Decisão:
- aprovar contrato canônico em `docs/roadmap/references/lesson_payload_aluno.md`;
- definir explicitamente campos pedagógicos exibíveis e campos editoriais internos;
- estabelecer regra de transformação `md -> payload` com validação mínima e versionamento por publicação.
Impacto: reduz ambiguidade entre conteúdo de autoria e experiência final do app, permitindo escalar geração/revisão com compatibilidade estável no cliente.

## D-010 - Aceleração sem catalogação (frente de contratos operacionais)
Data: 2026-03-06
Status: aceito
Contexto: havia tarefas bloqueadas por catalogação total, mas várias definições operacionais podiam ser concluídas sem esse pré-requisito.
Decisão:
- consolidar taxonomia dos 3 tipos de aula, workflow editorial e contrato de vídeo por minutagem em `docs/roadmap/references/m3_operacao_editorial.md`;
- formalizar versionamento incremental por módulo e fluxo de assinatura Android em `docs/roadmap/references/publicacao_release.md`;
- reposicionar `NEXT_TASK` para item executável não bloqueado (`T3.5`), mantendo `T3.11` explicitamente bloqueada.
Impacto: reduz fila de trabalho dependente de documentação e libera avanço prático nas próximas tarefas de implementação/piloto.

## D-011 - Hardening de geração editorial após piloto
Data: 2026-03-06
Status: aceito
Contexto: o piloto de recuperação rápida e a revisão do módulo completo evidenciaram retrabalho por placeholders residuais e instruções internas aparecendo no texto final.
Decisão:
- atualizar templates de módulo completo e recuperação rápida com checklist explícito de limpeza pré-publicação;
- reforçar no prompt de geração por módulo (v2) a proibição de placeholders/reticências e texto instrucional no resultado final;
- adicionar prompt operacional dedicado para recuperação rápida (`prompts/gerar_aula_recuperacao_rapida_enem.md`).
Impacto: redução de retrabalho editorial, maior consistência do conteúdo parseável e menor risco de vazamento de instrução interna na experiência do aluno.

## D-012 - Fechamento de T5.1 por validação do pipeline existente
Data: 2026-03-06
Status: aceito
Contexto: a tarefa `T5.1` estava pendente no roadmap, porém o `dist.sh` já implementava geração opcional de APK por versão com checksum e saída no resumo de release.
Decisão:
- considerar `T5.1` concluída após auditoria técnica do script e critérios de aceite;
- manter `T5.2` como complemento de assinatura e checklist de publicação.
Impacto: backlog alinhado ao estado real do código, reduzindo pendências artificiais no roadmap.

## D-013 - Planner acionável na UI (treino/módulo direto)
Data: 2026-03-06
Status: aceito
Contexto: a previsão do planner estava informativa, mas ainda exigia navegação indireta para iniciar treino ou revisar módulo.
Decisão:
- tornar cada slot diário do planner acionável com botões `Treinar agora` e `Abrir módulo`;
- reutilizar mapeamentos existentes (`StudyBlockSuggestion`/`ModuleSuggestion`) com fallback por skill quando não houver módulo exato.
Impacto: o fluxo planner -> execução ficou direto, reduzindo atrito operacional e atendendo o aceite de `T2.1`.

## D-014 - Tracker operacional por habilidade com erro explícito (`Hxx`)
Data: 2026-03-06
Status: aceito
Contexto: o tracker anterior registrava progresso geral, mas não estruturava evidência de erro por habilidade para fechar o ciclo diagnóstico -> ação -> reavaliação.
Decisão:
- atualizar `plano/tracker.md` com coluna dedicada de erro por habilidade (`Hxx`);
- incluir campos complementares (`tipo de erro`, `evidência curta`, `ação de revisão`, `reavaliação`) e exemplo preenchido local.
Impacto: melhora rastreabilidade pedagógica e facilita priorização do planner por habilidade com dados operacionais consistentes.

## D-015 - Rotina padrão para novos cadernos
Data: 2026-03-06
Status: aceito
Contexto: a atualização de novos cadernos precisava de um procedimento único para evitar variação operacional entre extração, validação e publicação.
Decisão:
- consolidar rotina em `plano/rotina_atualizacao_cadernos.md`;
- padronizar sequência: ingestão de PDF -> extração -> auditoria OCR -> mapeamento -> geração de bundle -> checklist.
Impacto: atualização de novos anos fica reproduzível, auditável e mais segura para publicação incremental.

## D-016 - Contrato de conceitos com exemplo de bundle offline
Data: 2026-03-06
Status: aceito
Contexto: a camada conceitual já tinha definição textual, mas faltava artefato de referência para padronizar estrutura de bundle offline.
Decisão:
- formalizar no `architecture.md` o contrato mínimo de `concepts`, `question_concepts`, `concept_dependencies`, `concept_mastery` e `concept_priority_weights`;
- publicar exemplo canônico em `docs/roadmap/references/concepts_bundle_offline_exemplo.json`.
Impacto: reduz ambiguidade de implementação no app/pipeline e acelera execução de `T2.5` (Q-matrix piloto).
