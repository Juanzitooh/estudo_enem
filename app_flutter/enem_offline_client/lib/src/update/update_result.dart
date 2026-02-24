class UpdateResult {
  const UpdateResult({
    required this.updated,
    required this.currentVersion,
    required this.message,
  });

  final bool updated;
  final String currentVersion;
  final String message;
}
