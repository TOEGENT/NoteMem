import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/scheduler_service.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final Function(bool) onReview;
  final VoidCallback onDelete;
  final Function(int) onPostpone; // Новая callback функция

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onReview,
    required this.onDelete,
    required this.onPostpone, // Добавляем параметр
  });

  @override
  Widget build(BuildContext context) {
    final intervalName = SchedulerService.getIntervalName(note.intervalIndex,SchedulerService.defaultIntervals);
    final isDueForReview = note.nextReview.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: note.isLearned 
          ? (isDueForReview ? Colors.orange[100] : Colors.yellow[100])
          : Colors.green[100],
      child: ListTile(
        title: Text(note.title.isEmpty ? 'Без названия' : note.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note.content.length > 100
                  ? '${note.content.substring(0, 100)}...'
                  : note.content,
            ),
            const SizedBox(height: 4),
            Text(
              'Следующее: ${_formatDateTime(note.nextReview)}',
              style: TextStyle(
                fontSize: 12,
                color: isDueForReview ? Colors.red : Colors.grey,
                fontWeight: isDueForReview ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            Text(
              'Интервал: $intervalName',
              style: const TextStyle(fontSize: 12, color: Colors.blue),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (note.isLearned && isDueForReview)
              PopupMenuButton<int>(
                icon: const Icon(Icons.more_time, color: Colors.blue),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 10, child: Text('Отложить на 10 мин')),
                  const PopupMenuItem(value: 30, child: Text('Отложить на 30 мин')),
                  const PopupMenuItem(value: 60, child: Text('Отложить на 1 час')),
                ],
                onSelected: (minutes) => onPostpone(minutes),
              ),
            if (note.isLearned)
              IconButton(
                icon: Icon(
                  isDueForReview ? Icons.warning : Icons.access_time,
                  color: isDueForReview ? Colors.orange : Colors.blue,
                ),
                onPressed: () => onReview(true),
                tooltip: isDueForReview ? 'Пора повторять!' : 'Выучено',
              )
            else
              IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                onPressed: () => onReview(false),
                tooltip: 'Повторить позже',
              ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
              tooltip: 'Удалить',
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

String _formatDateTime(DateTime dateTime) {
  final now = DateTime.now();
  final isToday = dateTime.year == now.year &&
                  dateTime.month == now.month &&
                  dateTime.day == now.day;

  final datePart = isToday
      ? 'Сегодня'
      : '${dateTime.day.toString().padLeft(2, '0')}.'
        '${dateTime.month.toString().padLeft(2, '0')}.'
        '${dateTime.year}';

  final timePart =
      '${dateTime.hour.toString().padLeft(2, '0')}:'
      '${dateTime.minute.toString().padLeft(2, '0')}';

  return '$datePart $timePart';
}
}