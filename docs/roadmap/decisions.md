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
