import 'package:flutter/material.dart';
import '../models/note.dart';

class EditorScreen extends StatefulWidget {
  final Note? note;
  final Function(Note) onSave;

  const EditorScreen({
    super.key,
    this.note,
    required this.onSave,
  });

  @override
  _EditorScreenState createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  List<String> _imagePaths = [];

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _imagePaths = widget.note!.imagePaths;
    }
  }

  void _saveNote() {
    final note = Note(
      id: widget.note?.id,
      title: _titleController.text,
      content: _contentController.text,
      imagePaths: _imagePaths,
      createdAt: widget.note?.createdAt,
      nextReview: widget.note?.nextReview,
      intervalIndex: widget.note?.intervalIndex ?? 0,
      isLearned: widget.note?.isLearned ?? false,
    );
    
    widget.onSave(note);
    Navigator.pop(context);
  }

  void _addImage() {
    setState(() {
      _imagePaths.add('assets/placeholder.jpg');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'Новый конспект' : 'Редактирование'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveNote),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Заголовок',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  hintText: 'Содержание',
                  border: OutlineInputBorder(),
                ),
                maxLines: null,
                expands: true,
              ),
            ),
            if (_imagePaths.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Изображения:'),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imagePaths.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Image.asset(
                        _imagePaths[index],
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addImage,
        child: const Icon(Icons.add_photo_alternate),
      ),
    );
  }
}