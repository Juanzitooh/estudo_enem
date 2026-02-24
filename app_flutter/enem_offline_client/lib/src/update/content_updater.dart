import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../data/local_database.dart';
import 'content_manifest.dart';
import 'update_result.dart';

class ContentUpdater {
  ContentUpdater({
    required this.localDatabase,
    required this.manifestUri,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final LocalDatabase localDatabase;
  final Uri manifestUri;
  final http.Client _client;

  Future<UpdateResult> checkAndUpdate() async {
    final db = await localDatabase.open();
    final currentVersion = await localDatabase.getContentVersion(db);

    final manifest = await _fetchManifest();
    if (manifest.version.isEmpty || manifest.archiveFile.isEmpty) {
      return UpdateResult(
        updated: false,
        currentVersion: currentVersion,
        message: 'Manifest inválido (version/archive_file ausentes).',
      );
    }

    if (manifest.version == currentVersion) {
      return UpdateResult(
        updated: false,
        currentVersion: currentVersion,
        message: 'Conteúdo já atualizado (${manifest.version}).',
      );
    }

    final zipBytes = await _downloadAsset(manifest);
    _validateAssetDigest(zipBytes, manifest);

    final bundle = _extractBundleFromZip(zipBytes, manifest.bundleFile);
    await localDatabase.upsertBundle(db, bundle);
    await localDatabase.setContentVersion(db, manifest.version);

    return UpdateResult(
      updated: true,
      currentVersion: manifest.version,
      message:
          'Update aplicado (${manifest.version}) | questões: ${manifest.questionCount} | módulos: ${manifest.bookModuleCount}.',
    );
  }

  Future<ContentManifest> _fetchManifest() async {
    final response = await _client.get(manifestUri);
    if (response.statusCode != 200) {
      throw Exception('Falha ao baixar manifest: HTTP ${response.statusCode}');
    }

    final payload = jsonDecode(utf8.decode(response.bodyBytes));
    if (payload is! Map<String, dynamic>) {
      throw Exception('Manifest JSON inválido (objeto esperado).');
    }
    return ContentManifest.fromJson(payload);
  }

  Future<Uint8List> _downloadAsset(ContentManifest manifest) async {
    final uri = _resolveAssetUri(manifest);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Falha ao baixar asset zip: HTTP ${response.statusCode}');
    }

    final bytes = response.bodyBytes;
    if (manifest.size > 0 && bytes.length != manifest.size) {
      throw Exception(
        'Tamanho inesperado do zip. Esperado ${manifest.size}, recebido ${bytes.length}.',
      );
    }
    return bytes;
  }

  Uri _resolveAssetUri(ContentManifest manifest) {
    final downloadUrl = manifest.downloadUrl;
    if (downloadUrl != null && downloadUrl.isNotEmpty) {
      return Uri.parse(downloadUrl);
    }
    return manifestUri.resolve(manifest.archiveFile);
  }

  void _validateAssetDigest(Uint8List bytes, ContentManifest manifest) {
    final expected = manifest.sha256.trim().toLowerCase();
    if (expected.isEmpty) {
      throw Exception('Manifest sem SHA256.');
    }

    final computed = sha256.convert(bytes).toString().toLowerCase();
    if (computed != expected) {
      throw Exception('SHA256 inválido para o asset zip.');
    }
  }

  Map<String, dynamic> _extractBundleFromZip(Uint8List zipBytes, String expectedFile) {
    final archive = ZipDecoder().decodeBytes(zipBytes, verify: true);

    ArchiveFile? bundleFile;
    for (final file in archive.files) {
      if (!file.isFile) {
        continue;
      }
      if (file.name == expectedFile) {
        bundleFile = file;
        break;
      }
    }

    if (bundleFile == null) {
      throw Exception('Arquivo $expectedFile não encontrado no zip.');
    }

    final content = bundleFile.content;
    if (content is! List<int>) {
      throw Exception('Conteúdo do bundle inválido no zip.');
    }

    final parsed = jsonDecode(utf8.decode(content));
    if (parsed is! Map<String, dynamic>) {
      throw Exception('Bundle inválido. JSON de objeto esperado.');
    }

    return parsed;
  }
}
