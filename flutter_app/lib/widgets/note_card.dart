import 'package:flutter/material.dart';
import '../models/note.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final Function(bool) onReview;
  final VoidCallback onDelete;

  const NoteCard({
    Key? key,
    required this.note,
    required this.onTap,
    required this.onReview,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(note.title.isEmpty ? 'Без названия' : note.title),
        subtitle: Text(
          note.content.length > 100
              ? '${note.content.substring(0, 100)}...'
              : note.content,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (note.isLearned)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => onReview(false),
                tooltip: 'Повторить',
              )
            else
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: () => onReview(true),
                tooltip: 'Выучено',
              ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: onDelete,
              tooltip: 'Удалить',
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}