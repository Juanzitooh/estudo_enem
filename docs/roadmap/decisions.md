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

## D-017 - Piloto Q-matrix em Humanas com cobertura auditável
Data: 2026-03-06
Status: aceito
Contexto: para iniciar o feed híbrido sem depender da catalogação completa, era necessário um piloto de Q-matrix em uma área com massa crítica de questões.
Decisão:
- executar piloto em Ciências Humanas com geração reprodutível via `scripts/gerar_qmatrix_piloto_humanas.py`;
- publicar artefatos auditáveis (`concepts`, `question_concepts`, `dependencies`, `weights`, `bundle`, `resumo`) em `questoes/mapeamento_habilidades/conceitos_piloto_humanas/`.
Impacto: cria base concreta para implementação da seleção híbrida em `T2.6` com fallback por habilidade já existente.

## D-018 - Feed híbrido com fallback explícito por habilidade no cliente offline
Data: 2026-03-06
Status: aceito
Contexto: o app precisava sair do feed puramente por habilidade e consumir a camada de conceitos sem quebrar o comportamento atual em bundles legados.
Decisão:
- implementar no app a priorização inicial por conceito (fraqueza observada em `progress` + peso estrutural + peso `question_concepts`);
- complementar a sessão com slots adaptativos por habilidade para manter continuidade da estratégia atual;
- quando não houver mapeamento conceitual disponível, manter fallback automático para seleção por habilidade e fallback geral de questões.
Impacto: permite rollout incremental do grafo no cliente offline com compatibilidade retroativa de conteúdo.

## D-019 - Diagnóstico curto pós-erro com atualização local de `concept_mastery`
Data: 2026-03-06
Status: aceito
Contexto: após habilitar o feed híbrido, faltava um mecanismo direto de intervenção pós-erro para refinar domínio conceitual local e alterar a recomendação seguinte sem depender apenas do histórico agregado de acertos.
Decisão:
- ao errar no reels, disparar diagnóstico rápido de até 3 questões do conceito principal associado à questão;
- registrar tentativas desse microdiagnóstico no `progress` e consolidar resultado em `concept_mastery` por perfil;
- considerar `concept_mastery` no cálculo de prioridade conceitual do feed híbrido (com peso maior que o observado bruto recente).
Impacto: o app passa a ter loop curto de correção (`erro -> microdiagnóstico -> ajuste de domínio -> novo ranking`) totalmente offline.

## D-020 - Resultado de T2.8: manter piloto do feed híbrido antes de rollout amplo
Data: 2026-03-06
Status: aceito
Contexto: após concluir `T2.7`, era necessário comparar `skill-only` vs `híbrido` com métricas offline para decisão de rollout.
Decisão:
- executar avaliação reproduzível via `scripts/avaliar_feed_hibrido_offline.py` usando release local (`2032` questões) + Q-matrix piloto de Humanas (`120` questões mapeadas, `79` conceitos);
- registrar artefatos em `docs/roadmap/references/t2_8_feed_comparativo.{report.md,summary.json,per_user.csv}`;
- adotar decisão `manter_piloto` para o híbrido nesta etapa, sem rollout amplo imediato.
Impacto: reduz risco de regressão pedagógica/operacional e direciona próximos ajustes de roteamento/pesos antes da expansão do híbrido para produção geral.

## D-021 - Política canônica de roteamento pós-erro (`T2.9`)
Data: 2026-03-06
Status: aceito
Contexto: após `T2.7` e `T2.8`, faltava transformar o roteamento `reels -> recuperação rápida|aula completa` em regra objetiva e auditável para reduzir decisões ad hoc.
Decisão:
- formalizar a política em `docs/roadmap/references/t2_9_politica_roteamento_pos_erro.md` com entradas mínimas: `primeiro_contato`, `mastery`, `acertos_microtreino`;
- definir regra v1: enviar para `aula_completa` quando `primeiro_contato=true` ou `mastery<0.45` ou `acertos_microtreino<=1`; nos demais casos, enviar para `recuperação_rapida`;
- definir escalada pós-recuperação: acurácia `< 50%` na recuperação rápida redireciona para `aula_completa`.
Impacto: cria base única para implementação no app, telemetria comparável entre sessões e redução de intervenção longa desnecessária em erros pontuais.

## D-022 - Pesos fundacionais iniciais do grafo (`T2.10`)
Data: 2026-03-06
Status: aceito
Contexto: após fechar o roteamento pós-erro, faltava explicitar a priorização estrutural de conceitos fundacionais no ranking híbrido para leitura/interpretação e matemática básica.
Decisão:
- aprovar tabela inicial em `docs/roadmap/references/t2_10_pesos_fundacionais_grafo.md` com pesos maiores para `geral_leitura_*` e `mat_*` fundacionais;
- manter baseline `1.10` para conceitos derivados de habilidade e `1.00` para temas disciplinares não fundacionais;
- registrar explicitamente a fórmula de ranking por conceito no roadmap para rastreabilidade (`weakness * baseWeight` como termo dominante).
Impacto: o feed passa a ter viés intencional para lacunas fundacionais transversais, preservando fallback estável para conceitos não priorizados.

## D-023 - Contrato canônico do painel de métricas de perfil (`T2.11`)
Data: 2026-03-06
Status: aceito
Contexto: com feed híbrido e player de aula já operacionais, faltava padronizar o payload de métricas do perfil para evitar divergência entre cálculos de habilidade, conceito e progresso de aula.
Decisão:
- formalizar `profile_metrics_payload` em `docs/roadmap/references/t2_11_contrato_metricas_perfil.md`;
- definir três blocos obrigatórios: `matriz_inep`, `grafo_conceitos`, `aulas`, com campos mínimos e regras de fallback offline;
- adotar regra inicial de tipagem de aula por `lesson_id` (contém `recuperacao_rapida`) para separar concluídas de recuperação vs módulo completo enquanto o catálogo final não está fechado.
Impacto: cria base única para UI de perfil, rastreabilidade entre métricas pedagógicas e evolução incremental sem quebrar compatibilidade local.

## D-024 - Contrato de modos de sessão (`T2.12`)
Data: 2026-03-06
Status: aceito
Contexto: apesar de já existir decisão macro sobre dois modos (`D-006`), faltava contrato operacional com payload mínimo e regras de validação para implementação segura da `prova_oficial`.
Decisão:
- formalizar `session_config` e `session_runtime` em `docs/roadmap/references/t2_12_contrato_modos_sessao.md`;
- exigir parâmetros mínimos na prova oficial (`exam_year`, `exam_day`, `question_order=enem_oficial`);
- tornar mandatória a regra `adaptive_enabled=false` em `prova_oficial` (com `post_error_routing` e `concept_diagnostic` desligados durante a sessão).
Impacto: reduz ambiguidade na implementação de `T2.13`, garante simulação fiel do caderno e evita mistura de comportamentos adaptativos na prova oficial.
