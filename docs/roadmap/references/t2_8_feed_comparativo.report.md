# T2.8 - Avaliação comparativa offline (feed skill-only vs híbrido)

- Gerado em: 2026-03-06T16:46:59.481654+00:00
- Bundle de questões: `app_flutter/releases/local.20260305173642/assets_local.20260305173642.zip`
- Bundle conceitual piloto: `questoes/mapeamento_habilidades/conceitos_piloto_humanas/concepts_bundle_piloto_humanas.json`
- Questões avaliadas (com Q-matrix): **120**

## Configuração da simulação
- Usuários simulados: **320**
- Questões principais por sessão: **30**
- Questões de retenção (delay): **6**
- Passos de cooldown (esquecimento): **10**
- Seed: **20260306**

## Métricas (média)

| Política | Acurácia | Tempo médio (s) | Retenção |
|---|---:|---:|---:|
| Skill-only | 48.60% | 111.49 | 47.92% |
| Híbrido | 48.32% | 111.88 | 47.14% |

## Delta (Híbrido - Skill-only)
- Acurácia: **-0.28 pp**
- Tempo: **+0.39 s**
- Retenção: **-0.78 pp**

## Decisão de rollout
- Decisão: **manter_piloto**
- Justificativa: ganho insuficiente para rollout amplo; manter coleta adicional e recalibrar pesos/diagnóstico.

## Critério objetivo usado
- `retenção >= +2.0 pp`
- `acurácia >= -1.0 pp`
- `tempo <= +8.0 s`

## Observações
- Avaliação offline por simulação com modelo probabilístico de aprendizagem/esquecimento.
- Resultado é válido para o piloto atual (Q-matrix de Humanas); reavaliar ao expandir catalogação.
