# Política de Compatibilidade e Origem de Atualização (Offline)

## Objetivo
Definir um contrato único entre pacote de conteúdo e versões do app Flutter,
com origem de atualização centralizada no repositório.

## 1) Compatibilidade app x conteúdo
Todo `manifest.json` gerado por `scripts/build_assets_release.py` deve publicar:
- `schema`: versão do schema do bundle (`content_bundle.json`);
- `compatibility_policy.content_schema`: schema esperado pelo app;
- `compatibility_policy.app_min_version`: versão mínima do app compatível (opcional);
- `compatibility_policy.app_max_version`: versão máxima do app compatível (opcional).

Regras operacionais:
- Se `schema` for incompatível com o app, o update deve ser recusado.
- Se `app_min_version` estiver preenchido, app abaixo dessa versão não deve aplicar o pacote.
- Se `app_max_version` estiver preenchido, app acima dessa versão exige novo pacote compatível.

## 2) Origem única de atualização
Todo pacote deve declarar `update_origin` com:
- `source_type=repository`;
- `source_repo` (identificador do repositório);
- `build_script=scripts/build_assets_release.py`;
- `offline_first=true`.

Isso formaliza o repositório como fonte canônica de atualização:
- fonte versionada em `conteudo/published/<versao>/`;
- pacote de distribuição (`assets_<versao>.zip` + checksum);
- manifesto de conteúdo (`manifest.json`) com contrato editorial e de compatibilidade.

## 3) Fluxo padrão
1. Curadoria/geração de conteúdo no repositório.
2. Build com `scripts/build_assets_release.py`.
3. Publicação do snapshot versionado em `conteudo/published/<versao>/`.
4. App consome pacote e continua funcional offline até nova atualização.
