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
