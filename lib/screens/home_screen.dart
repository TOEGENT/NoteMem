import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/note.dart';
import '../services/storage_service.dart';
import '../services/scheduler_service.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import 'editor_screen.dart';
import '../widgets/note_card.dart';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storage = StorageService();
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  String _searchQuery = '';
  String _filter = 'all';
  bool _isImporting = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _startPeriodicCheck();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _applyFilters();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startPeriodicCheck() {
    Future.delayed(const Duration(minutes: 1), () {
      _checkForExpiredReviews();
      _startPeriodicCheck();
    });
  }

  Future<void> _checkForExpiredReviews() async {
    final notes = await _storage.getNotes();
    final now = DateTime.now();
    bool needsUpdate = false;

    for (var note in notes) {
      if (note.isLearned && note.nextReview.isBefore(now)) {
        print('Конспект ${note.id} просрочен для повторения');
        needsUpdate = true;
      }
    }

    if (needsUpdate) _loadNotes();
  }

  Future<void> _loadNotes() async {
    await _storage.init();
    final notes = await _storage.getNotes();
    _updateOverdueNotes(notes);
    setState(() {
      _notes = notes;
      _applyFilters();
    });
  }

  void _updateOverdueNotes(List<Note> notes) {
    final now = DateTime.now();
    bool changed = false;

    for (var note in notes) {
      if (!note.isLearned && note.nextReview.isBefore(now)) {
        print('Заметка ${note.id} готова к изучению');
        changed = true;
      }
    }

    if (changed) _storage.saveNotes(notes);
  }

  void _applyFilters() {
    List<Note> filtered = _notes;
    final now = DateTime.now();

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((note) =>
          note.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          note.content.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    if (_filter == 'toLearn') {
      filtered = filtered.where((note) => !note.isLearned).toList();
    } else if (_filter == 'learned') {
      filtered = filtered.where((note) => note.isLearned).toList();
    } else if (_filter == 'toRepeat') {
      filtered = filtered.where((note) =>
          note.isLearned && note.nextReview.isBefore(now)
      ).toList();
    } else if (_filter == 'waiting') {
      filtered = filtered.where((note) =>
          note.isLearned && note.nextReview.isAfter(now)
      ).toList();
    }

    setState(() {
      _filteredNotes = filtered;
    });
  }

  void _addNewNote() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorScreen(
          onSave: (Note newNote) async {
            final notes = await _storage.getNotes();
            newNote.id = notes.isEmpty ? 1 : (notes.last.id ?? 0) + 1;
            newNote.isLearned = false;
            newNote.intervalIndex = -1;
            newNote.nextReview = DateTime.now();
            notes.add(newNote);
            await _storage.saveNotes(notes);
            _loadNotes();
          },
        ),
      ),
    );
  }

  void _editNote(Note note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorScreen(
          note: note,
          onSave: (Note updatedNote) async {
            final notes = await _storage.getNotes();
            final index = notes.indexWhere((n) => n.id == updatedNote.id);
            if (index != -1) {
              notes[index] = updatedNote;
              await _storage.saveNotes(notes);
              setState(() {
                _notes = notes;
                _applyFilters();
              });
            }
          },
        ),
      ),
    );
  }

  Future<void> _reviewNote(Note note, bool remembered) async {
    final intervals = await _storage.getIntervals();
    final oldIsLearned = note.isLearned;

    SchedulerService.updateNoteAfterReview(note, remembered, intervals);

    final notes = await _storage.getNotes();
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      notes[index] = note;
      await _storage.saveNotes(notes);
      _showReviewNotification(note, remembered, oldIsLearned);
      _applyFilters();
    }
  }

  Future<void> _postponeNote(Note note, int minutes) async {
    SchedulerService.postponeReview(note, minutes);

    final notes = await _storage.getNotes();
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      notes[index] = note;
      await _storage.saveNotes(notes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏰ Отложено на $minutes минут'),
          duration: const Duration(seconds: 2),
        ),
      );
      _applyFilters();
    }
  }

  void _showReviewNotification(Note note, bool remembered, bool oldIsLearned) {
    final intervalName = SchedulerService.getIntervalName(
        note.intervalIndex, SchedulerService.defaultIntervals);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          remembered
              ? '✅ Повторить ${intervalName.toLowerCase()}'
              : '🔄 Начинаем заново. ${intervalName.toLowerCase()}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _deleteNote(Note note) async {
    final notes = await _storage.getNotes();
    notes.removeWhere((n) => n.id == note.id);
    await _storage.saveNotes(notes);
    _applyFilters();
  }

  // === ИМПОРТ/ЭКСПОРТ ФУНКЦИОНАЛ ===

    // Импорт конспектов
  Future<void> _importNotes() async {
    setState(() => _isImporting = true);

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'zip', 'txt'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null) return;

      final PlatformFile picked = result.files.single;

      List<int>? bytes = picked.bytes;
      if (bytes == null && picked.path != null) {
        bytes = await File(picked.path!).readAsBytes();
      }
      if (bytes == null) throw Exception('Не удалось прочитать файл');

      final name = (picked.name ?? '').toLowerCase();

      if (name.endsWith('.zip')) {
        // Попытка стандартного импорта
        try {
          final importResult = await ImportService.importFromZip(bytes);
          if ((importResult.notes.isNotEmpty ?? false)) {
            await _showImportOptions(importResult);
            return;
          }
        } catch (_) {
          // продолжим с ручной распаковкой
        }

        // Ручная распаковка архива и поиск заметок/медиа
        final archive = ZipDecoder().decodeBytes(bytes);
        // Создаём временную папку для медиа
        final appDoc = await getApplicationDocumentsDirectory();
        final tmpDir = Directory(p.join(appDoc.path, 'import_tmp_${DateTime.now().millisecondsSinceEpoch}'));
        await tmpDir.create(recursive: true);

        // Сохраняем все файлы из media/ в tmpDir и собираем JSON-entries в notes/
        final List<ArchiveFile> jsonEntries = [];
        for (final entry in archive) {
          if (!entry.isFile) continue;
          final entryName = entry.name.replaceAll('\\', '/');
          final lower = entryName.toLowerCase();

          if (lower.startsWith('media/') || lower.startsWith('images/') || lower.contains('/media/')) {
            final outPath = p.join(tmpDir.path, p.basename(entryName));
            final outFile = File(outPath);
            await outFile.writeAsBytes(entry.content as List<int>);
          } else if (lower == 'notes.json' || lower.endsWith('/notes.json') || lower.startsWith('notes/') || lower.startsWith('data/notes') || lower.endsWith('.json')) {
            // собираем возможные json-файлы — позже попытаемся распарсить
            jsonEntries.add(entry);
          }
        }

        // Попытки распарсить JSON из найденных jsonEntries; при нахождении хотя бы одной заметки — используем их
        List<Note> parsedNotes = [];
        for (final entry in jsonEntries) {
          try {
            final content = utf8.decode(entry.content as List<int>);
            final dynamic decoded = json.decode(content);

            // Если это массив объектов — парсим как массив заметок
            if (decoded is List) {
              for (final item in decoded) {
                try {
                  parsedNotes.add(Note.fromJson(Map<String, dynamic>.from(item as Map)));
                } catch (e) {
                  // игнорируем некорректные элементы
                }
              }
            } else if (decoded is Map) {
              // варианты: { "notes": [...] } или один объект заметки либо { "data": [...] }
              if (decoded.containsKey('notes') && decoded['notes'] is List) {
                for (final item in decoded['notes']) {
                  try {
                    parsedNotes.add(Note.fromJson(Map<String, dynamic>.from(item as Map)));
                  } catch (_) {}
                }
              } else if (decoded.containsKey('data') && decoded['data'] is List) {
                for (final item in decoded['data']) {
                  try {
                    parsedNotes.add(Note.fromJson(Map<String, dynamic>.from(item as Map)));
                  } catch (_) {}
                }
              } else {
                // Попытка распарсить одиночную заметку
                try {
                  parsedNotes.add(Note.fromJson(Map<String, dynamic>.from(decoded)));
                } catch (_) {}
              }
            }
          } catch (_) {
            // пропускаем файл, если не JSON
          }
          if (parsedNotes.isNotEmpty) break;
        }

        // Если не нашли заметки через jsonEntries, попробуем искать JSON внутри папки notes/ по отдельным файлам
        if (parsedNotes.isEmpty) {
          for (final entry in archive) {
            if (!entry.isFile) continue;
            final entryName = entry.name.replaceAll('\\', '/');
            final lower = entryName.toLowerCase();
            if (lower.startsWith('notes/') && lower.endsWith('.json')) {
              try {
                final content = utf8.decode(entry.content as List<int>);
                final dynamic decoded = json.decode(content);
                if (decoded is Map) {
                  try {
                    parsedNotes.add(Note.fromJson(Map<String, dynamic>.from(decoded)));
                  } catch (_) {}
                } else if (decoded is List) {
                  for (final item in decoded) {
                    try {
                      parsedNotes.add(Note.fromJson(Map<String, dynamic>.from(item as Map)));
                    } catch (_) {}
                  }
                }
              } catch (_) {}
            }
          }
        }

        if (parsedNotes.isEmpty) {
          throw Exception('В архиве не найдено заметок в ожидаемом формате (notes или notes.json).');
        }

        // Подмена путей изображений: если в note.imagePaths встречается имя файла, заменяем на путь в tmpDir
        for (var note in parsedNotes) {
          final List<String> newPaths = [];
          for (final pathItem in note.imagePaths ?? <String>[]) {
            final base = p.basename(pathItem);
            final candidate = p.join(tmpDir.path, base);
            if (await File(candidate).exists()) {
              newPaths.add(candidate);
            } else {
              newPaths.add(pathItem);
            }
          }
          note.imagePaths = newPaths;
        }

        // Сохраняем распарсенные заметки
        await _processImportedNotes(parsedNotes);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Импортировано ${parsedNotes.length} конспектов')));
        return;
      } else {
        // Не zip — ожидаем JSON/TXT
        final jsonText = utf8.decode(bytes);
        final importResult = await ImportService.importFromFullJson(jsonText);
        if ((importResult.notes.isNotEmpty ?? false)) {
          await _showImportOptions(importResult);
          return;
        }

        // fallback: попытаемся распарсить вручную
        final dynamic decoded = json.decode(jsonText);
        final List<Note> parsedNotes = [];
        if (decoded is List) {
          for (final item in decoded) {
            try {
              parsedNotes.add(Note.fromJson(Map<String, dynamic>.from(item as Map)));
            } catch (_) {}
          }
        } else if (decoded is Map && decoded.containsKey('notes') && decoded['notes'] is List) {
          for (final item in decoded['notes']) {
            try {
              parsedNotes.add(Note.fromJson(Map<String, dynamic>.from(item as Map)));
            } catch (_) {}
          }
        }

        if (parsedNotes.isEmpty) throw Exception('JSON не содержит заметок в ожидаемом формате.');
        await _processImportedNotes(parsedNotes);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Импортировано ${parsedNotes.length} конспектов')));
        return;
      }
    } catch (e, st) {
      print('Импорт: ошибка $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка импорта: $e')));
    } finally {
      setState(() => _isImporting = false);
    }
  }


  Future<void> _showImportOptions(ImportResult importResult) async {
    bool preserveSettings = true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Импорт конспектов'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Найдено конспектов: ${importResult.notes.length}'),
              if (importResult.hasMedia) 
                Text('Медиафайлов: ${importResult.notes.expand((n) => n.imagePaths).length}'),
              const SizedBox(height: 10),
              CheckboxListTile(
                title: const Text('Сохранить настройки повторений'),
                subtitle: const Text('Интервалы, даты повторений'),
                value: preserveSettings,
                onChanged: (value) {
                  setDialogState(() {
                    preserveSettings = value ?? true;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _processImportedNotes(importResult.notes);
              },
              child: const Text('Импортировать'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processImportedNotes(List<Note> importedNotes) async {
    final existingNotes = await _storage.getNotes();
    final maxId = existingNotes.isEmpty ? 0 : (existingNotes.last.id ?? 0);
    
    for (var i = 0; i < importedNotes.length; i++) {
      importedNotes[i].id = maxId + i + 1;
    }
    
    existingNotes.addAll(importedNotes);
    await _storage.saveNotes(existingNotes);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Импортировано ${importedNotes.length} конспектов')),
    );
    
    _loadNotes();
  }

  // Экспорт конспектов
  Future<void> _exportNotes() async {
    setState(() {
      _isImporting = true;
    });

    try {
      final selectedNotes = await _showNoteSelectionDialog();
      if (selectedNotes.isEmpty) return;

      final exportPath = await ExportService.createExportPackage(selectedNotes);
      
      await Share.shareXFiles(
        [XFile(exportPath, mimeType: 'application/zip')],
        text: 'Экспорт конспектов из Spaced Repetition Notes',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка экспорта: $e')),
      );
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  Future<List<Note>> _showNoteSelectionDialog() async {
    final selectedNotes = <Note>[];
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Экспорт конспектов'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              children: [
                const Text('Выберите конспекты для экспорта:'),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: _notes.length,
                    itemBuilder: (context, index) {
                      final note = _notes[index];
                      final isSelected = selectedNotes.contains(note);
                      
                      return CheckboxListTile(
                        title: Text(note.title.isEmpty ? 'Без названия' : note.title),
                        subtitle: Text('Изображений: ${note.imagePaths.length}'),
                        value: isSelected,
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              selectedNotes.add(note);
                            } else {
                              selectedNotes.remove(note);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(selectedNotes),
              child: const Text('Экспортировать'),
            ),
          ],
        ),
      ),
    );

    return selectedNotes;
  }

  // Быстрый экспорт в JSON
  Future<void> _quickExport() async {
    try {
      final jsonData = ExportService.generateShareableData(_notes);
      final jsonText = json.encode(jsonData);
      await Share.share(jsonText);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка экспорта: $e')),
      );
    }
  }

  // Меню импорта/экспорта
  void _showImportExportMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Импорт/Экспорт',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('Импорт конспектов'),
              subtitle: const Text('ZIP, JSON с медиафайлами'),
              onTap: () {
                Navigator.of(context).pop();
                _importNotes();
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_upload),
              title: const Text('Экспорт конспектов'),
              subtitle: const Text('ZIP архив с настройками'),
              onTap: () {
                Navigator.of(context).pop();
                _exportNotes();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Быстрый экспорт'),
              subtitle: const Text('Текущие конспекты в JSON'),
              onTap: () {
                Navigator.of(context).pop();
                _quickExport();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getFilterLabel(String filter) {
    switch (filter) {
      case 'toLearn':
        return 'Только учить';
      case 'toRepeat':
        return 'Только повторить';
      case 'waiting':
        return 'Ждут повторения';
      case 'learned':
        return 'Только выученные';
      default:
        return 'Все';
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final toRepeatCount =
        _notes.where((n) => n.isLearned && n.nextReview.isBefore(now)).length;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Поиск...',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_isImporting)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            )
          else
            IconButton(
              icon: const Icon(Icons.import_export),
              onPressed: _showImportExportMenu,
              tooltip: 'Импорт/Экспорт',
            ),
          if (toRepeatCount > 0 && _filter != 'toRepeat')
            Badge(
              label: Text(toRepeatCount.toString()),
              child: IconButton(
                icon: const Icon(Icons.notification_important),
                onPressed: () {
                  setState(() {
                    _filter = 'toRepeat';
                    _applyFilters();
                  });
                },
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _filter = value;
                _applyFilters();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('Все')),
              const PopupMenuItem(value: 'toLearn', child: Text('Учить')),
              const PopupMenuItem(value: 'toRepeat', child: Text('Повторить')),
              const PopupMenuItem(value: 'waiting', child: Text('Ждут повторения')),
              const PopupMenuItem(value: 'learned', child: Text('Выученные')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotes,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searchQuery.isNotEmpty || _filter != 'all')
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[100],
              child: Row(
                children: [
                  if (_searchQuery.isNotEmpty)
                    Chip(
                      label: Text('Поиск: "$_searchQuery"'),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() {
                          _searchController.clear();
                          _applyFilters();
                        });
                      },
                    ),
                  if (_filter != 'all')
                    Chip(
                      label: Text(_getFilterLabel(_filter)),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() {
                          _filter = 'all';
                          _applyFilters();
                        });
                      },
                    ),
                ],
              ),
            ),
          Expanded(
            child: _filteredNotes.isEmpty
                ? const Center(child: Text('Нет конспектов для отображения'))
                : ListView.builder(
                    itemCount: _filteredNotes.length,
                    itemBuilder: (context, index) {
                      final note = _filteredNotes[index];
                      return NoteCard(
                        key: ValueKey(note.id),
                        note: note,
                        onTap: () => _editNote(note),
                        onReview: (remembered) => _reviewNote(note, remembered),
                        onDelete: () => _deleteNote(note),
                        onPostpone: (minutes) => _postponeNote(note, minutes),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewNote,
        child: const Icon(Icons.add),
      ),
    );
  }
}