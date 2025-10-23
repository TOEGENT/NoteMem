import '../models/note.dart';

class SchedulerService {
  static const List<int> defaultIntervals = [20, 1440, 2880, 10080]; // minutes (20 min, 1 day, 2 days, 7 days)

  static void updateNoteAfterReview(Note note, bool remembered, List<int> intervals) {
    // Validate intervals list
    if (intervals.isEmpty) {
      // If no intervals defined, treat as "new" and skip scheduling
      note.intervalIndex = -1;
      note.nextReview = DateTime.now();
      note.isLearned = false;
      return;
    }

    if (!remembered) {
      // If forgotten, reset to the first interval
      note.intervalIndex = 0;
    } else {
      // If remembered, advance to the next interval—but do not wrap around
      if (note.intervalIndex < intervals.length - 1) {
        note.intervalIndex += 1;
      }
      // Otherwise, stay at the last interval (no change)
    }

    // Set next review time based on current intervalIndex
    final minutes = intervals[note.intervalIndex];
    note.nextReview = DateTime.now().add(Duration(minutes: minutes));

    // Mark as learned if at least the first interval has been reached (index >= 0)
    // Since we reset to 0 on failure and start at 0 on success, index >= 0 always holds here
    // But to be explicit: consider "learned" once the user has successfully reviewed once
    note.isLearned = true;
  }

  static void postponeReview(Note note, int minutes) {
    if (minutes < 0) {
      throw ArgumentError('Postponement duration must be non-negative.');
    }
    note.nextReview = DateTime.now().add(Duration(minutes: minutes));
  }

  static String getIntervalName(int index, List<int> intervals) {
    if (index < 0 || index >= intervals.length) {
      return 'Новый';
    }

    final minutes = intervals[index];
    if (minutes < 60) {
      return '$minutes мин';
    } else if (minutes < 1440) {
      return '${minutes ~/ 60} ч';
    } else {
      return '${minutes ~/ 1440} д';
    }
  }
}