# Agents - Roadmap Local

Este arquivo define a entrada canônica de planejamento para agentes neste repositório.

## Ordem de leitura obrigatória
1. `docs/roadmap/status.md`
2. `docs/roadmap/tasks.md`
3. `docs/roadmap/milestones.md`
4. `docs/roadmap/roadmap.md`
5. `docs/roadmap/architecture.md`
6. `docs/roadmap/decisions.md`

## Ponte com contexto legado (`plano/`)
Os arquivos abaixo seguem válidos como base histórica e detalhamento:
- `plano/roadmap_geral.md`
- `plano/roadmap_proximos_passos.md`
- `plano/arquitetura_conteudo_offline.md`
- `plano/politica_compatibilidade_atualizacao_offline.md`

Regra: não apagar conteúdo de `plano/`; usar `docs/roadmap/` como camada de execução e coordenação.

## Loop operacional (obrigatório)
1. Ler `CURRENT_MILESTONE` e `NEXT_TASK` em `status.md`.
2. Localizar a tarefa em `tasks.md` e executar escopo mínimo validável.
3. Rodar validação técnica (testes/checks aplicáveis).
4. Atualizar `status.md`, `tasks.md`, `milestones.md` e `CHANGELOG.md` quando aplicável.

## Regras locais de execução
- Não iniciar tarefa fora de `tasks.md` sem registrar antes.
- Não alterar arquitetura sem registrar em `decisions.md`.
- Preferir tarefas com impacto localizado.
- Evitar commit misto grande de código + documentação quando possível.
