# Architecture (Roadmap)

## Fronteiras principais
- Conteúdo e curadoria: `conteudo/`, `questoes/`, `aulas/`, `templates/`, `prompts/`.
- Pipeline de publicação: `scripts/build_assets_release.py` e artefatos em `app_flutter/releases/`.
- Consumo no cliente: `app_flutter/enem_offline_client/` (SQLite local + importação de conteúdo).
- Planejamento determinístico: `planner/` e scripts associados em `scripts/`.

## Contratos e referências
- Arquitetura offline detalhada: `plano/arquitetura_conteudo_offline.md`.
- Compatibilidade app x conteúdo: `plano/politica_compatibilidade_atualizacao_offline.md`.
- Estado editorial padrão: `rascunho -> revisado -> aprovado -> publicado`.

## Restrições operacionais
- Sem backend obrigatório para uso principal.
- Conteúdo deve ser versionado e auditável.
- Atualização deve preservar funcionamento offline entre releases.
