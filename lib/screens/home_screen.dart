import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/storage_service.dart';
import '../services/scheduler_service.dart';
import 'editor_screen.dart';
import '../widgets/note_card.dart';

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
              _applyFilters();
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
