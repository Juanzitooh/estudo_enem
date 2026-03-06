# T2.11 - Contrato de métricas de perfil (`matriz INEP + grafo + aulas`)

Data: 2026-03-06  
Status: aprovado (v1)

## Objetivo

Definir o contrato canônico do painel de perfil para consolidar, no modo offline:
- cobertura por habilidade (Matriz INEP),
- domínio por conceito (grafo),
- progresso de aulas concluídas.

## Escopo

- Contrato de dados do painel (não depende de backend).
- Compatível com o estado atual do app (`progress`, `concept_mastery`, `lesson_progress`).
- Aplicável ao modo `adaptativo` e ao pós-sessão de `prova_oficial`.

## Payload canônico (`profile_metrics_payload`)

```json
{
  "version": "profile-metrics.v1",
  "generated_at_utc": "2026-03-06T20:30:00Z",
  "profile_id": "perfil_principal",
  "content_version": "local.20260305173642",
  "matriz_inep": {
    "summary": {
      "skills_tracked": 12,
      "skills_with_attempts": 9,
      "overall_accuracy": 0.58,
      "total_attempts": 240
    },
    "skills": []
  },
  "grafo_conceitos": {
    "summary": {
      "concepts_tracked": 79,
      "concepts_with_mastery": 31,
      "mastery_avg": 0.54,
      "critical_concepts": 7
    },
    "concepts": []
  },
  "aulas": {
    "summary": {
      "lessons_started": 6,
      "lessons_completed": 4,
      "completion_rate": 0.67,
      "questions_attempted": 28,
      "questions_correct": 17,
      "outdated_attempts": 3,
      "completed_modulo_completo": 2,
      "completed_recuperacao_rapida": 2
    },
    "recent_lessons": []
  }
}
```

## Campos por seção

### 1) `matriz_inep.skills[]`

Cada item:
- `skill`: código da habilidade (`Hxx`)
- `attempts`: tentativas totais na habilidade
- `correct`: acertos totais
- `accuracy`: `correct / attempts`
- `priority_band`: `foco|manutencao|forte` (mesma taxonomia do planner atual)
- `priority_score`: score de priorização por lacuna
- `days_since_last_seen`: recência em dias
- `coverage_status`: `sem_dados|baixo|medio|alto`

Regra de `coverage_status` (v1):
- `sem_dados`: `attempts == 0`
- `baixo`: `attempts < 5`
- `medio`: `attempts >= 5 && attempts < 15`
- `alto`: `attempts >= 15`

Fonte local:
- `progress` + `questions` (skill),
- cálculo de prioridade já existente em `loadSkillPriorities`.

### 2) `grafo_conceitos.concepts[]`

Cada item:
- `concept_id`
- `label` (quando disponível em `concepts`)
- `mastery`: domínio consolidado (`concept_mastery` ou fallback observado)
- `attempts`
- `base_weight`
- `priority_score`
- `last_answered_at`
- `dependency_pending_count`: quantidade de pré-requisitos com domínio abaixo do limiar (`< 0.60`)
- `mastery_band`: `critico|atenção|ok|forte`

Regra de `mastery_band` (v1):
- `critico`: `< 0.40`
- `atenção`: `>= 0.40` e `< 0.60`
- `ok`: `>= 0.60` e `< 0.80`
- `forte`: `>= 0.80`

Fonte local:
- `question_concepts`, `concept_mastery`, `concept_priority_weights`, `concept_dependencies`, `progress`.

### 3) `aulas`

`summary`:
- `lessons_started`: aulas com progresso salvo (`lesson_progress`) mesmo sem submissão
- `lessons_completed`: `lesson_progress.submitted = 1`
- `completion_rate`: `lessons_completed / max(1, lessons_started)`
- `questions_attempted`: total em `lesson_question_attempts`
- `questions_correct`: soma de `is_correct = 1` em `lesson_question_attempts`
- `outdated_attempts`: soma de `is_outdated = 1` em `lesson_question_attempts`
- `completed_modulo_completo`: concluídas cujo `lesson_id` **não** contém `recuperacao_rapida`
- `completed_recuperacao_rapida`: concluídas cujo `lesson_id` contém `recuperacao_rapida`

`recent_lessons[]` (opcional para card de histórico):
- `lesson_id`
- `lesson_version`
- `submitted`
- `score`
- `total_questions`
- `updated_at`

Fonte local:
- `lesson_progress`,
- `lesson_question_attempts`.

## Contrato de atualização

- Frequência: recalcular em cada `_refreshStats()` no app.
- Granularidade mínima:
  - `matriz_inep.summary` (sempre),
  - top 10 em `matriz_inep.skills`,
  - top 10 em `grafo_conceitos.concepts` por `priority_score`,
  - `aulas.summary` completo.
- Persistência: pode ser calculado sob demanda; opcionalmente cache em `planner_snapshot_json` do perfil ativo.

## Regras de fallback

- Sem dados de `concept_mastery`: usar domínio observado local por conceito.
- Sem mapeamento conceitual (`question_concepts` vazio): manter `grafo_conceitos` com `concepts=[]` e `summary` zerado, sem quebrar painel.
- Sem dados de aula: `aulas.summary` com zeros.

## Critério de aceite (`T2.11`)

- [x] Contrato documentado com campos de cobertura por habilidade.
- [x] Contrato documentado com campos de domínio por conceito.
- [x] Contrato documentado com campos de aulas concluídas.
