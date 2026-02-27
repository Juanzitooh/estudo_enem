# Roadmap — Próximos Passos (continuação)

## Objetivo imediato
Consolidar o banco de questões reais e evoluir para um gerador de treino por habilidade da matriz ENEM.

## Bloco 1 — Qualidade da extração (curto prazo)
- [ ] Revisar manualmente amostra de 20 questões do Dia 1 e 20 do Dia 2.
- [ ] Identificar ruídos em enunciados com imagem/tabela/fórmula.
- [ ] Definir critérios de limpeza mínima para manter fidelidade sem perder contexto.
- [x] Publicar flag `tem_imagem` por questão (lotes concluídos, sem recorte de asset).
- [x] Quebrar pendências de baixa confiança em lotes operacionais (`lotes_revisao/lote_*.md`).
- [x] Aplicar revisão manual em lotes até zerar pendências de `confianca=baixa`.

## Bloco 2 — Indexação por habilidade (curto prazo)
- [x] Criar esquema de metadados por questão (`ano`, `dia`, `numero`, `area`, `disciplina`, `competencia`, `habilidade`, `dificuldade`, `tem_imagem`).
- [x] Mapear questões reais para habilidades da matriz (`Hxx`).
- [x] Gerar arquivo consolidado para consulta rápida do agente.

## Bloco 3 — Geração orientada por base real (médio prazo)
- [x] Criar prompt-padrão para gerar questões novas por habilidade usando o banco real como referência de estilo.
- [x] Incluir validação automática: distribuição 5/3/2 e alternativas A–E em linhas separadas.
- [x] Incluir checklist de qualidade para detectar cópia literal de enunciados reais.

## Bloco 8 — Arquitetura de conteúdo e publicação offline (curto prazo)
- [x] Publicar briefing de arquitetura em `plano/arquitetura_conteudo_offline.md`.
- [ ] Definir estrutura de pastas: `conteudo/raw`, `conteudo/generated`, `conteudo/reviewed`, `conteudo/published`.
- [ ] Definir manifests por domínio: `banco_questoes`, `banco_aulas`, `banco_videos`, `banco_redacao`.
- [ ] Padronizar metadados editoriais em todos os itens: `generated_by`, `reviewed_by`, `review_status`, `version`, `updated_at`, `source_url`.
- [ ] Implementar estado editorial padrão (`rascunho` -> `revisado` -> `aprovado` -> `publicado`) nos scripts de build.
- [ ] Fechar pipeline de publicação `manifest.json + assets.zip + checksum` para consumo no app Flutter.

## Bloco 9 — Questões geradas por agent (médio prazo)
- [x] Criar `questoes/generateds/` por área (`linguagens`, `humanas`, `natureza`, `matematica`) com schema compatível ao banco real.
- [x] Definir contrato obrigatório por questão gerada: enunciado, A-E, gabarito, explicação, competência, habilidade, dificuldade, tags e fontes.
- [x] Implementar script/agent de geração por habilidade com lotes auditáveis e rastreabilidade de prompt.
- [ ] Expandir validação de qualidade pós-geração: formato e consistência base já cobertos em `scripts/validar_questoes_geradas.py`; falta score de similaridade com base real.
- [ ] Publicar somente itens com revisão humana aprovada.

## Bloco 10 — Limpeza guiada do repositório (curto prazo)
- [x] Definir política de retenção por pasta (`raw`, `generated`, `reviewed`, `published`, `archive`) em `plano/politica_retencao_repositorio.md`.
- [x] Criar script de auditoria para detectar pastas/arquivos órfãos em relação ao roadmap e ao pipeline de build (`scripts/auditar_pastas_orfas.py`).
- [x] Gerar relatório de limpeza com proposta de ação: `manter`, `mover para archive`, `remover` (`plano/relatorio_limpeza_repositorio.md`).
- [x] Executar limpeza segura fase 1 (somente temporários e duplicados evidentes).
- [x] Marcar tarefas de limpeza que dependem do catálogo completo antes de execução final.

## Bloco 11 — Perfil offline + planner portável (curto/médio prazo)
- [x] Criar schema local de perfil de estudante (`student_profiles`) com ficha editável de contexto.
- [x] Implementar multi-perfil com troca rápida (ex.: Perfil A / Perfil B).
- [x] Implementar export/import de perfil com histórico e plano (`profile_export.zip`).
- [x] Validar compatibilidade de versão durante importação e registrar migração quando necessário.
- [x] Salvar e restaurar planejamento inteligente no perfil importado sem perda de progresso.
- [x] Implementar motor determinístico de planejamento por horas/dias disponíveis e data-alvo.
- [x] Exibir previsão de estudo para os próximos dias com base no perfil + desempenho atual.

## Bloco 12 — Pós-catálogo (após concluir 100% dos 6 volumes)
- [ ] Classificar módulos por nível (`fundacao`, `intermediario`, `aplicado_enem`) e pré-requisitos.
- [ ] Construir ordem transversal de módulos independente de matéria (grafo de progressão).
- [ ] Publicar trilhas recomendadas por perfil/carga horária com caminho "base -> aplicação".
- [ ] Rodar revisão de atualização do acervo 2019 para 2026 antes de gerar aulas finais.
- [ ] Criar checklist editorial por módulo com foco em contexto brasileiro recente e fontes.
- [ ] Marcar e controlar metadados de atualização (`needs_update_2026`, `updated_2026_at`, `updated_2026_by`).

## Bloco 4 — Operação semanal (médio prazo)
- [ ] Integrar banco real ao fluxo de revisão semanal.
- [ ] Atualizar `plano/tracker.md` com campo de erro por habilidade (`Hxx`).
- [ ] Definir rotina de atualização quando novos cadernos forem adicionados ao repositório.

## Bloco 7 — Aulas por módulo (curto/médio prazo)
- [ ] Definir template final de “aula por módulo de conteúdo” com objetivos + explicação + perguntas finais de retenção.
- [ ] Incluir no template campos editoriais obrigatórios: `atualizado por IA em` + `revisado manualmente em` + `revisado por`.
- [ ] Ajustar prompt/agent para exigir exemplos de cotidiano brasileiro e aplicação prática por matéria (evitar contexto genérico/artificial).
- [ ] Incluir bloco fixo de questões contextualizadas por módulo com situações reais de dia a dia e profissões.
- [ ] Gerar primeiro lote piloto (ex.: 20 módulos) e medir qualidade com rubrica objetiva.
- [ ] Ajustar prompt/template até reduzir retrabalho humano para nível operacional.
- [ ] Planejar integração com índice de videoaulas por minutagem para aprofundamento opcional no fim da aula.

## Bloco 5 — Redação com IA externa (curto/médio prazo)
- [x] Definir schema local `essay_sessions` para histórico de redações (tema, prompts, texto/foto, retorno IA e notas C1..C5).
- [x] Implementar fluxo de cópia de prompt no app (sem chamada HTTP): gerar tema e corrigir redação.
- [x] Criar prompt de geração de tema ENEM com bloqueio de repetição de temas oficiais.
- [x] Criar prompt de correção ENEM com saída estruturada por competência.
- [x] Incluir prompt automático de reescrita pós-correção mantendo estrutura original do aluno.
- [x] Implementar parser opcional da resposta IA (`modo livre` + `modo validado` por regex).
- [x] Exibir feedback de legibilidade quando houver muitos marcadores `[ILEGÍVEL]`.
- [x] Persistir evolução e ranking de redação (faixas de nota e progresso no tempo).
- [ ] Criar fluxo para tema de redação gerado por IA com status editorial e referência de fontes motivadoras.
- [ ] Criar bloco de textos de apoio reais com curadoria e citação explícita (fonte + data).

## Bloco 6 — Intercorrelação Módulo x Questão (curto/médio prazo)
- [x] Criar `questoes/mapeamento_habilidades/intercorrelacao/modulo_questao_matches.csv` com score e confiança por vínculo.
- [x] Definir e publicar um catálogo de `tags_assunto` canônicas (com sinônimos).
- [x] Implementar script de matching inicial por `keywords + habilidades + competências + expectativas`.
- [x] Classificar tipo de vínculo: `direto`, `relacionado`, `interdisciplinar`.
- [ ] Marcar candidatos de baixa confiança para revisão manual em lote.
- [x] Expor no app filtros por `módulo`, `assunto`, `tipo_match` e `score_match`.

## Backlog futuro (pós-lotes `tem_imagem`)
- [ ] Validar precisão da flag `tem_imagem` em amostra manual por área.
- [ ] Adicionar campo `depende_contexto_visual` para priorizar revisão manual de itens com imagem.
- [ ] Planejar extração de recortes de imagem por questão (`asset_path` + coordenadas).
- [x] Integrar filtros no app por `matéria`, `competência`, `habilidade` e `tem_imagem`.
- [ ] Planejar pipeline de videoaulas por minutagem (`*.md` -> `*.segments.csv` -> SQLite) com deep link YouTube por `start_sec`.
- [ ] Definir seed inicial de vídeos com `youtube_bio_megaculao_001.md` e mapeamento manual inicial `segment_skill` para habilidades INEP.

## Próxima sessão sugerida
1. Expandir validação de qualidade pós-geração com score de similaridade em relação ao banco real.
2. Integrar previsão do planner com abertura direta da tela de módulo/treino por skill.
3. Definir e iniciar classificação calibrada de `dificuldade` no consolidado.
