# Plano Técnico — Mapeamento Questão -> Habilidade (Hxx)

## Objetivo
Classificar cada questão real do banco (`questoes/banco_reais/enem_YYYY`) em uma habilidade da matriz ENEM, com suporte a revisão quando a confiança estiver baixa.

## Escopo inicial
- Base: ENEM 2015 a 2025.
- Entrada: `dia1_questoes_reais.md`, `dia2_questoes_reais.md`, `*_questoes_index.json`.
- Matriz: `matriz/habilidades_por_area/*.md`.
- Saída: índice consolidado por questão e por habilidade.

## Estratégia (um a um, em lotes)
### Lote 1 — Normalização dos dados (`concluído`)
- Padronizar metadados por questão: `ano`, `dia`, `numero`, `area`, `variacao`, `texto`.
- Remover resíduos de cabeçalho/rodapé ainda presentes em parte dos anos.

### Lote 2 — Base de habilidades (`concluído`)
- Converter habilidades da matriz em catálogo estruturado:
  - `area`, `competencia`, `habilidade` (Hxx), `descricao`.
- Adicionar vocabulário auxiliar por habilidade (verbos de comando e termos de conteúdo).

### Lote 3 — Classificação automática (`concluído`)
Para cada questão:
1. Detectar tipo de comando (inferir, identificar, relacionar, calcular, etc.).
2. Identificar núcleo de conteúdo e objeto cognitivo.
3. Pontuar aderência com habilidades da mesma área.
4. Selecionar:
- `habilidade_primaria` (obrigatória)
- `habilidade_secundaria` (opcional)
- `confianca` (`alta`, `media`, `baixa`)

### Lote 4 — Revisão assistida (`concluído`)
- Enviar para revisão manual apenas itens com `confianca=baixa`.
- Registrar decisão final em arquivo de auditoria (`motivo_curto`).
- Situação final do ciclo: pendentes de baixa confiança reduzidos de **444** para **0**.
- Revisões aplicadas por lote via `questoes/mapeamento_habilidades/revisao_manual/overrides.csv`.
- Relatório de aplicação em `questoes/mapeamento_habilidades/revisao_manual/aplicacao_overrides.md`.

### Lote 5 — Consolidação (`concluído`)
Gerar artefatos finais:
- `questoes/mapeamento_habilidades/questoes_mapeadas.jsonl`
- `questoes/mapeamento_habilidades/questoes_mapeadas.csv`
- `questoes/mapeamento_habilidades/resumo_por_disciplina_tema.md`
- `questoes/mapeamento_habilidades/revisao_pendente.md`
- `questoes/mapeamento_habilidades/resumo_lotes_tem_imagem.md`

## Fechamento dos lotes `tem_imagem` (2015–2025)

| Lote | Faixa de anos | Questões | Com imagem | Sem imagem | % com imagem | Status |
|---|---|---:|---:|---:|---:|---|
| Lote 1 | 2015–2017 | 437 | 141 | 296 | 32,3% | concluído |
| Lote 2 | 2018–2020 | 481 | 117 | 364 | 24,3% | concluído |
| Lote 3 | 2021–2023 | 500 | 103 | 397 | 20,6% | concluído |
| Lote 4 | 2024–2025 | 370 | 106 | 264 | 28,6% | concluído |

## Critérios de qualidade
- Cobertura mínima: 100% das questões com `habilidade_primaria`.
- Taxa máxima de revisão manual: <= 20% no primeiro ciclo.
- Coerência por área: 0 questões mapeadas para área diferente da prova.
- Status atual: pendências `baixa` zeradas no ciclo (`0/1788`).

## Métricas de acompanhamento
- Questões processadas por lote.
- % de alta/média/baixa confiança.
- Top 10 habilidades mais recorrentes por área.
- Lacunas de habilidade (Hxx com pouca cobertura histórica).

## Entregas por fase
1. Script de preparação: `scripts/preparar_mapeamento_habilidades.py`.
2. Script de classificação: `scripts/mapear_habilidades_enem.py`.
3. Script de relatório: `scripts/relatorio_mapeamento_habilidades.py`.
4. Documentação de uso no `README.md`.

## Riscos e mitigação
- Ambiguidade de comando da questão:
  - Mitigação: marcar `habilidade_secundaria` e reduzir confiança.
- Questões com imagem/tabela não textual:
  - Mitigação: flag `depende_contexto_visual` para revisão manual.
- Diferença entre anos (ordem de áreas e estilo):
  - Mitigação: usar metadados por ano/dia e validação por faixa de números.

## Próxima execução sugerida (futuro)
1. Executar auditoria amostral de qualidade nas revisões manuais aplicadas.
2. Implementar campo `depende_contexto_visual` para priorizar revisão de itens com imagem.
3. Evoluir para recorte de imagem por questão (`asset_path` + coordenadas).
4. Publicar resumo por habilidade/competência para orientar plano de estudo e geração de treino.

## Implementação atual (base heurística, sem IA)
- Script implementado: `scripts/mapear_habilidades_enem.py`.
- Saídas em `questoes/mapeamento_habilidades/`:
  - `questoes_mapeadas.csv`
  - `questoes_mapeadas.jsonl`
  - `resumo_materias_chave.md`
  - `resumo_por_disciplina_tema.md`
  - `revisao_pendente.md`
  - `lotes_revisao/README.md` + `lotes_revisao/lote_*.md`
  - `por_disciplina/*.md`
- Cobertura atual: questões 2015–2025 do banco real extraído.
