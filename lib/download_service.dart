import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';

class DownloadService {
  static const String MODEL_URL =
      'https://alphacephei.com/vosk/models/vosk-model-small-ru-0.22.zip';

  static const String MODEL_FOLDER = 'vosk-model-small-ru-0.22';

  // Папка Documents/ZefirkaVoice/
  static Future<Directory> getAppFolder() async {
    final docs = await getApplicationDocumentsDirectory();
    final folder = Directory('${docs.path}/ZefirkaVoice');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  // Путь к папке с моделью
  static Future<String> getModelPath() async {
    final folder = await getAppFolder();
    return '${folder.path}/$MODEL_FOLDER';
  }

  // Проверка — есть ли модель
  static Future<bool> isModelReady() async {
    final path = await getModelPath();
    return await Directory(path).exists();
  }

  // Скачивание + распаковка
  static Future<void> downloadModel({
    required Function(double progress) onProgress,
    required Function(String status) onStatus,
  }) async {
    final folder = await getAppFolder();
    final zipPath = '${folder.path}/model.zip';

    onStatus('Подключение...');

    // 1. Скачивание
    final request = http.Request('GET', Uri.parse(MODEL_URL));
    final response = await request.send();

    final totalBytes = response.contentLength ?? 0;
    int downloadedBytes = 0;

    final zipFile = File(zipPath);
    if (await zipFile.exists()) {
      await zipFile.delete();
    }
    final sink = zipFile.openWrite();

    await for (var chunk in response.stream) {
      sink.add(chunk);
      downloadedBytes += chunk.length;

      if (totalBytes > 0) {
        onProgress(downloadedBytes / totalBytes);
        onStatus(
            'Скачано: ${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)}');
      }
    }

    await sink.close();

    // 2. Распаковка
    onStatus('Распаковка...');
    onProgress(1.0);

    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive.files) {
      final filename = file.name;
      final outPath = '${folder.path}/$filename';

      if (file.isFile) {
        final data = file.content as List<int>;
        final outFile = File(outPath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(data);
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }

    // 3. Удаляем zip
    await zipFile.delete();

    onStatus('Готово!');
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} МБ';
  }
}
