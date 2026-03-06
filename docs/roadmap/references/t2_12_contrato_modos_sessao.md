# T2.12 - Contrato de modos de sessão (`adaptativo` vs `prova_oficial`)

Data: 2026-03-06  
Status: aprovado (v1)

## Objetivo

Padronizar como uma sessão de questões é configurada e executada no app, com separação explícita entre:
- estudo contínuo adaptativo (`adaptativo`),
- simulação fiel de prova ENEM por ano/dia (`prova_oficial`).

## Escopo

- Contrato de configuração e execução de sessão.
- Regras de comportamento durante a sessão.
- Regra explícita de desligamento adaptativo no modo `prova_oficial`.

## Tipos de sessão

- `adaptativo`:
  - feed inteligente por lacuna (`habilidade + conceito`);
  - pode disparar diagnóstico curto pós-erro;
  - pode rotear para `recuperacao_rapida` ou `aula_completa`.
- `prova_oficial`:
  - seleção por `ano` e `dia` do ENEM;
  - caderno fechado em ordem fixa;
  - sem intervenções adaptativas durante a resolução.

## Payload canônico de configuração (`session_config`)

```json
{
  "version": "session-config.v1",
  "profile_id": "perfil_principal",
  "mode": "prova_oficial",
  "exam_year": 2023,
  "exam_day": 1,
  "question_order": "enem_oficial",
  "question_limit": 90,
  "adaptive_enabled": false,
  "post_error_routing_enabled": false,
  "concept_diagnostic_enabled": false,
  "created_at_utc": "2026-03-06T20:45:00Z"
}
```

## Campos mínimos

- `mode`: `adaptativo|prova_oficial` (obrigatório)
- `exam_year`: inteiro (obrigatório em `prova_oficial`; opcional em `adaptativo`)
- `exam_day`: `1|2` (obrigatório em `prova_oficial`; opcional em `adaptativo`)
- `question_order`:
  - `adaptive_ranked` para `adaptativo`
  - `enem_oficial` para `prova_oficial`
- `adaptive_enabled`:
  - `true` em `adaptativo`
  - `false` em `prova_oficial` (regra mandatória)

## Regras mandatórias por modo

### `adaptativo`

- `adaptive_enabled = true`
- `post_error_routing_enabled = true`
- `concept_diagnostic_enabled = true`
- fonte principal de seleção: ranking por lacuna (`skill + concept`)

### `prova_oficial`

- `adaptive_enabled = false`
- `post_error_routing_enabled = false`
- `concept_diagnostic_enabled = false`
- seleção estrita por `exam_year + exam_day`
- ordem de questões fixa (`question_order = enem_oficial`)
- sem inserção dinâmica de novas questões durante a sessão

## Regra de ordenação (`question_order`)

- `adaptive_ranked`:
  - ordenação por score adaptativo (prioridade de skill/conceito + recência + confiança).
- `enem_oficial`:
  - ordenação por sequência do caderno:
    - `number ASC`
    - desempate por `variation ASC`
  - sem reordenação por desempenho do aluno.

## Estado de execução (`session_runtime`) - mínimo recomendado

```json
{
  "session_id": "sess_20260306_001",
  "mode": "prova_oficial",
  "status": "in_progress",
  "current_index": 17,
  "total_questions": 90,
  "correct_count": 0,
  "wrong_count": 0,
  "started_at_utc": "2026-03-06T20:50:00Z",
  "finished_at_utc": null
}
```

Campos:
- `status`: `in_progress|completed|abandoned`
- `current_index`: posição atual
- `total_questions`: total da sessão
- `correct_count` e `wrong_count`: atualizados com respostas válidas

## Regra de pós-sessão

- `adaptativo`:
  - mantém ciclo curto `erro -> diagnóstico -> roteamento`.
- `prova_oficial`:
  - só após `status=completed`:
    - calcular resumo por habilidade/conceito,
    - sugerir revisão (`recuperacao_rapida`/`aula_completa`) fora da sessão.

## Validações mínimas

1. Se `mode=prova_oficial` e (`exam_year` vazio ou `exam_day` vazio) -> inválido.
2. Se `mode=prova_oficial` e `adaptive_enabled=true` -> inválido.
3. Se `mode=prova_oficial` e `question_order!=enem_oficial` -> inválido.
4. Se `mode=adaptativo` e `question_order=enem_oficial` -> inválido.

## Compatibilidade com o app atual

- O modo `adaptativo` já está operacional via reels/planner.
- O modo `prova_oficial` ainda depende da implementação de fluxo dedicado (`T2.13`).
- Este contrato define os campos e gates que `T2.13` deve respeitar.

## Critério de aceite (`T2.12`)

- [x] contrato documentado com seleção de modo;
- [x] parâmetros mínimos (`ano`, `dia`, `ordem`) definidos;
- [x] regra explícita de desligamento adaptativo na prova oficial.
