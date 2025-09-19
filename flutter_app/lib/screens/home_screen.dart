import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/storage_service.dart';
import '../services/scheduler_service.dart';
import 'editor_screen.dart'; // Импорт оставляем, он используется
import '../widgets/note_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key}); // Используем super параметр

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storage = StorageService();
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  String _searchQuery = '';
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    await _storage.init();
    final notes = await _storage.getNotes();
    setState(() {
      _notes = notes;
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<Note> filtered = _notes;
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((note) =>
        note.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        note.content.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    // Apply category filter
    if (_filter == 'toLearn') {
      filtered = filtered.where((note) => note.isLearned).toList();
    }
    
    setState(() {
      _filteredNotes = filtered;
    });
  }

  void _addNewNote() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorScreen( // Правильное использование EditorScreen
          onSave: (Note newNote) async {
            final notes = await _storage.getNotes();
            newNote.id = notes.isEmpty ? 1 : (notes.last.id ?? 0) + 1;
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
        builder: (context) => EditorScreen( // Правильное использование EditorScreen
          note: note,
          onSave: (Note updatedNote) async {
            final notes = await _storage.getNotes();
            final index = notes.indexWhere((n) => n.id == updatedNote.id);
            if (index != -1) {
              notes[index] = updatedNote;
              await _storage.saveNotes(notes);
              _loadNotes();
            }
          },
        ),
      ),
    );
  }

  void _reviewNote(Note note, bool remembered) async {
    final intervals = await _storage.getIntervals();
    SchedulerService.updateNoteAfterReview(note, remembered, intervals);
    
    final notes = await _storage.getNotes();
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      notes[index] = note;
      await _storage.saveNotes(notes);
      _loadNotes();
    }
  }

  void _deleteNote(Note note) async {
    final notes = await _storage.getNotes();
    notes.removeWhere((n) => n.id == note.id);
    await _storage.saveNotes(notes);
    _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: const InputDecoration(
            hintText: 'Поиск...',
            border: InputBorder.none,
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
              _applyFilters();
            });
          },
        ),
        actions: [
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
            ],
          ),
        ],
      ),
      body: _filteredNotes.isEmpty
          ? const Center(child: Text('Нет конспектов'))
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
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewNote,
        child: const Icon(Icons.add),
      ),
    );
  }
}