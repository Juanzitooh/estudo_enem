# Tasks

Legenda de status: `[ ]` pendente, `[-]` em andamento, `[x]` concluída.

## M1 - Qualidade da base real
- [ ] T1.1 Revisar amostra manual de 20 questões (Dia 1) e 20 (Dia 2).
Aceite: relatório curto com ruídos recorrentes e ações por tipo de erro.
- [ ] T1.2 Definir versão estável do banco consolidado.
Aceite: versão nomeada, congelada e referenciada no roadmap.
- [ ] T1.3 Definir regra de atualização incremental para novos anos.
Aceite: fluxo documentado com entrada, validação e publicação.

## M2 - Planner + treino operacional
- [ ] T2.1 Integrar previsão do planner com abertura direta da tela de treino/módulo.
Aceite: ação na UI abre treino/módulo correspondente sem etapa manual extra.
- [ ] T2.2 Atualizar `plano/tracker.md` com campo de erro por habilidade (`Hxx`).
Aceite: modelo atualizado e validado em uso local.
- [ ] T2.3 Documentar rotina de atualização ao adicionar novos cadernos.
Aceite: procedimento reproduzível com checklist.
- [ ] T2.4 Definir contrato mínimo da camada de conceitos (`concepts`, `question_concepts`, `concept_dependencies`, `concept_mastery`).
Aceite: contrato documentado em `docs/roadmap/architecture.md` com exemplo de bundle offline.
- [ ] T2.5 Gerar Q-matrix piloto para 1 área sem depender do catálogo completo.
Aceite: mínimo de 80 questões mapeadas para 25+ conceitos com cobertura auditável.
- [ ] T2.6 Implementar seleção híbrida de feed (`habilidade + conceito`) no cliente offline.
Aceite: fallback por habilidade ativo quando não houver mapeamento conceitual.
- [ ] T2.7 Implementar diagnóstico pós-erro curto por conceito (3 perguntas objetivas).
Aceite: respostas atualizam `concept_mastery` local e influenciam a próxima recomendação.
- [ ] T2.8 Rodar avaliação comparativa do feed atual vs feed híbrido.
Aceite: relatório com métricas offline (`acurácia`, `tempo`, `retenção`) e decisão de rollout.
- [ ] T2.9 Definir política de roteamento pós-erro (`reels -> recuperação rápida` vs `aula completa`).
Aceite: regra documentada com gatilhos mínimos (`primeiro contato`, `mastery`, `acertos no microtreino`).
- [ ] T2.10 Definir pesos de conceitos fundacionais no grafo.
Aceite: tabela de pesos inicial aprovada para leitura/interpretação e matemática básica com impacto explícito no ranking.
- [ ] T2.11 Definir painel de métricas de perfil (`matriz INEP + grafo + aulas`).
Aceite: contrato de métricas documentado com campos de cobertura por habilidade, domínio por conceito e aulas concluídas.
- [ ] T2.12 Definir contrato de modos de sessão (`adaptativo` vs `prova oficial`).
Aceite: contrato documentado com seleção de modo, parâmetros mínimos (`ano`, `dia`, `ordem`) e regra explícita de desligamento adaptativo na prova oficial.
- [ ] T2.13 Implementar fluxo de prova oficial ENEM por ano/dia no app.
Aceite: usuário seleciona `ano/dia`, resolve caderno em sequência fechada e conclui sessão sem roteamento pós-erro durante a prova.

## M3 - Aulas por módulo operacional
- [ ] T3.1 Avaliar manualmente o lote piloto de 20 módulos com rubrica.
Aceite: notas por módulo registradas e gaps recorrentes consolidados.
- [x] T3.2 Ajustar prompt/template com base no retrabalho identificado.
Aceite: checklist de gaps reduzido e versão do prompt incrementada.
- [x] T3.3 Definir integração de aprofundamento por vídeo (minutagem).
Aceite: proposta técnica aprovada com campos e fluxo no app.
- [x] T3.4 Definir workflow de revisão humana em lote (`rascunho -> revisado -> publicado`).
Aceite: fluxo e critérios de aprovação documentados.
- [x] T3.5 Pilotar o template de recuperação rápida em 1 módulo real.
Aceite: 1 aula rápida preenchida, revisada e testada no fluxo pós-erro.
- [x] T3.6 Consolidar a taxonomia editorial dos 3 tipos de aula.
Aceite: documentação única com papéis e gatilhos de uso para `habilidade`, `módulo completo` e `recuperação rápida`.
- [x] T3.7 Definir contrato `lesson_payload_aluno` derivado de `aula_modulo_enem` aprovado.
Aceite: especificação documentada com campos pedagógicos exibíveis, campos editoriais internos e regra de transformação `md -> payload`.
- [x] T3.8 Implementar player de aula no app com persistência mínima local.
Aceite: aluno abre aula na aba `Aulas`, responde questões no app, finaliza correção com gabarito oculto prévio e retoma estado local ao reabrir.
- [x] T3.9 Implementar regra de desbloqueio de aprofundamento por tentativa mínima.
Aceite: seção de aprofundamento permanece bloqueada até o aluno tentar ao menos 1 questão da aula.
- [x] T3.10 Implementar interrelação versionada `aula <-> questão`.
Aceite: vínculo por `lesson_id`, `question_id`, `lesson_version` e regra documentada para marcar tentativa como desatualizada quando a questão for revisada.
- [ ] T3.11 Consolidar decisão final dos templates após catalogação completa.
Aceite: decisão final registrada com base na catalogação dos 6 volumes e checklist de ajustes finais aprovado.

## M4 - Publicação de conteúdo offline
- [x] T4.1 Estruturar árvore canônica `conteudo/{raw,generated,reviewed,published}`.
Aceite: diretórios existentes e documentados.
- [x] T4.2 Publicar pipeline `manifest + assets + checksum` com contrato editorial.
Aceite: script gera artefatos consistentes e manifests por domínio.
- [x] T4.3 Versionar conteúdo por módulo para histórico incremental.
Aceite: estratégia de versionamento por módulo definida e aplicada.

## M5 - Distribuição do app
- [x] T5.1 Evoluir `dist.sh` para APK opcional por versão com checksum.
Aceite: artefato e hash gerados com registro no resumo de release.
- [x] T5.2 Definir fluxo de assinatura Android (`debug/local` x `release`).
Aceite: checklist mínimo de assinatura e validação publicado.

## M6 - Pós-catálogo (bloqueado)
- [ ] T6.1 Classificar módulos por nível e pré-requisitos.
Aceite: catálogo completo classificado.
- [ ] T6.2 Publicar trilhas transversais por perfil/carga horária.
Aceite: trilhas validadas com critérios de progressão.
