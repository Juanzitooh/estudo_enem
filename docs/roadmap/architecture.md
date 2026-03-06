# Architecture (Roadmap)

## Fronteiras principais
- Conteúdo e curadoria: `conteudo/`, `questoes/`, `aulas/`, `templates/`, `prompts/`.
- Pipeline de publicação: `scripts/build_assets_release.py` e artefatos em `app_flutter/releases/`.
- Consumo no cliente: `app_flutter/enem_offline_client/` (SQLite local + importação de conteúdo).
- Planejamento determinístico: `planner/` e scripts associados em `scripts/`.
- Camada conceitual incremental: contratos de grafo (`conceito -> questão -> módulo`) para o feed adaptativo.

## Modelos editoriais de aula (convivência)
- `aula_habilidade_enem`: cobertura canônica da Matriz INEP por habilidade (`Hxx`).
- `aula_modulo_enem`: aula completa por módulo (base conceitual + aplicação ENEM).
- `aula_modulo_recuperacao_rapida_enem`: intervenção curta pós-erro para retomada de conceito.

## Contratos e referências
- Arquitetura offline detalhada: `plano/arquitetura_conteudo_offline.md`.
- Compatibilidade app x conteúdo: `plano/politica_compatibilidade_atualizacao_offline.md`.
- Estado editorial padrão: `rascunho -> revisado -> aprovado -> publicado`.
- Referência técnica do canvas de grafo: `docs/roadmap/references/aprendizado_grafo.md`.
- Política canônica de roteamento pós-erro: `docs/roadmap/references/t2_9_politica_roteamento_pos_erro.md`.
- Tabela inicial de pesos fundacionais do grafo: `docs/roadmap/references/t2_10_pesos_fundacionais_grafo.md`.
- Operação editorial M3 (taxonomia + workflow + vídeo): `docs/roadmap/references/m3_operacao_editorial.md`.
- Publicação/release (versionamento por módulo + assinatura Android): `docs/roadmap/references/publicacao_release.md`.

## Contrato de aula para aluno (derivado de Markdown)
- Fonte editorial: `aulas/*/modulos/*.md` (completo para IA/revisão humana).
- Artefato de consumo: `lesson_payload_aluno` em assets offline (somente conteúdo exibível ao estudante).
- Campos mínimos no payload: `lesson_id`, `lesson_version`, `title`, `learning_expectations`, `context_12m`, `concepts`, `resolution_steps`, `enem_patterns`, `examples`, `questions`, `deepening`.
- Regra de publicação: converter e publicar apenas aulas com estado editorial `aprovado/publicado`.
- Especificação formal: `docs/roadmap/references/lesson_payload_aluno.md`.

## Interrelação aula x questão (app)
- Relação canônica: `lesson_id` + `question_id` + `lesson_version`.
- Tentativas de aluno por aula: armazenar respostas e status de finalização localmente no SQLite.
- Atualização de conteúdo: quando `lesson_version`/`question_revision` mudar, manter histórico e marcar tentativa anterior como `desatualizada`.
- Aprofundamento: seção desbloqueada somente após tentativa mínima (>= 1 questão respondida na aula).

## Contrato mínimo da camada de conceitos (piloto M2)
- `concepts`: catálogo de conceitos canônicos (`id`, `label`, `area`, `difficulty`).
- `question_concepts`: Q-matrix esparsa (`question_id`, `concept_id`, `weight`).
- `concept_dependencies`: pré-requisitos (`concept_id`, `depends_on`, `strength`).
- `concept_mastery`: domínio local por perfil (`profile_id`, `concept_id`, `mastery`, `updated_at`).
- `concept_priority_weights`: pesos estruturais por conceito (`concept_id`, `base_weight`, `reason`).
- Exemplo de bundle offline: `docs/roadmap/references/concepts_bundle_offline_exemplo.json`.
- Piloto Q-matrix (Humanas): `questoes/mapeamento_habilidades/conceitos_piloto_humanas/`.
- Política de pesos fundacionais (v1): `docs/roadmap/references/t2_10_pesos_fundacionais_grafo.md`.

### Fórmula de prioridade por conceito (cliente offline)
- `priorityScore = (weakness * baseWeight) + ((1 - confidence) * 0.25) + recencyBoost`
- `baseWeight` é lido de `concept_priority_weights.base_weight`.
- Impacto: conceitos fundacionais com maior `baseWeight` sobem no ranking quando a fraqueza (`weakness`) é equivalente.

### Exemplo resumido do bundle offline
```json
{
  "version": "concepts.2026.03.06.1",
  "concepts": [{"id": "geral_leitura_comando", "label": "Leitura de comando", "area": "Transversal", "difficulty": "basico"}],
  "question_concepts": [{"question_id": "2023_1_45_1", "concept_id": "geral_leitura_comando", "weight": 0.4}],
  "concept_dependencies": [{"concept_id": "ch_h13_centralizacao_politica", "depends_on": "ch_h13_civilizacoes_hidraulicas", "strength": 0.8}],
  "concept_priority_weights": [{"concept_id": "geral_leitura_comando", "base_weight": 1.5, "reason": "fundacional_transversal"}],
  "concept_mastery": [{"profile_id": "perfil_principal", "concept_id": "geral_leitura_comando", "mastery": 0.55, "updated_at": "2026-03-06T17:45:00Z"}]
}
```

## Política de estudo (reels -> aula)
- Entrada principal: feed de questões (`reels`) com priorização híbrida.
- Pós-erro (`adaptativo`): executar microtreino de 3 questões e decidir por regra canônica.
- Regra v1: `aula_completa` quando `primeiro_contato=true` ou `mastery<0.45` ou `acertos_microtreino<=1`; caso contrário `recuperação_rapida`.
- Escalada: se `recuperação_rapida` terminar com acurácia `< 50%`, redirecionar para `aula_completa`.
- Retorno ao feed: após critério mínimo de saída (microtreino/checagem).

## Modos de sessão de estudo
- `adaptativo` (plano comum): feed inteligente com priorização híbrida e intervenções pós-erro.
- `prova_oficial`: execução de caderno ENEM por `ano/dia` em sequência fechada, sem intervenções adaptativas durante a sessão.
- Contrato mínimo de sessão: `mode`, `exam_year`, `exam_day`, `question_order`, `adaptive_enabled`.
- Regra: `adaptive_enabled=false` em `prova_oficial`; diagnósticos e recomendações só após finalizar o caderno.

## Métricas de perfil (matriz + grafo + aulas)
- Cobertura INEP por habilidade (`tentadas`, `domínio estimado`, `lacunas críticas`).
- Domínio por conceito no grafo (`mastery`, `tendência`, `pré-requisitos pendentes`).
- Consumo de aulas (`completas concluídas`, `recuperações rápidas concluídas`, `tempo total`).

## Restrições operacionais
- Sem backend obrigatório para uso principal.
- Conteúdo deve ser versionado e auditável.
- Atualização deve preservar funcionamento offline entre releases.
- Operação atual por habilidade deve seguir funcional durante a transição para feed híbrido.
