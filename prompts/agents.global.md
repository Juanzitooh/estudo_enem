# Agent Global — ENEM Aula por Habilidade

## Missão
Gerar aulas no padrão ENEM focadas em uma habilidade da Matriz do INEP, usando o template `templates/aula_habilidade_enem.md`.

## Fontes internas do repositório
- `sources/inep_matriz_referencia.pdf` (fonte primária)
- `edital.pdf` (regras oficiais de aplicação do ENEM)
- `matriz/` (conteúdo convertido da matriz)
- `notes/` (anotações de vídeos, artigos e pesquisas)
- `questoes/banco_reais/` (questões reais extraídas de provas anteriores)
- `questoes/mapeamento_habilidades/` (questões classificadas por disciplina/tema/habilidade estimada)
- `prompts/contexto_planejador.json` (quando existir, contexto do motor offline sem IA)
- `plano/desempenho_habilidades.csv` (feedback real por habilidade)
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
8. Consultar `edital.pdf` para confirmar estrutura do exame (dias, áreas, duração e formato) quando necessário.
9. Linguagem didática, objetiva e sem “textão”.
10. Em conteúdo em português, usar ortografia e acentuação corretas (UTF-8).
11. Não remover acentos para ASCII em materiais de estudo, resumos, questões e planos.
12. Seguir as instruções globais do Codex (AGENTS) para qualidade e versionamento.
13. Se o pedido for de planejamento determinístico sem IA, priorizar `scripts/gerar_plano_offline.py` e os arquivos do módulo `planner/`.
14. Se o pedido for separação por matéria/tema, priorizar `scripts/mapear_habilidades_enem.py` e os artefatos em `questoes/mapeamento_habilidades/`.
15. Em aulas geradas, sempre preencher metadados editoriais no topo: `Status editorial`, `Atualizado por IA em`, `Revisado manualmente em` e `Revisado por`.
16. Incluir bloco de contexto atual com fatos dos últimos 12 meses, citando datas absolutas.
17. Priorizar exemplos do Brasil e regionalidades brasileiras; usar contexto internacional apenas quando for essencial para explicar o conceito.
18. Para Física, Química, Biologia e Matemática, incluir pelo menos um recurso visual didático (gráfico, esquema, diagrama ou desenho) quando o tema exigir apoio visual.
19. Incluir um problema real aplicado ao contexto brasileiro com perguntas de reflexão no fim da aula.

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

## Workflow local (.sh) para app Flutter
Quando o pedido envolver validação/execução do app, priorizar os scripts da raiz do repositório:

1. `./dev_linux.sh`
- Fluxo de desenvolvimento rápido no Linux (setup + build local + servidor de manifest + abrir app).
- Usar para validação visual/manual de interface (tema, contraste, acessibilidade etc.).

2. `./run_local.sh`
- Sobe somente servidor local do `manifest.json` (não abre a janela do app).
- Usar quando quiser testar update manual com app já aberto.

3. `./dist.sh --version <versao> [opcoes]`
- Gera release versionada com `manifest.json` + `assets_<versao>.zip` + build Linux.
- Usar para testes de empacotamento/distribuição e verificação do pipeline de release.

4. `./install_linux.sh --type <deb|appimage> --version <versao> --release-dir app_flutter/releases/<versao>`
- Instala artefatos Linux gerados pelo `dist.sh`.
- Usar para validar instalação/execução fora da pasta de build.

Referência operacional detalhada: `README.md` (seção “App Flutter: uso rápido e release”) e `app_flutter/README.md`.

## Convenções de commit
Usar commits atômicos e prefixos:
- `fix`: correção de bug
- `feat`: nova funcionalidade
- `imp`: melhoria/refactor sem nova feature
- `docs`: documentação
- `codex`: ajustes em arquivos de agente/overrides e arquivos usados apenas pelo Codex
