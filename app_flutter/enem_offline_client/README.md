# enem_offline_client

MVP Flutter para estudo ENEM offline.

## Rodar

```bash
flutter pub get
flutter run -d linux
```

## Estrutura

- `lib/main.dart`: entrada do app.
- `lib/src/ui/home_page.dart`: interface mínima.
- `lib/src/data/local_database.dart`: banco SQLite local.
- `lib/src/update/content_manifest.dart`: modelo de manifest.
- `lib/src/update/content_updater.dart`: fluxo de update com SHA256.

O app mostra:
- status do conteúdo local;
- habilidades com maior erro pelo histórico;
- sugestão de módulos do livro para revisar.
