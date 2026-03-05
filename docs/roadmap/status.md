CURRENT_MILESTONE: M3 - Aulas por módulo operacional
NEXT_TASK: T3.7 - Definir contrato `lesson_payload_aluno` derivado de `aula_modulo_enem` aprovado

BLOCKERS:
- none

RECENT_CHANGES:
- 2026-03-05 - `T3.10` concluída com interrelação versionada `aula <-> questão`, marcação de tentativas desatualizadas e histórico por versão exibido na UI.
- 2026-03-05 - Validação manual confirmou `T3.8` e `T3.9` no app (persistência local + desbloqueio de aprofundamento por tentativa mínima).
- 2026-03-05 - UI da aula passou a exibir aviso de tentativas `desatualizadas` de versões anteriores.
- 2026-03-05 - Implementação inicial da interrelação versionada `aula <-> questão` no app, com marcação de tentativas antigas como `desatualizadas`.
- 2026-03-05 - Aprovação parcial do template/player de aula; decisões finais ficam para pós-catalogação completa dos 6 volumes.
- 2026-03-05 - Priorização operacional ajustada para avançar no player de aula (`NEXT_TASK=T3.8`) mantendo validação editorial ampla em paralelo.
- 2026-03-05 - Planejamento atualizado com player de aula no app, interrelação `aula <-> questão` e desbloqueio de aprofundamento após tentativa mínima.
- 2026-03-05 - Planejamento atualizado com modos de sessão (`adaptativo` e `prova oficial por ano/dia`) e regra de prova fechada sem adaptação durante o caderno.
- 2026-03-05 - Planejamento atualizado para explicitar 3 tipos de aula (`habilidade`, `módulo completo`, `recuperação rápida`).
- 2026-03-05 - Trilha M2 estendida com política pós-erro, pesos fundacionais do grafo e métricas de perfil.
- 2026-03-05 - Trilha de grafo de conhecimento adicionada ao M2 (`T2.4` a `T2.8`) com rollout incremental.
- 2026-03-05 - Canvas técnico movido para `docs/roadmap/references/aprendizado_grafo.md` como referência de longo prazo.
- 2026-03-04 - Bootstrap `docs/roadmap/` criado como camada canônica de execução.
- 2026-03-04 - Fluxo inicial de aula por módulo concluído (template, prompt, lote piloto, validador e rubrica).
- 2026-03-04 - Pipeline de conteúdo offline consolidado com manifests por domínio e política de compatibilidade.
