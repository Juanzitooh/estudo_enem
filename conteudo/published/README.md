# Conteúdo Publicado

Diretório de saída versionada para consumo no app.

## Convenções
- Snapshot por versão: `conteudo/published/<versao>/`.
- Manifest principal: `manifest.json`.
- Pacote de assets: `assets_<versao>.zip`.
- Checksum: `assets_<versao>.zip.sha256`.

## Manifests por domínio
Cada domínio mantém manifests por versão em:
- `conteudo/published/banco_questoes/<versao>.manifest.json`
- `conteudo/published/banco_aulas/<versao>.manifest.json`
- `conteudo/published/banco_videos/<versao>.manifest.json`
- `conteudo/published/banco_redacao/<versao>.manifest.json`

## Estado editorial
Fluxo padrão obrigatório no build de conteúdo:
`rascunho -> revisado -> aprovado -> publicado`
