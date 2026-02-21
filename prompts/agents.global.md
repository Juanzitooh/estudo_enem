# agents.global.md — ENEM Companion (Codex/VSCode)

## Contexto
Este repositório organiza meu estudo para o ENEM usando a Matriz de Referência do INEP.
Há um PDF oficial em `sources/inep_matriz_referencia.pdf` que deve ser a fonte principal.

## Objetivo do agente
1) Transformar o PDF em Markdown navegável.
2) Gerar resumos por área (Linguagens, Matemática, Natureza, Humanas).
3) Criar checklists rastreáveis e um plano semanal.
4) Gerar questões originais no estilo ENEM para treino (sem copiar provas inteiras).

## Fontes
- Fonte oficial: `sources/inep_matriz_referencia.pdf`
- Arquivos gerados: `matriz/` e `plano/`
- Guia operacional: `README.md`
- Histórico de mudanças: `CHANGELOG.md`

## Regras de ouro
- Não inventar conteúdo da matriz.
- Se algo estiver ilegível no PDF, marcar como `[TRECHO ILEGÍVEL]`.
- Priorizar Markdown limpo: títulos, listas, tabelas, links internos.
- Evitar textos longos: preferir tópicos.
- Questões devem ser originais (não copiar enunciados reais).
- Seguir as instruções globais do Codex (AGENTS) para qualidade e versionamento.
- Em conteúdo em português, usar ortografia e acentuação corretas (UTF-8).
- Não remover acentos para ASCII em materiais de estudo, resumos, questões e planos.

## Integração de contexto
- Ao iniciar uma sessão de estudo, considerar `prompts/contexto_sessao.md` quando existir.
- Usar `README.md` como referência de fluxo e tipos de interação.
- Registrar mudanças relevantes no `CHANGELOG.md`.
- Em commits, seguir convenções globais: `fix`, `feat`, `imp`, `docs`, `codex`.

## Saídas padrão
- `matriz/matriz_referencia_enem.md` (conversão completa)
- `matriz/eixos_cognitivos.md` (resumo)
- `matriz/habilidades_por_area/*.md` (por área)
- `plano/checklist_*.md` (checklists)
- `plano/plano_semanal.md` (plano semanal adaptável)
- `plano/tracker.md` (registro de progresso)

## Workflow sugerido
1) Converter PDF → MD
2) Resumir por área
3) Criar checklists
4) Criar plano semanal
5) Gerar questões por habilidade (e registrar erros no tracker)

## Como gerar questões (template)
- Escolha 1 habilidade
- Gere 10 questões originais estilo ENEM (5 fáceis, 3 médias, 2 difíceis)
- Inclua gabarito e justificativa curta
- Salvar em `questoes/<area>/<habilidade>.md`
