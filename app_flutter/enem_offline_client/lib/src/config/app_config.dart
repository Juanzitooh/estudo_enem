class AppConfig {
  const AppConfig._();

  // URL padrão exibida no campo de update do app.
  static const String defaultManifestUrl = String.fromEnvironment(
    'ENEM_MANIFEST_URL',
    defaultValue: 'http://127.0.0.1:8787/manifest.json',
  );

  // Diretório opcional para forçar caminho único do banco no Linux.
  // Quando vazio, o app usa ~/.local/share/estudo_enem_offline_client.
  static const String linuxDbDir = String.fromEnvironment(
    'ENEM_DB_DIR',
    defaultValue: '',
  );

  static const String linuxDbFileName = 'enem_offline.db';
  static const String linuxStableDataDirName = 'estudo_enem_offline_client';
}
