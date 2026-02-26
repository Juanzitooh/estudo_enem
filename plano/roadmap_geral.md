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
- Lotes `tem_imagem` concluídos no banco 2015–2025 (resumo em `questoes/mapeamento_habilidades/resumo_lotes_tem_imagem.md`).
- Pendências de baixa confiança zeradas no ciclo atual com revisões em `questoes/mapeamento_habilidades/revisao_manual/`.
- Planejador offline determinístico em `planner/` e `scripts/gerar_plano_offline.py`.
- App desktop inicial de planejamento em `scripts/app_planejador_pyside6.py`.
- Scaffold de cliente Flutter offline em `app_flutter/enem_offline_client/`.
- Índice dos livros com campo de habilidades em `plano/indice_livros_6_volumes.csv`.

## Fase 1 — Consolidação de Dados
- [ ] Validar qualidade da extração em amostras por ano (enunciado, alternativas, gabarito).
- [x] Sinalizar `tem_imagem` por questão (heurística textual) para filtrar itens com figura/gráfico/tabela/tirinha.
- [x] Revisar pendências de mapeamento em `questoes/mapeamento_habilidades/revisao_pendente.md`.
- [ ] Definir versão estável do banco consolidado para consumo do app.
- [ ] Criar regra de atualização incremental quando entrar novo ano de prova.
- [ ] Planejar pipeline futuro de recorte de imagens da prova por questão (`asset_path` + metadados), sem bloquear MVP.

## Fase 2 — Motor de Prática e Planejamento
- [ ] Calcular métricas por habilidade: acurácia, volume, tempo médio, reincidência de erro.
- [ ] Definir algoritmo de priorização por lacuna (sem IA, determinístico).
- [ ] Integrar índice dos livros ao motor para sugerir módulo exato do material.
- [ ] Gerar plano semanal automático com base em disponibilidade de tempo.

### Intercorrelação Matriz + Livro + Questões
- [x] Criar CSV de intercorrelação `modulo_questao_matches.csv` para ligar módulo do livro a questões reais.
- [x] Definir esquema do CSV com: `ano`, `dia`, `numero`, `variacao`, `area`, `disciplina`, `materia`, `modulo`, `competencias`, `habilidades`, `assuntos_match`, `score_match`, `tipo_match`, `confianca`, `revisado_manual`.
- [x] Criar taxonomia canônica de assuntos (`tags`) com sinônimos para reduzir ruído de keyword.
- [x] Implementar matching por múltiplos sinais: keyword, competência/habilidade, disciplina e expectativa de aprendizagem.
- [x] Incluir score de interrelação (não binário) para priorizar aprofundamento por aderência.
- [x] Registrar vínculos interdisciplinares explícitos (questão conectada a mais de uma matéria/eixo).
- [ ] Mapear pré-requisitos entre módulos para trilha de aprofundamento progressivo.
- [ ] Versionar o mapeamento para rastrear mudanças de regra ao longo do tempo.

## Fase 3 — Seção dedicada: App Open Source Gratuito

### Escopo do App
- [ ] App Flutter offline-first (Windows, Linux, macOS e Android/APK).
- [ ] Banco local em SQLite para desempenho, histórico e preferências.
- [ ] Importação de dados por pacote versionado (CSV -> `assets.zip` -> SQLite local).
- [ ] Interface simples para resolver questões, corrigir e evoluir no plano.

### Funcionalidades do MVP
- [ ] Tela de filtros: ano, dia, área, disciplina/matéria, competência, habilidade, dificuldade e `tem_imagem`.
- [ ] Modo treino: resolver questões por habilidade com correção imediata.
- [ ] Modo simulado: montar prova com tempo e quantidade configuráveis.
- [ ] Histórico de tentativas com análise por habilidade.
- [ ] Recomendação de módulos do livro com base nas habilidades de maior erro.
- [ ] Sugestão automática de próximos blocos de estudo.

### Fluxo adaptativo de aprofundamento por erros
- [ ] Implementar simulado diagnóstico por matéria com distribuição 3 fáceis + 3 médias + 3 difíceis.
- [ ] Exibir resultado do diagnóstico com score por matéria, Top 5 habilidades em déficit e erro dominante.
- [ ] Criar tela "Habilidades em foco" com domínio (%), causa provável da queda e ações rápidas.
- [ ] Disponibilizar ações por habilidade: Treinar agora (10 questões), Revisar teoria e Copiar prompt de estudo.
- [ ] Classificar habilidades por faixa de domínio: foco (<55%), manutenção (55% a 75%) e forte (>75%).
- [ ] Montar sessões adaptativas com distribuição 60% foco, 30% manutenção e 10% forte.
- [ ] Recalcular foco automaticamente após cada sessão para substituir habilidades que melhorarem.

### Perfil de erro local (sem IA embarcada)
- [ ] Implementar `error_profile` por habilidade com: `pacing`, `level_break`, `topic_tags` e `pattern`.
- [ ] Inferir sinais locais: tempo alto + erro, erro rápido, erro recorrente por tag e erro em questão fácil.
- [ ] Armazenar "evidência do erro" via tags/tipo de questão sem expor texto de enunciado.

### Construtor de prompt para aprofundamento
- [ ] Implementar `PromptBuilder` offline para gerar prompt copiável (uso externo em ChatGPT/YouTube).
- [ ] Criar modo de prompt "Aula completa" com explicação, erros comuns, heurística, exemplos e plano de revisão.
- [ ] Criar modo de prompt "Só vídeos" com palavras-chave e títulos sugeridos (sem inventar links).
- [ ] Criar modo de prompt "Só treino" com exercícios progressivos sem entregar gabarito de questão real.
- [ ] Incluir no prompt: `skill_code`, `skill_description`, `area`, `module_title`, métricas e `error_profile`.

### Redação com IA externa (sem API no app)
- [ ] Manter arquitetura sem backend e sem chave de API (app como orquestrador pedagógico offline).
- [ ] Implementar dois modos de redação:
- [ ] `Modo 1` offline puro: tema oficial, estrutura fixa ENEM, checklist, foto da redação e progresso local.
- [ ] `Modo 2` IA assistida externa: gerar prompt no app, copiar/colar na IA externa e registrar resposta no app.
- [x] Criar `PromptBuilder` de redação para geração de tema inédito no estilo ENEM (evitando repetição 2015–2025).
- [x] Criar `PromptBuilder` de correção (transcrição, C1..C5, justificativas, melhorias, erros, reescrita e nota 0–1000).
- [x] Persistir sessões em tabela local `essay_sessions` com prompts, texto/foto, feedback bruto e notas por competência.
- [ ] Implementar parser opcional da resposta da IA:
- [x] modo livre (usuário cola qualquer formato);
- [x] modo validado (espera estrutura mínima, ex.: `C1: ...` até `C5: ...`).
- [x] Adicionar modo de legibilidade com alerta quando houver muitos trechos `[ILEGÍVEL]`.
- [x] Adicionar gamificação de redação por faixas de nota (Bronze/Prata/Ouro/Elite).
- [x] Incluir prompt automático de reescrita pós-correção mantendo estrutura original do aluno.

### Priorização automática por lacuna
- [ ] Implementar prioridade dinâmica por habilidade com fórmula base: `priority = deficit + recency + (1 - confidence)`.
- [ ] Definir `deficit = 1 - accuracy`, `confidence = ln(1 + attempts)` e `recency = min(0.3, dias_sem_ver * 0.02)`.
- [ ] Selecionar Top N habilidades por prioridade para alimentar o próximo ciclo de foco.

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
