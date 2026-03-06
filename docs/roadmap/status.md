CURRENT_MILESTONE: M3 - Aulas por módulo operacional
NEXT_TASK: T2.3 - Documentar rotina de atualização ao adicionar novos cadernos

BLOCKERS:
- T3.1 depende de validação manual do lote piloto com rubrica.
- T3.11 segue bloqueada até a catalogação completa dos 6 volumes.

RECENT_CHANGES:
- 2026-03-06 - `T2.2` concluída com atualização do `plano/tracker.md` (campo explícito de erro por habilidade `Hxx`, tipo de erro, ação de revisão e exemplo de uso local).
- 2026-03-06 - `T2.1` concluída no app: slots da previsão do planner agora abrem treino/módulo diretamente na UI (sem etapa manual extra).
- 2026-03-06 - `T5.1` concluída: `dist.sh` validado com APK Android opcional por versão, checksum (`.sha256`) e registro no `dist_summary.txt`.
- 2026-03-06 - `T3.2` concluída com ajustes em template/prompt (limpeza de placeholders/instruções internas, estrutura de questões completa e prompt operacional de recuperação rápida).
- 2026-03-06 - `T3.5` concluída com piloto de recuperação rápida no módulo `V1_M1_antiguidade_oriental` e relatório de aceite do fluxo pós-erro.
- 2026-03-06 - `T3.3`, `T3.4` e `T3.6` concluídas com especificação operacional unificada de taxonomia, workflow editorial e integração de vídeo por minutagem.
- 2026-03-06 - `T4.3` concluída com estratégia formal de versionamento incremental por módulo no manifesto.
- 2026-03-06 - `T5.2` concluída com checklist de assinatura Android (`debug/local` vs `release`) e validação mínima.
- 2026-03-05 - `T3.7` concluída com especificação formal do contrato `lesson_payload_aluno` (`campos exibíveis`, `campos internos`, transformação `md -> payload`).
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
