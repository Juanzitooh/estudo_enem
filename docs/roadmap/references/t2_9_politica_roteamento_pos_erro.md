# T2.9 - Política de roteamento pós-erro (`reels -> recuperação rápida` vs `aula completa`)

Data: 2026-03-06  
Status: aprovado para rollout incremental no modo `adaptativo`

## Objetivo

Definir regra única e reproduzível para decidir, após erro no reels, se o aluno deve ir para:
- `recuperação rápida` (intervenção curta), ou
- `aula completa` (reconstrução de base).

## Escopo

- Aplica apenas ao modo `adaptativo`.
- Não se aplica durante `prova_oficial` (diagnóstico/recomendação só após encerrar o caderno).

## Entradas mínimas da decisão

- `primeiro_contato` (bool):
  - `true` quando o conceito ainda tem baixa exposição local.
  - Regra inicial sugerida: `tentativas_no_conceito < 3` **ou** sem aula concluída para o tema relacionado.
- `mastery` (0..1):
  - valor de `concept_mastery` do perfil ativo;
  - fallback: domínio observado local no conceito (acertos ponderados / tentativas).
- `acertos_microtreino` (0..3):
  - resultado do diagnóstico curto pós-erro (`T2.7`).

## Regra canônica (v1)

1. Se `primeiro_contato == true` -> `aula_completa`.
2. Senão, se `mastery < 0.45` -> `aula_completa`.
3. Senão, se `acertos_microtreino <= 1` -> `aula_completa`.
4. Caso contrário (`mastery >= 0.45` e `acertos_microtreino >= 2`) -> `recuperacao_rapida`.

## Critério de escalada após recuperação rápida

- Se o aluno tentar ao menos 1 questão da recuperação rápida e ficar com acurácia `< 50%`, escalar para `aula_completa`.
- Se acurácia `>= 50%`, retornar ao reels adaptativo.

## Pseudocódigo

```text
if mode == "prova_oficial":
  return "sem_roteamento_durante_prova"

if primeiro_contato:
  return "aula_completa"

if mastery < 0.45:
  return "aula_completa"

if acertos_microtreino <= 1:
  return "aula_completa"

return "recuperacao_rapida"
```

## Casos de referência

1. Errou questão nova, conceito nunca praticado (`primeiro_contato=true`) -> `aula_completa`.
2. Conceito conhecido, `mastery=0.38`, microtreino `2/3` -> `aula_completa`.
3. Conceito conhecido, `mastery=0.62`, microtreino `1/3` -> `aula_completa`.
4. Conceito conhecido, `mastery=0.62`, microtreino `2/3` -> `recuperacao_rapida`.
5. Foi para `recuperacao_rapida`, tentou questões e fez `<50%` -> escalar `aula_completa`.

## Telemetria mínima local (offline)

- `post_error_route`: `recuperacao_rapida|aula_completa`.
- `post_error_reason`: `primeiro_contato|mastery_baixo|microtreino_baixo|microtreino_ok`.
- `post_error_mastery_snapshot`: valor usado na decisão.
- `post_error_microtreino_score`: `0..3`.

## Resultado esperado

- Reduzir envio prematuro para aula longa quando o aluno já tem base mínima.
- Preservar intervenção robusta (`aula_completa`) nos casos de primeiro contato ou baixa base real.
