import '../models/note.dart';

class SchedulerService {
  static const List<int> defaultIntervals = [20, 1440, 2880,10080]; // минуты (8ч, 48ч, 144ч)

  static void updateNoteAfterReview(Note note, bool remembered, List<int> intervals) {
    if (!remembered) {
      // Если забыли - начинаем заново
      note.intervalIndex = 0;
    } else {
      // Если помним - переходим к следующему интервалу
      note.intervalIndex = (note.intervalIndex + 1) % intervals.length;
    }
    
    // Устанавливаем следующее повторение
    final minutes = intervals[note.intervalIndex];
    note.nextReview = DateTime.now().add(Duration(minutes: minutes));
    
    // Помечаем как изученную только если прошли хотя бы один интервал
    note.isLearned = note.intervalIndex >= 0;
  }

  static void postponeReview(Note note, int minutes) {
    note.nextReview = DateTime.now().add(Duration(minutes: minutes));
  }

  static String getIntervalName(int index, List<int> intervals) {
    if (index < 0 || index >= intervals.length) return 'Новый';
    
    final minutes = intervals[index];
    if (minutes < 60) return '$minutes мин';
    if (minutes < 1440) return '${minutes ~/ 60} ч';
    return '${minutes ~/ 1440} д';
  }
}