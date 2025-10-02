import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import '../models/note.dart';

class ExportService {
  static Future<String> exportNotes(List<Note> notes, {bool includeMedia = true}) async {
    final exportData = {
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'notes': notes.map((note) => note.toMap()).toList(),
    };

    if (includeMedia) {
      // Собираем все уникальные медиафайлы
      final allMediaPaths = <String>{};
      for (final note in notes) {
        allMediaPaths.addAll(note.imagePaths);
      }
      
      // Копируем медиафайлы во временную директорию
      final tempDir = await getTemporaryDirectory();
      final mediaDir = Directory(path.join(tempDir.path, 'media'));
      if (await mediaDir.exists()) {
        await mediaDir.delete(recursive: true);
      }
      await mediaDir.create(recursive: true);

      for (final mediaPath in allMediaPaths) {
        try {
          final sourceFile = File(mediaPath);
          if (await sourceFile.exists()) {
            final fileName = path.basename(mediaPath);
            await sourceFile.copy(path.join(mediaDir.path, fileName));
          }
        } catch (e) {
          print('Ошибка копирования файла $mediaPath: $e');
        }
      }

      // Добавляем информацию о медиафайлах
      exportData['media'] = {
        'count': allMediaPaths.length,
        'files': allMediaPaths.map(path.basename).toList(),
      };
    }

    return json.encode(exportData);
  }

  static Future<String> createExportPackage(List<Note> notes) async {
    final tempDir = await getTemporaryDirectory();
    final exportDir = Directory(path.join(tempDir.path, 'export_${DateTime.now().millisecondsSinceEpoch}'));
    await exportDir.create(recursive: true);

    // Создаем файл с данными
    final dataFile = File(path.join(exportDir.path, 'notes.json'));
    final jsonData = await exportNotes(notes, includeMedia: true);
    await dataFile.writeAsString(jsonData);

    // Копируем медиафайлы
    final mediaDir = Directory(path.join(exportDir.path, 'media'));
    await mediaDir.create();

    final allMediaPaths = <String>{};
    for (final note in notes) {
      allMediaPaths.addAll(note.imagePaths);
    }

    for (final mediaPath in allMediaPaths) {
      try {
        final sourceFile = File(mediaPath);
        if (await sourceFile.exists()) {
          final fileName = path.basename(mediaPath);
          await sourceFile.copy(path.join(mediaDir.path, fileName));
        }
      } catch (e) {
        print('Ошибка копирования медиафайла: $e');
      }
    }

    // Создаем ZIP архив
    final archive = Archive();
    
    // Добавляем файл данных
    final dataBytes = await dataFile.readAsBytes();
    archive.addFile(ArchiveFile('notes.json', dataBytes.length, dataBytes));

    // Добавляем медиафайлы
    final mediaFiles = await mediaDir.list().toList();
    for (final entity in mediaFiles) {
      if (entity is File) {
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile('media/${path.basename(entity.path)}', bytes.length, bytes));
      }
    }

    // Сохраняем ZIP
    final zipFile = File(path.join(tempDir.path, 'notes_export_${DateTime.now().millisecondsSinceEpoch}.zip'));
    final zipData = ZipEncoder().encode(archive);
    if (zipData != null) {
      await zipFile.writeAsBytes(zipData);
    }

    // Очищаем временные файлы
    await exportDir.delete(recursive: true);

    return zipFile.path;
  }

  static Map<String, dynamic> generateShareableData(List<Note> notes) {
    return {
      'format': 'SpacedRepetitionNotes',
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'notesCount': notes.length,
      'data': notes.map((note) => note.toMap()).toList(),
    };
  }
}