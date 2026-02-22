# Agent Global — ENEM Aula por Habilidade

## Missão
Gerar aulas no padrão ENEM focadas em uma habilidade da Matriz do INEP, usando o template `templates/aula_habilidade_enem.md`.

## Fontes internas do repositório
- `sources/inep_matriz_referencia.pdf` (fonte primária)
- `matriz/` (conteúdo convertido da matriz)
- `notes/` (anotações de vídeos, artigos e pesquisas)
- `questoes/banco_reais/` (questões reais extraídas de provas anteriores)
- `templates/aula_habilidade_enem.md` (template obrigatório)
- `README.md` (fluxo operacional)
- `CHANGELOG.md` (histórico de mudanças)

## Regras obrigatórias
1. Não inventar conteúdo da matriz.
2. Se algo estiver ilegível no PDF, marcar como `[TRECHO ILEGÍVEL]`.
3. Questões estilo ENEM devem ser originais (sem copiar enunciados reais).
4. Sempre incluir contexto real, método de resolução, interdisciplinaridade (mínimo 2 conexões), treino progressivo e gabarito comentado.
5. Cada aula deve ter 10 questões estilo ENEM com distribuição: 5 fáceis, 3 médias e 2 difíceis.
6. Em cada questão de múltipla escolha, formatar alternativas A, B, C, D e E em linhas separadas, com quebra explícita para evitar texto corrido no PDF.
7. Se houver `questoes/banco_reais/` disponível, usar como base de estilo (comando, nível e distratores), sem copiar texto literal.
8. Linguagem didática, objetiva e sem “textão”.
9. Em conteúdo em português, usar ortografia e acentuação corretas (UTF-8).
10. Não remover acentos para ASCII em materiais de estudo, resumos, questões e planos.
11. Seguir as instruções globais do Codex (AGENTS) para qualidade e versionamento.

## Estrutura de saída
- Aula em `aulas/{area}/HXX_{tema}.md`
- Banco extra em `questoes/{area}/HXX_{tema}.md`
- Quando necessário, imagens de apoio em `assets/img/`

## Fluxo de trabalho
1. Ler a habilidade alvo na matriz (`matriz/habilidades_por_area/` ou `sources/inep_matriz_referencia.pdf`).
2. Consultar `notes/` se houver notas para a habilidade.
3. Consultar `questoes/banco_reais/` para calibrar formato de enunciado e dificuldade.
4. Preencher `templates/aula_habilidade_enem.md` e salvar em `aulas/{area}/`.
5. Gerar também banco extra de 20 questões em `questoes/{area}/`.
6. Registrar mudanças relevantes no `CHANGELOG.md`.

## Entregáveis mínimos por aula
- Aula completa no template.
- 10 questões estilo ENEM na aula (5 fáceis, 3 médias, 2 difíceis) com gabarito comentado.
- Banco de 20 questões extras (originais) + gabarito curto.
- Lista de 10 erros comuns e como corrigir.
- Mini-plano de revisão de 7 dias.

## Convenções de commit
Usar commits atômicos e prefixos:
- `fix`: correção de bug
- `feat`: nova funcionalidade
- `imp`: melhoria/refactor sem nova feature
- `docs`: documentação
- `codex`: ajustes em arquivos de agente/overrides e arquivos usados apenas pelo Codex
