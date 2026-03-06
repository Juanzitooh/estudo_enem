# T2.10 - Pesos fundacionais do grafo (tabela inicial)

Data: 2026-03-06  
Status: aprovado (v1)

## Objetivo

Definir pesos iniciais de conceitos fundacionais para influenciar o ranking do feed híbrido (`habilidade + conceito`) no modo `adaptativo`.

## Fórmula de ranking conceitual (estado atual no app)

No cliente offline, a prioridade por conceito usa:

`priorityScore = (weakness * baseWeight) + ((1 - confidence) * 0.25) + recencyBoost`

Onde:
- `weakness = 1 - mastery`
- `baseWeight` vem de `concept_priority_weights.base_weight`
- `confidence` cresce com número de tentativas
- `recencyBoost` favorece revisão espaçada

Impacto explícito: mantendo os demais termos iguais, aumentar `baseWeight` aumenta linearmente o termo dominante (`weakness * baseWeight`) e sobe o conceito no ranking.

## Tabela inicial aprovada (v1)

| concept_id | base_weight | classe | reason |
|---|---:|---|---|
| `geral_leitura_comando` | 1.70 | fundacional_transversal | leitura de comando é pré-condição para todas as áreas |
| `geral_interpretacao_texto` | 1.65 | fundacional_transversal | interpretação textual sustenta resolução e eliminação |
| `geral_leitura_grafico_tabela` | 1.60 | fundacional_transversal | leitura de dados é transversal em Humanas/Natureza/Matemática |
| `mat_aritmetica_basica` | 1.70 | fundacional_matematica | base para proporcionalidade, porcentagem e álgebra inicial |
| `mat_razao_proporcao` | 1.60 | fundacional_matematica | recorrência alta em matemática e ciências |
| `mat_porcentagem` | 1.60 | fundacional_matematica | conceito chave em problemas cotidianos e gráficos |
| `mat_regra_de_tres` | 1.55 | fundacional_matematica | ponte operacional para aplicação de proporções |
| `mat_fracoes_decimais` | 1.50 | fundacional_matematica | base de cálculo para operações e conversões |
| `*_habilidade_enem` | 1.10 | baseline_habilidade | fallback para conceitos derivados de habilidade |
| `*_tema_disciplinar` | 1.00 | baseline_tema | fallback para temas disciplinares não fundacionais |

## Regra operacional de aplicação

- Se `concept_id` existir explicitamente na tabela acima, usar o `base_weight` definido.
- Se não existir:
  - usar `1.10` para conceitos com `reason=habilidade_enem`;
  - usar `1.00` para conceitos com `reason=tema_disciplinar`;
  - fallback final `1.00`.

## Exemplo de impacto no ranking

Com `weakness=0.50`, `confidence=0.60` e `recencyBoost=0.05`:

- conceito A (`base_weight=1.70`):  
  `priorityScore = (0.50*1.70) + (0.40*0.25) + 0.05 = 1.00`
- conceito B (`base_weight=1.10`):  
  `priorityScore = (0.50*1.10) + (0.40*0.25) + 0.05 = 0.70`

Resultado: conceito fundacional (A) sobe na fila com diferença de `+0.30`.

## Observações de rollout

- Esta tabela é inicial e deve ser recalibrada após expansão de catalogação além do piloto atual de Humanas.
- Alterações futuras de peso devem ser registradas em `decisions.md` com evidência de impacto (acurácia/tempo/retenção).
