# Architecture (Roadmap)

## Fronteiras principais
- Conteúdo e curadoria: `conteudo/`, `questoes/`, `aulas/`, `templates/`, `prompts/`.
- Pipeline de publicação: `scripts/build_assets_release.py` e artefatos em `app_flutter/releases/`.
- Consumo no cliente: `app_flutter/enem_offline_client/` (SQLite local + importação de conteúdo).
- Planejamento determinístico: `planner/` e scripts associados em `scripts/`.
- Camada conceitual incremental: contratos de grafo (`conceito -> questão -> módulo`) para o feed adaptativo.

## Modelos editoriais de aula (convivência)
- `aula_habilidade_enem`: cobertura canônica da Matriz INEP por habilidade (`Hxx`).
- `aula_modulo_enem`: aula completa por módulo (base conceitual + aplicação ENEM).
- `aula_modulo_recuperacao_rapida_enem`: intervenção curta pós-erro para retomada de conceito.

## Contratos e referências
- Arquitetura offline detalhada: `plano/arquitetura_conteudo_offline.md`.
- Compatibilidade app x conteúdo: `plano/politica_compatibilidade_atualizacao_offline.md`.
- Estado editorial padrão: `rascunho -> revisado -> aprovado -> publicado`.
- Referência técnica do canvas de grafo: `docs/roadmap/references/aprendizado_grafo.md`.

## Contrato mínimo da camada de conceitos (piloto M2)
- `concepts`: catálogo de conceitos canônicos (`id`, `label`, `area`, `difficulty`).
- `question_concepts`: Q-matrix esparsa (`question_id`, `concept_id`, `weight`).
- `concept_dependencies`: pré-requisitos (`concept_id`, `depends_on`, `strength`).
- `concept_mastery`: domínio local por perfil (`profile_id`, `concept_id`, `mastery`, `updated_at`).
- `concept_priority_weights`: pesos estruturais por conceito (`concept_id`, `base_weight`, `reason`).

## Política de estudo (reels -> aula)
- Entrada principal: feed de questões (`reels`) com priorização híbrida.
- Pós-erro: roteamento para `recuperação rápida` quando houver contato prévio suficiente.
- Escalada: roteamento para `aula completa` quando houver baixa base/primeiro contato/baixa retenção.
- Retorno ao feed: após critério mínimo de saída (microtreino/checagem).

## Métricas de perfil (matriz + grafo + aulas)
- Cobertura INEP por habilidade (`tentadas`, `domínio estimado`, `lacunas críticas`).
- Domínio por conceito no grafo (`mastery`, `tendência`, `pré-requisitos pendentes`).
- Consumo de aulas (`completas concluídas`, `recuperações rápidas concluídas`, `tempo total`).

## Restrições operacionais
- Sem backend obrigatório para uso principal.
- Conteúdo deve ser versionado e auditável.
- Atualização deve preservar funcionamento offline entre releases.
- Operação atual por habilidade deve seguir funcional durante a transição para feed híbrido.
