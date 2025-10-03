
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
    _initStorage();
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

  Future<void> _initStorage() async {
    await _storage.init();
    final notes = await _storage.getNotes();
    _updateOverdueNotes(notes);
    setState(() {
      _notes = notes;
      _applyFilters();
    });
  }

  void _startPeriodicCheck() {
    Future.delayed(const Duration(minutes: 1), () {
      _checkForExpiredReviews();
      _startPeriodicCheck();
    });
  }

  Future<void> _checkForExpiredReviews() async {
    final now = DateTime.now();
    bool needsUpdate = false;

    for (var note in _notes) {
      if (note.isLearned && note.nextReview.isBefore(now)) {
        print('Конспект ${note.id} просрочен для повторения');
        needsUpdate = true;
      }
    }

    if (needsUpdate) setState(() => _applyFilters());
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

    _filteredNotes = filtered;
  }

  void _addNewNote() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorScreen(
          onSave: (Note newNote) async {
            newNote.id = (_notes.isEmpty ? 1 : (_notes.last.id ?? 0) + 1);
            newNote.isLearned = false;
            newNote.intervalIndex = -1;
            newNote.nextReview = DateTime.now();
            setState(() {
              _notes.add(newNote);
              _applyFilters();
            });
            await _storage.saveNotes(_notes);
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
            final index = _notes.indexWhere((n) => n.id == updatedNote.id);
            if (index != -1) {
              setState(() {
                _notes[index] = updatedNote;
                _applyFilters();
              });
              await _storage.saveNotes(_notes);
            }
          },
        ),
      ),
    );
  }

  Future<void> _reviewNote(Note note, bool remembered) async {
    SchedulerService.updateNoteAfterReview(note, remembered, await _storage.getIntervals());
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      setState(() {
        _notes[index] = note;
        _applyFilters();
      });
      await _storage.saveNotes(_notes);
      _showReviewNotification(note, remembered);
    }
  }

  Future<void> _postponeNote(Note note, int minutes) async {
    SchedulerService.postponeReview(note, minutes);
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      setState(() {
        _notes[index] = note;
        _applyFilters();
      });
      await _storage.saveNotes(_notes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏰ Отложено на $minutes минут'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showReviewNotification(Note note, bool remembered) {
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

  Future<void> _deleteNote(Note note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить конспект?'),
        content: Text('Вы уверены, что хотите удалить "${note.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _notes.removeWhere((n) => n.id == note.id);
      _applyFilters();
    });
    await _storage.saveNotes(_notes);
  }

  // === Импорт/Экспорт ===
  Future<void> _importNotes() async {
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'zip', 'txt'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null) return;
      final picked = result.files.single;
      List<int>? bytes = picked.bytes ?? await File(picked.path!).readAsBytes();
      if (bytes == null) throw Exception('Не удалось прочитать файл');

      final name = (picked.name ?? '').toLowerCase();
      List<Note> parsedNotes = [];

      if (name.endsWith('.zip')) {
        final archive = ZipDecoder().decodeBytes(bytes);
        final appDoc = await getApplicationDocumentsDirectory();
        final tmpDir = Directory(p.join(appDoc.path, 'import_tmp_${DateTime.now().millisecondsSinceEpoch}'));
        await tmpDir.create(recursive: true);
        final List<ArchiveFile> jsonEntries = [];

        for (final entry in archive) {
          if (!entry.isFile) continue;
          final lower = entry.name.replaceAll('\\', '/').toLowerCase();
          if (lower.endsWith('.json')) jsonEntries.add(entry);
          else if (lower.startsWith('media/')) {
            final outFile = File(p.join(tmpDir.path, p.basename(entry.name)));
            await outFile.writeAsBytes(entry.content as List<int>);
          }
        }

        for (final entry in jsonEntries) {
          final content = utf8.decode(entry.content as List<int>);
          final decoded = json.decode(content);
          if (decoded is List) parsedNotes.addAll(decoded.map((e) => Note.fromJson(Map<String, dynamic>.from(e))));
          else if (decoded is Map) parsedNotes.add(Note.fromJson(Map<String, dynamic>.from(decoded)));
        }

        for (var note in parsedNotes) {
          final List<String> newPaths = [];
          for (final pathItem in note.imagePaths ?? <String>[]) {
            final candidate = p.join(tmpDir.path, p.basename(pathItem));
            if (await File(candidate).exists()) newPaths.add(candidate);
            else newPaths.add(pathItem);
          }
          note.imagePaths = newPaths;
        }
      } else {
        final decoded = json.decode(utf8.decode(bytes));
        if (decoded is List) parsedNotes.addAll(decoded.map((e) => Note.fromJson(Map<String, dynamic>.from(e))));
        else if (decoded is Map) parsedNotes.add(Note.fromJson(Map<String, dynamic>.from(decoded)));
      }

      if (parsedNotes.isEmpty) throw Exception('Не найдено заметок для импорта');
      final maxId = _notes.isEmpty ? 0 : (_notes.last.id ?? 0);
      for (var i = 0; i < parsedNotes.length; i++) parsedNotes[i].id = maxId + i + 1;

      setState(() {
        _notes.addAll(parsedNotes);
        _applyFilters();
      });
      await _storage.saveNotes(_notes);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Импортировано ${parsedNotes.length} конспектов')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка импорта: $e')));
    } finally {
      setState(() => _isImporting = false);
    }
  }

  Future<void> _exportNotes() async {
    setState(() => _isImporting = true);
    try {
      final selectedNotes = await _showNoteSelectionDialog();
      if (selectedNotes.isEmpty) return;
      final exportPath = await ExportService.createExportPackage(selectedNotes);
      await Share.shareXFiles([XFile(exportPath, mimeType: 'application/zip')], text: 'Экспорт конспектов');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка экспорта: $e')));
    } finally {
      setState(() => _isImporting = false);
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
            height: 300,
            child: ListView.builder(
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                final note = _notes[index];
                final isSelected = selectedNotes.contains(note);
                return CheckboxListTile(
                  title: Text(note.title.isEmpty ? 'Без названия' : note.title),
                  value: isSelected,
                  onChanged: (value) {
                    setDialogState(() {
                      if (value == true) selectedNotes.add(note);
                      else selectedNotes.remove(note);
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            ElevatedButton(onPressed: () => Navigator.pop(context, selectedNotes), child: const Text('Экспортировать')),
          ],
        ),
      ),
    );
    return selectedNotes;
  }

  Future<void> _quickExport() async {
    try {
      final jsonData = ExportService.generateShareableData(_notes);
      await Share.share(json.encode(jsonData));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка экспорта: $e')));
    }
  }

  void _showImportExportMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Импорт/Экспорт', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('Импорт конспектов'),
              onTap: () {
                Navigator.pop(context);
                _importNotes();
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_upload),
              title: const Text('Экспорт конспектов'),
              onTap: () {
                Navigator.pop(context);
                _exportNotes();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Быстрый экспорт'),
              onTap: () {
                Navigator.pop(context);
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
      case 'toLearn': return 'Только учить';
      case 'toRepeat': return 'Только повторить';
      case 'waiting': return 'Ждут повторения';
      case 'learned': return 'Только выученные';
      default: return 'Все';
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final toRepeatCount = _notes.where((n) => n.isLearned && n.nextReview.isBefore(now)).length;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(hintText: 'Поиск...', border: InputBorder.none),
        ),
        actions: [
          if (_isImporting)
            const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())
          else
            IconButton(icon: const Icon(Icons.import_export), onPressed: _showImportExportMenu, tooltip: 'Импорт/Экспорт'),
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
