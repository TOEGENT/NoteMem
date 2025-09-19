import '../models/note.dart';

class SchedulerService {
  static final List<int> defaultIntervals = [480, 2880, 8640]; // minutes

  static DateTime calculateNextReview(Note note, List<int> intervals) {
    final currentInterval = intervals[note.intervalIndex];
    return DateTime.now().add(Duration(minutes: currentInterval));
  }

  static void updateNoteAfterReview(Note note, bool remembered, List<int> intervals) {
    if (remembered) {
      // Move to next interval
      note.intervalIndex = (note.intervalIndex + 1).clamp(0, intervals.length - 1);
    } else {
      // Reset to first interval
      note.intervalIndex = 0;
    }
    
    note.nextReview = calculateNextReview(note, intervals);
    note.isLearned = !remembered;
  }

  static List<Note> getNotesDueForReview(List<Note> notes) {
    final now = DateTime.now();
    return notes.where((note) => note.nextReview.isBefore(now)).toList();
  }
}