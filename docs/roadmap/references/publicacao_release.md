# Publicação e Release (Sem Dependência de Catalogação)

Status: aprovado  
Data: 2026-03-06  
Cobertura: `T4.3`, `T5.2`

## 1) Versionamento incremental por módulo (`T4.3`)

Objetivo:
- versionar conteúdo por módulo com histórico auditável e atualização incremental no cliente.

Convenção recomendada:
- `module_id`: identificador estável (`v{volume}_{materia}_m{modulo}_{slug}`).
- `module_version`: semver curta (`MAJOR.MINOR.PATCH`) ou timestamp controlado.

Regras:
- `PATCH`: ajuste textual sem alterar intenção pedagógica das questões.
- `MINOR`: inclusão/remoção de bloco pedagógico ou atualização relevante de contexto.
- `MAJOR`: quebra de contrato do payload ou mudança estrutural da aula.

Manifest de conteúdo:
- manter versão global de release (bundle).
- incluir mapa por módulo:
  - `module_id`
  - `module_version`
  - `checksum`
  - `updated_at`
  - `status_editorial`

Aplicação no cliente:
- detectar módulo alterado por `module_id + module_version`.
- manter histórico local de tentativas antigas.
- marcar tentativas como `desatualizadas` quando versão de aula mudar.

## 2) Fluxo de assinatura Android (`T5.2`)

Objetivo:
- separar assinatura para uso local (`debug`) e distribuição (`release`).

Perfis:
- `debug/local`:
  - chave debug padrão do Flutter/Android;
  - uso para testes locais e validação interna.
- `release`:
  - keystore própria do projeto;
  - senha e aliases fora do repositório;
  - assinatura obrigatória antes de distribuir APK/AAB.

Checklist mínimo de release:
1. gerar build release (`flutter build apk --release` ou `appbundle`);
2. verificar assinatura (`apksigner verify --print-certs <apk>`);
3. gerar hash SHA256 do artefato;
4. registrar versão + hash no resumo da release;
5. validar instalação limpa em dispositivo de teste.

Arquivos e segredos:
- não versionar `key.properties` com credenciais reais;
- usar `key.properties.example` no repositório;
- armazenar keystore e segredos em cofre local/CI seguro.

Observação operacional:
- enquanto `T5.1` não estiver concluída, a assinatura permanece como etapa manual guiada por checklist.
