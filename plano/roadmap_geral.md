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

### Arquitetura de conteúdo versionado (offline-first)
- [x] Publicar briefing inicial da arquitetura em `plano/arquitetura_conteudo_offline.md`.
- [ ] Definir árvore canônica de conteúdo: `conteudo/raw/`, `conteudo/generated/`, `conteudo/reviewed/` e `conteudo/published/`.
- [ ] Separar bancos por domínio no conteúdo publicado: `banco_questoes`, `banco_aulas`, `banco_videos`, `banco_redacao`.
- [ ] Definir contrato de metadados editoriais comum: `source_type`, `source_url`, `source_date`, `generated_by`, `reviewed_by`, `review_status`, `version`, `updated_at`.
- [ ] Definir estado editorial obrigatório por item: `rascunho` -> `revisado` -> `aprovado` -> `publicado`.
- [ ] Criar pipeline de empacotamento para atualização: `manifest.json` + `assets.zip` + checksum.
- [ ] Definir política de compatibilidade entre versão de conteúdo e versão do app Flutter.
- [ ] Formalizar repositório como origem única de atualização (conteúdo versionado + scripts de build), mantendo app funcional 100% offline.

### Higienização contínua do repositório (sem perder histórico útil)
- [x] Definir política de retenção: o que permanece em `raw`, o que vira `archive` e o que pode ser removido após publicação (ver `plano/politica_retencao_repositorio.md`).
- [x] Criar checklist de limpeza por ciclo de release (arquivos temporários, saídas intermediárias, lotes obsoletos, duplicados).
- [x] Automatizar auditoria de pastas não referenciadas no roadmap/build (`scripts/auditar_pastas_orfas.py`).
- [x] Adicionar regra de segurança para nunca remover fontes oficiais, revisões manuais e artefatos publicados.
- [x] Publicar relatório de limpeza por versão com diff de arquivos removidos/movidos (`plano/relatorio_limpeza_repositorio.md`).

### Dependências de catalogação (separação explícita)
- [x] Itens que podem fechar antes do catálogo completo: estrutura de pastas, schemas, pipeline de build/publicação, perfil offline e import/export.
- [x] Itens bloqueados até catálogo completo dos 6 volumes: validação final de cobertura módulo->habilidade, curadoria final de aulas por módulo e calibração fina das recomendações.
- [x] Criar marcador de status por tarefa (`independe_catalogo` | `depende_catalogo`) para priorização operacional.

### Pós-catálogo: trilha transversal + atualização editorial (2019 -> 2026)
- [ ] (depende_catalogo) Classificar todos os módulos por nível pedagógico (`fundacao`, `intermediario`, `aplicado_enem`) e registrar pré-requisitos.
- [ ] (depende_catalogo) Montar grafo de dependências entre módulos independente de matéria para gerar ordem de estudo transversal.
- [ ] (depende_catalogo) Publicar sequência recomendada "do básico ao aplicado" com trilhas por perfil e carga horária.
- [ ] (depende_catalogo) Definir campo de maturidade por módulo (`basico_essencial`, `nucleo_enem`, `aprofundamento`) para evitar pular base necessária.
- [ ] (depende_catalogo) Rodar revisão de atualidade do acervo 2019 com delta 2020-2026 antes de gerar aulas finais.
- [ ] (depende_catalogo) Criar checklist de atualização por módulo: dados/contextos recentes, fatos brasileiros, exemplos atuais e fontes.
- [ ] (depende_catalogo) Adicionar metadados de atualização (`needs_update_2026`, `updated_2026_at`, `updated_2026_by`) e bloquear publicação final sem revisão.

## Fase 2 — Motor de Prática e Planejamento
- [ ] Calcular métricas por habilidade: acurácia, volume, tempo médio, reincidência de erro.
- [ ] Definir algoritmo de priorização por lacuna (sem IA, determinístico).
- [ ] Integrar índice dos livros ao motor para sugerir módulo exato do material.
- [ ] Gerar plano semanal automático com base em disponibilidade de tempo.

### Conteúdo didático por módulo (geração assistida)
- [ ] Definir schema mínimo de aula por módulo: `area`, `materia`, `volume`, `modulo`, `titulo`, `expectativas_aprendizagem`, `competencias/habilidades`.
- [ ] Criar pipeline para gerar rascunho de aula para cada módulo de conteúdo (excluir `tipo_modulo=exercicios`), usando template padronizado.
- [ ] Registrar metadados editoriais em cada aula: `ia_updated_at` (data/hora), `manual_reviewed_at` (data/hora) e `manual_reviewed_by` (nome).
- [ ] Definir objetivo pedagógico explícito por aula (o que o aluno deve saber, aplicar e revisar ao final do módulo).
- [ ] Incluir seção obrigatória de “o que deve ser aprendido” alinhada às expectativas de aprendizagem do módulo.
- [ ] Incluir seção obrigatória de “contexto atual” com fatos dos últimos 12 meses (com datas absolutas) e linguagem adequada ao ENEM.
- [ ] Priorizar exemplos brasileiros e regionalidades do Brasil; usar exemplos externos apenas quando forem essenciais ao conceito.
- [ ] Incluir seção de “problema real” (estudo de caso) para aprofundamento aplicado do conteúdo.
- [ ] Em Física/Química/Biologia/Matemática, incluir ao menos um recurso visual didático mínimo (gráfico, diagrama, esquema ou desenho explicativo).
- [ ] Incluir seção obrigatória de “checagem de entendimento” com 5-10 perguntas de recuperação ativa (curtas e retóricas) no fim de cada aula.
- [ ] Incluir seção obrigatória “erros comuns” e “como revisar” para consolidar retenção.
- [ ] Incluir seção “aprofundamento” com recomendações de vídeo por tema (usando índice de videoaulas por minutagem quando disponível).
- [ ] Definir rubrica de qualidade para aula gerada: correção conceitual, clareza, progressão didática, aderência ENEM e ausência de alucinação factual.
- [ ] Implementar validações automáticas mínimas do texto gerado (estrutura obrigatória, tamanho por seção, presença de perguntas finais, termos proibidos).
- [ ] Implementar workflow de revisão humana em lote (`rascunho` -> `revisado` -> `publicado`) antes de expor conteúdo no app.
- [ ] Salvar versão de conteúdo por módulo para permitir melhoria incremental e histórico de qualidade.
- [ ] Exibir no app o selo editorial da aula (`atualizado por IA em ...`, `revisado manualmente por ...`) para transparência.
- [ ] Integrar no app exibição de aula por módulo com bloco final “revise seu entendimento” e CTA para treino relacionado.

### Intercorrelação Matriz + Livro + Questões
- [x] Criar CSV de intercorrelação `modulo_questao_matches.csv` para ligar módulo do livro a questões reais.
- [x] Definir esquema do CSV com: `ano`, `dia`, `numero`, `variacao`, `area`, `disciplina`, `materia`, `modulo`, `competencias`, `habilidades`, `assuntos_match`, `score_match`, `tipo_match`, `confianca`, `revisado_manual`.
- [x] Criar taxonomia canônica de assuntos (`tags`) com sinônimos para reduzir ruído de keyword.
- [x] Implementar matching por múltiplos sinais: keyword, competência/habilidade, disciplina e expectativa de aprendizagem.
- [x] Incluir score de interrelação (não binário) para priorizar aprofundamento por aderência.
- [x] Registrar vínculos interdisciplinares explícitos (questão conectada a mais de uma matéria/eixo).
- [ ] Mapear pré-requisitos entre módulos para trilha de aprofundamento progressivo.
- [ ] Versionar o mapeamento para rastrear mudanças de regra ao longo do tempo.
- [ ] Criar CSV adicional de intercorrelação semântica (`modulo_assunto_keywords.csv`) para ligar expectativas, palavras-chave e temas por área.
- [ ] Incluir relações de aprofundamento e interdisciplinaridade explícitas (`modulo_origem`, `modulo_relacionado`, `motivo_relacao`).

### Banco de questões geradas (agent + revisão humana)
- [ ] Criar estrutura de conteúdo em `questoes/generateds/` separada por área (`linguagens`, `humanas`, `natureza`, `matematica`) e tipo (`treino`, `simulado`, `redacao`).
- [ ] Definir schema de questão gerada compatível com o banco real: cabeçalho, enunciado, alternativas A-E, gabarito, explicação, competência/habilidade, dificuldade, tags e fontes.
- [ ] Criar agent/script de geração orientado por habilidade para produzir lotes de questões inéditas no estilo ENEM (sem cópia literal).
- [ ] Implementar validações automáticas de qualidade: formato, distribuição de dificuldade, consistência do gabarito e detector de similaridade com questões reais.
- [ ] Exigir revisão humana antes de publicação com campos `reviewed_by`, `review_notes` e `approved_at`.
- [ ] Definir política de publicação incremental para liberar conteúdo gerado sem bloquear o banco real.

## Fase 3 — Seção dedicada: App Open Source Gratuito

### Escopo do App
- [ ] App Flutter offline-first (Windows, Linux, macOS e Android/APK).
- [ ] Banco local em SQLite para desempenho, histórico e preferências.
- [ ] Importação de dados por pacote versionado (CSV -> `assets.zip` -> SQLite local).
- [ ] Interface simples para resolver questões, corrigir e evoluir no plano.

### Perfil de usuário offline + portabilidade
- [x] Implementar perfil local com dados mínimos: `nome_exibicao`, `ano_alvo`, `dias_semana_estudo`, `horas_por_dia`, `foco_area`, `data_prova`.
- [x] Permitir múltiplos perfis locais e troca rápida de perfil no app.
- [x] Criar tela de "ficha do estudante" (onboarding editável) para contexto de planejamento.
- [x] Salvar planner/contexto no próprio perfil e permitir edição contínua.
- [x] Implementar exportação de perfil (JSON/ZIP) com histórico, métricas e plano.
- [x] Implementar importação de perfil com validação de versão e merge seguro.
- [x] Incluir no pacote exportado um arquivo de planejamento (`planejamento_profile.json`) para portabilidade completa.
- [x] Garantir que import/export funcione offline, sem backend e sem IA.

### Planejamento inteligente determinístico (sem IA)
- [x] Criar motor de estimativa de estudo por habilidade com base em `acurácia`, `recência`, `tempo disponível` e `dificuldade`.
- [x] Gerar plano diário/semanal automaticamente a partir da ficha do estudante (horas, dias e data-alvo).
- [x] Projetar previsão de carga por meta (`horas necessárias`, `habilidades por semana`, `risco de atraso`).
- [x] Recalcular o plano após cada sessão para refletir ganho/perda de domínio.
- [x] Exibir "próximas aulas recomendadas" por janela de dias (ex.: próximos 7 dias) com justificativa objetiva.
- [x] Permitir exportar/importar o plano junto do perfil para continuidade entre dispositivos.

### Funcionalidades do MVP
- [x] Tela de filtros: ano, dia, área, disciplina/matéria, competência, habilidade e `tem_imagem`.
- [x] Incluir filtro de dificuldade quando houver classificação disponível no banco.
- [x] Modo treino: resolver questões por habilidade com correção imediata.
- [x] Modo simulado: montar prova com tempo e quantidade configuráveis.
- [x] Histórico de tentativas com análise por habilidade.
- [x] Recomendação de módulos do livro com base nas habilidades de maior erro.
- [x] Sugestão automática de próximos blocos de estudo.

### Fluxo adaptativo de aprofundamento por erros
- [x] Implementar simulado diagnóstico por matéria com distribuição 3 fáceis + 3 médias + 3 difíceis.
- [ ] Exibir resultado do diagnóstico com score por matéria, Top 5 habilidades em déficit e erro dominante.
- [x] Criar tela "Habilidades em foco" com domínio (%), causa provável da queda e ações rápidas.
- [x] Disponibilizar ações por habilidade: Treinar agora (10 questões), Revisar teoria e Copiar prompt de estudo.
- [x] Classificar habilidades por faixa de domínio: foco (<55%), manutenção (55% a 75%) e forte (>75%).
- [x] Montar sessões adaptativas com distribuição 60% foco, 30% manutenção e 10% forte.
- [x] Recalcular foco automaticamente após cada sessão para substituir habilidades que melhorarem.

### Perfil de erro local (sem IA embarcada)
- [ ] Implementar `error_profile` por habilidade com: `pacing`, `level_break`, `topic_tags` e `pattern`.
- [ ] Inferir sinais locais: tempo alto + erro, erro rápido, erro recorrente por tag e erro em questão fácil.
- [ ] Armazenar "evidência do erro" via tags/tipo de questão sem expor texto de enunciado.

### Construtor de prompt para aprofundamento
- [x] Implementar `PromptBuilder` offline para gerar prompt copiável (uso externo em ChatGPT/YouTube).
- [x] Criar modo de prompt "Aula completa" com explicação, erros comuns, heurística, exemplos e plano de revisão.
- [x] Criar modo de prompt "Só vídeos" com palavras-chave e títulos sugeridos (sem inventar links).
- [x] Criar modo de prompt "Só treino" com exercícios progressivos sem entregar gabarito de questão real.
- [ ] Incluir no prompt: `skill_code`, `skill_description`, `area`, `module_title`, métricas e `error_profile`.

### Indexação de videoaulas YouTube por minutagem (futuro)
- [ ] Tratar índice de videoaulas como conteúdo versionado (`assets.zip`), com metadados e links, sem download/redistribuição de mídia.
- [ ] Padronizar pasta `build_assets/input/videos/` com arquivos `*.md` (fonte humana), `*.segments.csv` (parser) e `*.segment_skill.csv` (curadoria incremental).
- [ ] Implementar `scripts/parse_video_timestamps.py` para converter `*.md` em `*.segments.csv` e `*.segments.json`.
- [ ] Regras do parser: detectar grupos (`group_title`), converter `HH:MM:SS` para `start_sec`, normalizar títulos e inferir `end_sec` a partir do próximo segmento.
- [ ] Regras do parser: marcar `availability=external` em blocos de bônus/não liberados.
- [ ] Criar no SQLite de conteúdo a tabela `videos` (`platform`, `video_id`, `title`, `channel`, `language`).
- [ ] Criar no SQLite de conteúdo a tabela `video_segments` (`video_ref_id`, `group_title`, `segment_title`, `start_sec`, `end_sec`, `tags_json`, `availability`).
- [ ] Criar no SQLite de conteúdo a tabela opcional `segment_skill` (`segment_id`, `skill_id`, `weight`) para recomendação por habilidade.
- [ ] Implementar `scripts/import_videos.py` para importar CSV em SQLite com índices em `(video_id, start_sec)` e `group_title`.
- [ ] No app Flutter, exibir segmentos recomendados na tela de habilidade em foco e abrir link externo com `https://www.youtube.com/watch?v={video_id}&t={start_sec}s`.
- [ ] No app Flutter, exibir aviso visual quando `availability=external`.
- [ ] Criar arquivo base `build_assets/input/videos/youtube_bio_megaculao_001.md` (video_id `NOBaD0hCGYU`) com minutagem curada por capítulos.
- [ ] Iniciar curadoria de `*.segment_skill.csv` com tópicos-chave (ex.: Células, Mitose, Ecologia) para retorno por `skill_id`.
- [ ] Critérios de aceite: parser gera todos os segmentos, app lista por grupo, abre no timestamp correto e marca segmentos bônus com aviso.

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
- [ ] Criar banco de temas gerados (`redacao/generated_temas`) com status editorial e vínculo de fontes.
- [ ] Incluir campo obrigatório de referência para textos motivadores externos (fonte, data e contexto brasileiro).
- [ ] Definir trilha de curadoria para temas de redação gerados por IA (`rascunho` -> `revisado` -> `publicado`).

### Priorização automática por lacuna
- [x] Implementar prioridade dinâmica por habilidade com fórmula base: `priority = deficit + recency + (1 - confidence)`.
- [x] Definir `deficit = 1 - accuracy`, `confidence = ln(1 + attempts)` e `recency = min(0.3, dias_sem_ver * 0.02)`.
- [x] Selecionar Top N habilidades por prioridade para alimentar o próximo ciclo de foco.

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
- [ ] Para videoaulas externas, manter apenas deep links públicos por timestamp (sem espelhar ou redistribuir conteúdo de terceiros).

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
