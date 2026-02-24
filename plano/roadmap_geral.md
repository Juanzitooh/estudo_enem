# Roadmap Geral — Estudo ENEM + App Open Source

## Objetivo Macro
Transformar este repositório em um sistema completo de estudo para ENEM que:
- usa a Matriz do INEP como fonte pedagógica;
- usa questões reais para treino e calibração;
- gera plano de estudo com base em desempenho real;
- oferece um app gratuito e open source para praticar simulados offline.

## Próximo Passo Imediato
- [ ] Rodar `./dist.sh --version <versao> --base-url <url_base>` no Linux para validar pipeline end-to-end (conteúdo + build + execução local).

## Estado Atual (base já pronta)
- Matriz convertida para Markdown em `matriz/`.
- Banco de provas anteriores em `questoes/banco_reais/`.
- Mapeamento automático por disciplina/tema/habilidade em `questoes/mapeamento_habilidades/`.
- Planejador offline determinístico em `planner/` e `scripts/gerar_plano_offline.py`.
- App desktop inicial de planejamento em `scripts/app_planejador_pyside6.py`.
- Scaffold de cliente Flutter offline em `app_flutter/enem_offline_client/`.
- Índice dos livros com campo de habilidades em `plano/indice_livros_6_volumes.csv`.

## Fase 1 — Consolidação de Dados
- [ ] Validar qualidade da extração em amostras por ano (enunciado, alternativas, gabarito).
- [ ] Revisar pendências de mapeamento em `questoes/mapeamento_habilidades/revisao_pendente.md`.
- [ ] Definir versão estável do banco consolidado para consumo do app.
- [ ] Criar regra de atualização incremental quando entrar novo ano de prova.

## Fase 2 — Motor de Prática e Planejamento
- [ ] Calcular métricas por habilidade: acurácia, volume, tempo médio, reincidência de erro.
- [ ] Definir algoritmo de priorização por lacuna (sem IA, determinístico).
- [ ] Integrar índice dos livros ao motor para sugerir módulo exato do material.
- [ ] Gerar plano semanal automático com base em disponibilidade de tempo.

## Fase 3 — Seção dedicada: App Open Source Gratuito

### Escopo do App
- [ ] App Flutter offline-first (Windows, Linux, macOS e Android/APK).
- [ ] Banco local em SQLite para desempenho, histórico e preferências.
- [ ] Importação de dados por pacote versionado (CSV -> `assets.zip` -> SQLite local).
- [ ] Interface simples para resolver questões, corrigir e evoluir no plano.

### Funcionalidades do MVP
- [ ] Tela de filtros: ano, dia, área, disciplina, habilidade, dificuldade.
- [ ] Modo treino: resolver questões por habilidade com correção imediata.
- [ ] Modo simulado: montar prova com tempo e quantidade configuráveis.
- [ ] Histórico de tentativas com análise por habilidade.
- [ ] Recomendação de módulos do livro com base nas habilidades de maior erro.
- [ ] Sugestão automática de próximos blocos de estudo.

### “Dá para criar provas?”
Sim. Neste roadmap, “criar provas” significa montar simulados a partir do banco real com regras de montagem.
- [ ] Simulado por distribuição (exemplo: 10, 20, 45 ou 90 questões).
- [ ] Simulado por foco (exemplo: apenas H18/H22, ou apenas Matemática).
- [ ] Simulado misto por lacunas do aluno.
- [ ] Exportação do simulado em Markdown/PDF para uso offline.

### Regras de montagem de simulado (MVP)
- [ ] Não repetir a mesma questão em sequência de sessões recentes.
- [ ] Balancear dificuldade (fácil, média, difícil).
- [ ] Manter rastreabilidade: origem da questão (`ano`, `dia`, `numero`).
- [ ] Separar claramente treino por área e treino interdisciplinar.

### Diretriz de licença e uso
- [ ] Publicar o código sob licença permissiva (ex.: MIT).
- [ ] Manter créditos e origem dos dados oficiais (INEP/ENEM).
- [ ] Documentar no README que o app organiza estudo e não substitui fonte oficial.
- [ ] Separar release do app e release de conteúdo (`manifest.json` + `assets.zip`).

## Fase 4 — Qualidade de Produto
- [ ] Testes unitários para parser, seleção de questões e cálculo de métricas.
- [ ] Testes de regressão para evitar quebra em atualizações do banco.
- [ ] Validação manual de UX com fluxo real de estudo (ciclo semanal).
- [ ] Checklist de release para versões estáveis.

## Fase 5 — Comunidade Open Source
- [ ] Criar `CONTRIBUTING.md` com padrão de branch, commit e PR.
- [ ] Criar templates de issue para bug, melhoria e conteúdo.
- [ ] Publicar backlog inicial de issues “good first issue”.
- [ ] Documentar como rodar localmente sem dependências pagas.

## Cronograma sugerido (8 semanas)
- Semana 1–2: Fase 1 (consolidação e validação do banco).
- Semana 3–4: Fase 2 (motor de priorização + integração com módulos dos livros).
- Semana 5–6: Fase 3 MVP (app de treino/simulado funcional).
- Semana 7: Fase 4 (testes e refinos).
- Semana 8: Fase 5 (empacotar para comunidade).

## Critérios de Pronto (DoD)
- [ ] Usuário consegue montar e resolver um simulado completo offline.
- [ ] Resultado gera diagnóstico por habilidade automaticamente.
- [ ] Plano semanal é recalculado com base em desempenho recente.
- [ ] Sistema sugere quais módulos dos livros revisar para cada lacuna.
