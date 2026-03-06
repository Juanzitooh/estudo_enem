# Relatório T3.5 - Piloto de Recuperação Rápida

Data: 2026-03-06  
Módulo piloto: `V1_M1_antiguidade_oriental`  
Arquivo gerado: `aulas/humanas/modulos/V1_M1_antiguidade_oriental_recuperacao_rapida.md`

## 1) Objetivo do piloto

Validar um exemplo real de aula curta pós-erro com:
- tempo alvo de 10-15 min;
- microdiagnóstico;
- microtreino com 3 questões;
- regra de saída para retorno ao feed ou escalada para aula completa.

## 2) Trigger simulado

- `trigger_question_id`: `CH_V1M1_QHIDR_01`
- `trigger_skill`: `H13`
- erro dominante esperado: confusão entre contexto político antigo e instituições modernas.

## 3) Checklist de aceite (T3.5)

- [x] Aula rápida preenchida em módulo real.
- [x] Conteúdo revisado em formato operacional de recuperação.
- [x] Regra de saída definida (`>=2/3` retorna feed; `<2/3` abre aula completa).
- [x] Bloco de aprofundamento com minutagem e fallback.

## 4) Resultado do piloto

Piloto aprovado como referência inicial de recuperação rápida para História 1.

## 5) Próximo passo sugerido

Reaplicar o mesmo formato em 1 módulo de outra área (Natureza ou Matemática) para testar portabilidade do template.
