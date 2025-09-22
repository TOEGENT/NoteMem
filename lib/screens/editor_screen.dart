import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:photo_view/photo_view.dart';
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
  final ImagePicker _picker = ImagePicker();
  List<String> _imagePaths = [];

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _imagePaths = List.from(widget.note!.imagePaths);
    }
  }

  void _saveNote() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите заголовок')),
      );
      return;
    }

    final note = Note(
      id: widget.note?.id,
      title: title,
      content: content,
      imagePaths: _imagePaths,
      createdAt: widget.note?.createdAt ?? DateTime.now(),
      nextReview: widget.note?.nextReview ?? DateTime.now(),
      intervalIndex: widget.note?.intervalIndex ?? 0,
      isLearned: widget.note?.isLearned ?? false,
    );
    
    widget.onSave(note);
    Navigator.pop(context);
  }

  Future<void> _addImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        final String savedImagePath = await _saveImageToAppDirectory(image.path);
        
        setState(() {
          _imagePaths.add(savedImagePath);
        });
      }
    } catch (e) {
      _showErrorSnackbar('Ошибка при выборе изображения: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        final String savedImagePath = await _saveImageToAppDirectory(image.path);
        
        setState(() {
          _imagePaths.add(savedImagePath);
        });
      }
    } catch (e) {
      _showErrorSnackbar('Ошибка при съемке фото: $e');
    }
  }

  Future<String> _saveImageToAppDirectory(String originalPath) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName = 'image_${DateTime.now().millisecondsSinceEpoch}${path.extension(originalPath)}';
      final String newPath = path.join(appDir.path, fileName);

      final File originalFile = File(originalPath);
      await originalFile.copy(newPath);

      return newPath;
    } catch (e) {
      // Если не удалось сохранить, используем оригинальный путь
      return originalPath;
    }
  }

  void _removeImage(int index) {
    setState(() {
      final String imagePath = _imagePaths.removeAt(index);
      // Удаляем файл с устройства
      _deleteImageFile(imagePath);
    });
  }

  Future<void> _deleteImageFile(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      if (await imageFile.exists()) {
        await imageFile.delete();
      }
    } catch (e) {
      print('Ошибка при удалении файла: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _openImageFullScreen(String imagePath, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewerScreen(
          imagePath: imagePath,
          imageIndex: index,
          imagePaths: _imagePaths,
          onDelete: () {
            _removeImage(index);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Widget _buildImageThumbnail(String imagePath, int index) {
    return GestureDetector(
      onTap: () => _openImageFullScreen(imagePath, index),
      child: Stack(
        children: [
          Container(
            width: 100,
            height: 100,
            margin: const EdgeInsets.only(right: 8.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(imagePath),
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.error, color: Colors.red),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeImage(index),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'Новый конспект' : 'Редактирование'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveNote,
            tooltip: 'Сохранить',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Заголовок конспекта',
                border: OutlineInputBorder(),
                labelText: 'Заголовок',
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  hintText: 'Содержание конспекта...',
                  border: OutlineInputBorder(),
                  labelText: 'Содержание',
                  alignLabelWithHint: true,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
            if (_imagePaths.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Прикрепленные изображения:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imagePaths.length,
                  itemBuilder: (context, index) {
                    return _buildImageThumbnail(_imagePaths[index], index);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _takePhoto,
            heroTag: 'camera_fab',
            mini: true,
            tooltip: 'Сделать фото',
            child: const Icon(Icons.camera_alt),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _addImage,
            heroTag: 'gallery_fab',
            tooltip: 'Добавить из галереи',
            child: const Icon(Icons.photo_library),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}

class ImageViewerScreen extends StatefulWidget {
  final String imagePath;
  final int imageIndex;
  final List<String> imagePaths;
  final VoidCallback onDelete;

  const ImageViewerScreen({
    super.key,
    required this.imagePath,
    required this.imageIndex,
    required this.imagePaths,
    required this.onDelete,
  });

  @override
  _ImageViewerScreenState createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.imageIndex;
    _pageController = PageController(initialPage: widget.imageIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Удалить изображение?'),
                  content: const Text('Это действие нельзя отменить.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onDelete();
                      },
                      child: const Text('Удалить', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imagePaths.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return PhotoView(
                imageProvider: FileImage(File(widget.imagePaths[index])),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3.0,
                initialScale: PhotoViewComputedScale.contained,
                heroAttributes: PhotoViewHeroAttributes(tag: widget.imagePaths[index]),
                loadingBuilder: (context, event) => Center(
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: const CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              );
            },
          ),
          
          if (widget.imagePaths.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.imagePaths.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}