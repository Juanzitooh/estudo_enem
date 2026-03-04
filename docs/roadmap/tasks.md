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

## M3 - Aulas por módulo operacional
- [ ] T3.1 Avaliar manualmente o lote piloto de 20 módulos com rubrica.
Aceite: notas por módulo registradas e gaps recorrentes consolidados.
- [ ] T3.2 Ajustar prompt/template com base no retrabalho identificado.
Aceite: checklist de gaps reduzido e versão do prompt incrementada.
- [ ] T3.3 Definir integração de aprofundamento por vídeo (minutagem).
Aceite: proposta técnica aprovada com campos e fluxo no app.
- [ ] T3.4 Definir workflow de revisão humana em lote (`rascunho -> revisado -> publicado`).
Aceite: fluxo e critérios de aprovação documentados.

## M4 - Publicação de conteúdo offline
- [x] T4.1 Estruturar árvore canônica `conteudo/{raw,generated,reviewed,published}`.
Aceite: diretórios existentes e documentados.
- [x] T4.2 Publicar pipeline `manifest + assets + checksum` com contrato editorial.
Aceite: script gera artefatos consistentes e manifests por domínio.
- [ ] T4.3 Versionar conteúdo por módulo para histórico incremental.
Aceite: estratégia de versionamento por módulo definida e aplicada.

## M5 - Distribuição do app
- [ ] T5.1 Evoluir `dist.sh` para APK opcional por versão com checksum.
Aceite: artefato e hash gerados com registro no resumo de release.
- [ ] T5.2 Definir fluxo de assinatura Android (`debug/local` x `release`).
Aceite: checklist mínimo de assinatura e validação publicado.

## M6 - Pós-catálogo (bloqueado)
- [ ] T6.1 Classificar módulos por nível e pré-requisitos.
Aceite: catálogo completo classificado.
- [ ] T6.2 Publicar trilhas transversais por perfil/carga horária.
Aceite: trilhas validadas com critérios de progressão.
