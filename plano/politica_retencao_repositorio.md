# Politica de Retencao e Limpeza do Repositorio

## Objetivo
Manter o repositorio limpo sem perder rastreabilidade de dados oficiais, revisoes humanas e artefatos publicados.

## Regra geral
- Nada e removido sem classificacao previa em relatorio.
- Priorizar `mover para archive` antes de `remover`.
- Limpeza automatica so pode atuar em temporarios seguros (cache/artefatos efemeros).

## Politica por dominio

| Pasta/Dominio | Acao padrao | Observacao |
|---|---|---|
| `questoes/banco_reais/` | manter | fonte oficial extraida; nao remover sem substituicao validada |
| `questoes/mapeamento_habilidades/` | manter | inclui revisao manual e intercorrelacao |
| `plano/` | manter | planejamento, roadmaps e politicas de produto |
| `app_flutter/` | manter | codigo cliente e release metadata |
| `scripts/` | manter | pipeline de geracao, build e auditoria |
| `conteudo/raw/` (futuro) | manter + archive por ciclo | fonte bruta fica preservada por versao |
| `conteudo/generated/` (futuro) | mover para `archive` apos publicacao | manter somente ultimo ciclo ativo |
| `conteudo/reviewed/` (futuro) | manter | base de historico editorial |
| `conteudo/published/` (futuro) | manter | produto final versionado consumido no app |

## Classificacao operacional
- `manter`: arquivo/pasta referenciado no roadmap, pipeline ou politicas.
- `mover para archive`: artefato util para historico, mas fora do fluxo ativo.
- `remover`: apenas temporario seguro (`__pycache__`, `*.pyc`, `.DS_Store`, etc.).

## Guard rails de seguranca
- Nunca remover:
- dados oficiais do ENEM;
- revisoes manuais (`overrides`, lotes e anotacoes);
- manifestos e bundles publicados;
- documentos de arquitetura e roadmap.
- Toda remocao automatica deve evitar arquivos versionados (`git ls-files`).

## Dependencia de catalogacao completa
- Pode executar agora: auditoria de orfaos, limpeza segura fase 1, criacao de relatorios.
- So apos catalogacao completa dos 6 volumes:
- limpeza final de conteudo intermediario de mapeamento;
- consolidacao final de arquivos `generated` e `reviewed`;
- decisoes de archive de materiais de apoio nao usados.

## Comandos operacionais
- Auditoria (sem remover): `python3 scripts/auditar_pastas_orfas.py`
- Limpeza segura fase 1: `python3 scripts/auditar_pastas_orfas.py --apply-safe-clean`
