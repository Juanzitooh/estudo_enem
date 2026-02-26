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
- [ ] Criar esquema de metadados por questão (`ano`, `dia`, `numero`, `area`, `disciplina`, `competencia`, `habilidade`, `dificuldade`, `tem_imagem`).
- [ ] Mapear questões reais para habilidades da matriz (`Hxx`).
- [ ] Gerar arquivo consolidado para consulta rápida do agente.

## Bloco 3 — Geração orientada por base real (médio prazo)
- [ ] Criar prompt-padrão para gerar questões novas por habilidade usando o banco real como referência de estilo.
- [ ] Incluir validação automática: distribuição 5/3/2 e alternativas A–E em linhas separadas.
- [ ] Incluir checklist de qualidade para detectar cópia literal de enunciados reais.

## Bloco 4 — Operação semanal (médio prazo)
- [ ] Integrar banco real ao fluxo de revisão semanal.
- [ ] Atualizar `plano/tracker.md` com campo de erro por habilidade (`Hxx`).
- [ ] Definir rotina de atualização quando novos cadernos forem adicionados ao repositório.

## Bloco 5 — Redação com IA externa (curto/médio prazo)
- [ ] Definir schema local `essay_sessions` para histórico de redações (tema, prompts, texto/foto, retorno IA e notas C1..C5).
- [x] Implementar fluxo de cópia de prompt no app (sem chamada HTTP): gerar tema e corrigir redação.
- [x] Criar prompt de geração de tema ENEM com bloqueio de repetição de temas oficiais.
- [x] Criar prompt de correção ENEM com saída estruturada por competência.
- [ ] Implementar parser opcional da resposta IA (`modo livre` + `modo validado` por regex).
- [ ] Exibir feedback de legibilidade quando houver muitos marcadores `[ILEGÍVEL]`.
- [ ] Persistir evolução e ranking de redação (faixas de nota e progresso no tempo).

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
- [ ] Integrar filtros no app por `matéria`, `competência`, `habilidade` e `tem_imagem`.

## Próxima sessão sugerida
1. Rodar auditoria amostral das revisões manuais aplicadas em `revisao_manual/overrides.csv`.
2. Implementar indexação por habilidade/competência em lote.
3. Gerar primeiro simulado de treino totalmente ancorado no banco real.
