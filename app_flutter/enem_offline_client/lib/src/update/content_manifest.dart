class ContentManifest {
  ContentManifest({
    required this.version,
    required this.archiveFile,
    required this.bundleFile,
    required this.sha256,
    required this.size,
    required this.generatedAt,
    required this.questionCount,
    required this.bookModuleCount,
    required this.moduleQuestionMatchCount,
    this.downloadUrl,
  });

  final String version;
  final String archiveFile;
  final String bundleFile;
  final String sha256;
  final int size;
  final String generatedAt;
  final int questionCount;
  final int bookModuleCount;
  final int moduleQuestionMatchCount;
  final String? downloadUrl;

  factory ContentManifest.fromJson(Map<String, dynamic> json) {
    final legacyAssetFile = (json['asset_file'] ?? '').toString();
    return ContentManifest(
      version: (json['version'] ?? '').toString(),
      archiveFile: (json['archive_file'] ?? legacyAssetFile).toString(),
      bundleFile: (json['bundle_file'] ?? 'content_bundle.json').toString(),
      sha256: (json['sha256'] ?? '').toString(),
      size: int.tryParse('${json['size']}') ?? 0,
      generatedAt: (json['generated_at'] ?? '').toString(),
      questionCount: int.tryParse('${json['question_count']}') ?? 0,
      bookModuleCount: int.tryParse('${json['book_module_count']}') ?? 0,
      moduleQuestionMatchCount:
          int.tryParse('${json['module_question_match_count']}') ?? 0,
      downloadUrl: (json['download_url'] ?? '').toString().isEmpty
          ? null
          : (json['download_url'] ?? '').toString(),
    );
  }
}
