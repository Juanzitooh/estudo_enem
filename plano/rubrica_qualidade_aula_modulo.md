# Rubrica objetiva - Aula por modulo (ENEM)

Rubrica para avaliar lotes piloto e reduzir retrabalho humano.

## Escala
- Nota por criterio: `0`, `1` ou `2`.
- Peso por criterio: conforme tabela.
- Nota final: soma ponderada (0 a 100).

## Critérios

| # | Critério | Peso | Nota 0 | Nota 1 | Nota 2 |
|---|---|---:|---|---|---|
| 1 | Correcao conceitual | 20 | Erros conceituais relevantes | Pequenas imprecisoes sem comprometer o raciocinio | Conceitos corretos e consistentes |
| 2 | Clareza didatica | 15 | Texto confuso e pouco instrucional | Explicacao parcialmente clara | Explicacao direta, progressiva e compreensivel |
| 3 | Progressao pedagogica | 10 | Nao ha encadeamento | Encadeamento parcial | Fluxo completo: base -> aplicacao -> revisao |
| 4 | Aderencia ao ENEM | 15 | Linguagem/formato fora do exame | Parcialmente aderente | Estilo, comando e profundidade alinhados ao ENEM |
| 5 | Contexto brasileiro atual | 10 | Sem contexto atual | Contexto atual superficial | Contexto brasileiro real, com datas absolutas |
| 6 | Aplicacao pratica | 10 | Sem exemplos praticos | Apenas 1 exemplo valido | 2+ exemplos (cotidiano + profissional) |
| 7 | Qualidade do treino | 10 | Questoes sem alinhamento ao modulo | Alinhamento parcial | Bloco contextualizado coerente com o modulo |
| 8 | Retencao e revisao | 10 | Sem checagem/erros comuns | Secoes incompletas | Checagem 5-10 + erros comuns + revisao objetiva |

## Classificacao por faixa
- `>= 85`: pronto para revisao editorial final.
- `70-84`: bom, requer ajustes localizados.
- `50-69`: retrabalho moderado (prompt/template).
- `< 50`: retrabalho alto, nao publicar.

## Gate minimo para publicar
- Nota final `>= 70`.
- Criterio 1 (correcao conceitual) com nota `2`.
- Criterio 4 (aderencia ENEM) com nota `>= 1`.

## Procedimento de avaliacao do lote piloto
1. Selecionar lote de aulas (ex.: 20 modulos).
2. Rodar validacao automatica estrutural (`scripts/validar_aulas_modulo.py`).
3. Avaliar manualmente cada aula com esta rubrica.
4. Consolidar resultado em relatorio por modulo (`nota`, `gaps`, `acao`).
5. Ajustar prompt/template e repetir ate reduzir retrabalho para faixa operacional.
