import 'package:shared_preferences/shared_preferences.dart'; // Исправлена опечатка
import 'dart:convert';
import '../models/note.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;
  final String _notesKey = 'notes';
  final String _intervalsKey = 'intervals';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Notes operations
  Future<List<Note>> getNotes() async {
    await init();
    final notesJson = _prefs?.getString(_notesKey);
    if (notesJson == null) return [];
    
    final List<dynamic> notesList = json.decode(notesJson);
    return notesList.map((noteMap) => Note.fromMap(noteMap)).toList();
  }

  Future<void> saveNotes(List<Note> notes) async {
    await init();
    final notesJson = json.encode(notes.map((note) => note.toMap()).toList());
    await _prefs?.setString(_notesKey, notesJson);
  }

  // Intervals operations
  Future<List<int>> getIntervals() async {
    await init();
    final intervalsJson = _prefs?.getString(_intervalsKey);
    if (intervalsJson == null) return [20, 1440, 2880,10080]; // minutes
    
    final List<dynamic> intervalsList = json.decode(intervalsJson);
    return intervalsList.cast<int>();
  }

  Future<void> saveIntervals(List<int> intervals) async {
    await init();
    final intervalsJson = json.encode(intervals);
    await _prefs?.setString(_intervalsKey, intervalsJson);
  }
}