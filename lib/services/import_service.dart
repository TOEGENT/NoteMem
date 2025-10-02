import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/note.dart';
import 'export_service.dart';
class ImportService {
  // Импорт из полного JSON с настройками повторений
  static Future<ImportResult> importFromFullJson(String jsonText, {bool preserveSettings = true}) async {
    try {
      final Map<String, dynamic> data = json.decode(jsonText);
      
      // Проверяем формат
      if (data['format'] != 'SpacedRepetitionNotes') {
        throw FormatException('Неверный формат файла');
      }

      final List<dynamic> notesData = data['data'] ?? [];
      final notes = <Note>[];
      final mediaFiles = <String, List<int>>{};

      // Обрабатываем медиафайлы если есть
      if (data['media'] != null && data['media'] is Map) {
        final mediaMap = Map<String, dynamic>.from(data['media']);
        for (final entry in mediaMap.entries) {
          if (entry.value is String) {
            // Base64 encoded файлы
            final fileData = base64.decode(entry.value as String);
            mediaFiles[entry.key] = fileData;
          }
        }
      }

      for (var noteData in notesData) {
        final noteMap = Map<String, dynamic>.from(noteData);
        
        final note = Note(
          id: noteMap['id'],
          title: noteMap['title'] ?? '',
          content: noteMap['content'] ?? '',
          createdAt: noteMap['createdAt'] != null 
              ? DateTime.fromMillisecondsSinceEpoch(noteMap['createdAt'])
              : DateTime.now(),
          nextReview: noteMap['nextReview'] != null
              ? DateTime.fromMillisecondsSinceEpoch(noteMap['nextReview'])
              : DateTime.now(),
          intervalIndex: preserveSettings ? (noteMap['intervalIndex'] ?? 0) : 0,
          isLearned: preserveSettings ? (noteMap['isLearned'] ?? true) : true,
        );

        // Восстанавливаем пути к медиафайлам
        if (noteMap['imagePaths'] != null) {
          final imagePaths = List<String>.from(noteMap['imagePaths']);
          final restoredPaths = <String>[];
          
          for (final imagePath in imagePaths) {
            final fileName = path.basename(imagePath);
            if (mediaFiles.containsKey(fileName)) {
              // Сохраняем файл локально
              final localPath = await _saveMediaFile(fileName, mediaFiles[fileName]!);
              restoredPaths.add(localPath);
            } else {
              // Оставляем оригинальный путь (может не работать)
              restoredPaths.add(imagePath);
            }
          }
          
          note.imagePaths = restoredPaths;
        }

        notes.add(note);
      }

      return ImportResult(
        notes: notes,
        source: 'json',
        hasMedia: mediaFiles.isNotEmpty,
      );
    } catch (e) {
      throw FormatException('Ошибка импорта JSON: $e');
    }
  }

  // Импорт из ZIP архива
  static Future<ImportResult> importFromZip(List<int> bytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      String? notesJson;
      final mediaFiles = <String, List<int>>{};

      // Извлекаем файлы из архива
      for (final file in archive) {
        final fileName = file.name;
        
        if (fileName == 'notes.json') {
          notesJson = utf8.decode(file.content);
        } else if (fileName.startsWith('media/')) {
          final mediaName = path.basename(fileName);
          mediaFiles[mediaName] = file.content;
        }
      }

      if (notesJson == null) {
        throw FormatException('Файл notes.json не найден в архиве');
      }

      // Парсим JSON и восстанавливаем медиафайлы
      final Map<String, dynamic> data = json.decode(notesJson);
      final List<dynamic> notesData = data['data'] ?? [];
      final notes = <Note>[];

      for (var noteData in notesData) {
        final noteMap = Map<String, dynamic>.from(noteData);
        
        final note = Note(
          id: noteMap['id'],
          title: noteMap['title'] ?? '',
          content: noteMap['content'] ?? '',
          createdAt: noteMap['createdAt'] != null 
              ? DateTime.fromMillisecondsSinceEpoch(noteMap['createdAt'])
              : DateTime.now(),
          nextReview: noteMap['nextReview'] != null
              ? DateTime.fromMillisecondsSinceEpoch(noteMap['nextReview'])
              : DateTime.now(),
          intervalIndex: noteMap['intervalIndex'] ?? 0,
          isLearned: noteMap['isLearned'] ?? true,
        );

        // Восстанавливаем медиафайлы
        if (noteMap['imagePaths'] != null) {
          final imagePaths = List<String>.from(noteMap['imagePaths']);
          final restoredPaths = <String>[];
          
          for (final imagePath in imagePaths) {
            final fileName = path.basename(imagePath);
            if (mediaFiles.containsKey(fileName)) {
              final localPath = await _saveMediaFile(fileName, mediaFiles[fileName]!);
              restoredPaths.add(localPath);
            }
          }
          
          note.imagePaths = restoredPaths;
        }

        notes.add(note);
      }

      return ImportResult(
        notes: notes,
        source: 'zip',
        hasMedia: mediaFiles.isNotEmpty,
      );
    } catch (e) {
      throw FormatException('Ошибка импорта ZIP: $e');
    }
  }

  // Сохранение медиафайла локально
  static Future<String> _saveMediaFile(String fileName, List<int> data) async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(path.join(appDir.path, 'imported_media'));
    
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }

    final filePath = path.join(mediaDir.path, '${DateTime.now().millisecondsSinceEpoch}_$fileName');
    final file = File(filePath);
    await file.writeAsBytes(data);
    
    return filePath;
  }

  // Генерация демонстрационных данных для тестирования
  static Future<Map<String, dynamic>> generateDemoExport() async {
    final demoNotes = [
      Note(
        title: 'Математика: Производные',
        content: 'Производная функции показывает скорость изменения.',
        intervalIndex: 2,
        isLearned: true,
        nextReview: DateTime.now().add(const Duration(hours: 1)),
      ),
      Note(
        title: 'Физика: Законы Ньютона',
        content: 'F = m*a - второй закон Ньютона.',
        intervalIndex: 1,
        isLearned: true,
        nextReview: DateTime.now().add(const Duration(minutes: 30)),
      ),
    ];

    return ExportService.generateShareableData(demoNotes);
  }
}

class ImportResult {
  final List<Note> notes;
  final String source;
  final bool hasMedia;

  ImportResult({
    required this.notes,
    required this.source,
    required this.hasMedia,
  });
}