# Relatório de Limpeza do Repositório

- Gerado em (UTC): **2026-02-26 21:04:01**
- Arquivos de referência analisados: **9**
- Entradas top-level classificadas: **26**
- Temporários seguros detectados: **0**
- Remoções seguras aplicadas: **0**

## Arquivos-base usados na auditoria
- `plano/roadmap_geral.md`
- `plano/roadmap_proximos_passos.md`
- `plano/arquitetura_conteudo_offline.md`
- `plano/politica_retencao_repositorio.md`
- `README.md`
- `dist.sh`
- `run_local.sh`
- `scripts/build_assets_release.py`
- `scripts/package_linux_artifacts.sh`

## Classificação top-level

| Caminho | Ação | Motivo |
|---|---|---|
| `.gitignore` | manter | pasta/arquivo essencial por politica |
| `.venv_mdpdf` | manter | configuracao local/oculta |
| `.vscode` | manter | configuracao local/oculta |
| `agents.global.md` | manter | referenciado no roadmap/build |
| `app_flutter` | manter | referenciado no roadmap/build |
| `assets` | manter | referenciado no roadmap/build |
| `aulas` | manter | referenciado no roadmap/build |
| `CHANGELOG.md` | manter | referenciado no roadmap/build |
| `dev_linux.sh` | manter | pasta/arquivo essencial por politica |
| `dist.sh` | manter | referenciado no roadmap/build |
| `edital.pdf` | manter | referenciado no roadmap/build |
| `install_linux.sh` | manter | pasta/arquivo essencial por politica |
| `LICENSE` | manter | pasta/arquivo essencial por politica |
| `matriz` | manter | referenciado no roadmap/build |
| `notes` | manter | referenciado no roadmap/build |
| `planner` | manter | referenciado no roadmap/build |
| `plano` | manter | referenciado no roadmap/build |
| `prompts` | manter | referenciado no roadmap/build |
| `questoes` | manter | referenciado no roadmap/build |
| `README.md` | manter | referenciado no roadmap/build |
| `run_local.sh` | manter | referenciado no roadmap/build |
| `scripts` | manter | referenciado no roadmap/build |
| `sources` | manter | referenciado no roadmap/build |
| `templates` | manter | referenciado no roadmap/build |
| `teste_aula_habilidade_base_h18.md` | manter | referenciado no roadmap/build |
| `teste_aula_habilidade_base_h18.pdf` | mover para archive | artefato de teste fora da arvore principal |

## Pendências para decisão manual
- `teste_aula_habilidade_base_h18.pdf` -> artefato de teste fora da arvore principal

## Limpeza segura (fase 1)
- Nenhum artefato temporário detectado.

## Resumo operacional
- `manter`: 25
- `mover para archive`: 1
- `remover` aplicado na fase 1: 0
