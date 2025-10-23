import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/note.dart';
import 'dart:math';

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
  // пути, которые пользователь удалил в редакторе — удаляем файлы при сохранении
  final List<String> _deletedImagePaths = [];

  late Note _backupNoteData;

  bool get _hasChanges {
    if (widget.note == null) {
      return _titleController.text.isNotEmpty ||
          _contentController.text.isNotEmpty ||
          _imagePaths.isNotEmpty;
    }
    return _titleController.text != widget.note!.title ||
        _contentController.text != widget.note!.content ||
        !_listEquals(_imagePaths, widget.note!.imagePaths);
  }

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _imagePaths = List.from(widget.note!.imagePaths);
    }
    _backupNoteData = _makeBackup();
    _titleController.addListener(_backupNote);
    _contentController.addListener(_backupNote);
  }

  Note _makeBackup() {
    return Note(
      id: widget.note?.id,
      title: _titleController.text,
      content: _contentController.text,
      imagePaths: List.from(_imagePaths),
      createdAt: widget.note?.createdAt ?? DateTime.now(),
      nextReview: widget.note?.nextReview ?? DateTime.now(),
      intervalIndex: widget.note?.intervalIndex ?? 0,
      isLearned: widget.note?.isLearned ?? false,
    );
  }

  void _backupNote() {
    _backupNoteData = _makeBackup();
  }

  Future<void> _deleteMarkedFiles() async {
    for (final p in List<String>.from(_deletedImagePaths)) {
      try {
        final File f = File(p);
        if (await f.exists()) await f.delete();
      } catch (e) {
        // ignore
      }
    }
    _deletedImagePaths.clear();
  }

  Future<void> _saveNote({bool showSnack = true}) async {
    String title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty) {
      final lines = content
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);
      title = lines.isNotEmpty ? lines.first : 'Без названия';
    }

    // фильтруем пути — сохраняем только существующие файлы
    final List<String> existingImagePaths = [];
    for (final imgPath in _imagePaths) {
      try {
        final File f = File(imgPath);
        if (await f.exists()) {
          existingImagePaths.add(imgPath);
        }
      } catch (e) {
        // ignore
      }
    }
    _imagePaths = existingImagePaths;

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

    // удаляем реальные файлы, которые пользователь пометил на удаление
    await _deleteMarkedFiles();

    widget.onSave(note);
    _backupNoteData = _makeBackup();

    if (showSnack) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сохранено')),
      );
    }
  }

  Future<bool> _onWillPop() async {
    if (_hasChanges) {
      await _saveNote(showSnack: true);
    }
    return true;
  }

    Future<void> _addImage() async {
    try {
      final List<XFile>? images = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (images != null && images.isNotEmpty) {
        final List<String> savedImagePaths = [];
        for (var i = 0; i < images.length; i++) {
          final image = images[i];
          final uniqueName =
              'image_${DateTime.now().microsecondsSinceEpoch}_${i}_${Random().nextInt(1 << 32)}${path.extension(image.path)}';
          final String? savedImagePath = await _saveImageToAppDirectory(image.path, uniqueName);
          if (savedImagePath != null) {
            savedImagePaths.add(savedImagePath);
          } else {
            _showErrorSnackbar('Не удалось сохранить одно из изображений.');
          }
          // небольшая пауза гарантирует разные microseconds при экстремально быстрой обработке
          await Future.delayed(const Duration(milliseconds: 1));
        }
        setState(() {
          _imagePaths.addAll(savedImagePaths);
        });
        _backupNote();
      }
    } catch (e) {
      _showErrorSnackbar('Ошибка при выборе изображений: $e');
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
        final String? savedImagePath = await _saveImageToAppDirectory(image.path);
        if (savedImagePath != null) {
          setState(() {
            _imagePaths.add(savedImagePath);
          });
          _backupNote();
        } else {
          _showErrorSnackbar('Не удалось сохранить фото.');
        }
      }
    } catch (e) {
      _showErrorSnackbar('Ошибка при съемке фото: $e');
    }
  }

  // Теперь возвращаем null в случае ошибки — это гарантирует, что
  // путь в temp не попадёт в список изображений.
  Future<String?> _saveImageToAppDirectory(String originalPath, [String? fileName]) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String extension = path.extension(originalPath);
      final String safeFileName = fileName ??
          'image_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 32)}$extension';
      String newPath = path.join(appDir.path, safeFileName);

      final File originalFile = File(originalPath);
      if (!await originalFile.exists()) {
        return null;
      }

      // Если файл с таким именем вдруг существует — добавляем суффикс-счётчик
      var counter = 0;
      while (await File(newPath).exists()) {
        counter++;
        final String nameWithoutExt = path.basenameWithoutExtension(safeFileName);
        final String candidate = '${nameWithoutExt}_$counter$extension';
        newPath = path.join(appDir.path, candidate);
        // предохранитель на случай бесконечной петли
        if (counter > 1000) break;
      }

      await originalFile.copy(newPath);
      return newPath;
    } catch (e) {
      return null;
    }
  }

  // Удаление только помечаем; реальное удаление при сохранении
  void _removeImageAt(int index) {
    setState(() {
      final String imagePath = _imagePaths.removeAt(index);
      // помечаем путь на удаление, если файл находится в app documents (а не в temp)
      _deletedImagePaths.add(imagePath);
    });
    _backupNote();
  }

  Future<void> _deleteImageFile(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      if (await imageFile.exists()) await imageFile.delete();
    } catch (e) {
      // ignore
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _openImageFullScreen(int index) async {
    final result = await Navigator.push<List<String>?>(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewerScreen(
          initialIndex: index,
          imagePaths: List.from(_imagePaths),
          deleteFiles: false, // viewer не удаляет файлы физически когда открыт из редактора
        ),
      ),
    );

    if (result != null) {
      // определим, какие пути были удалены в viewer, и пометим их на удаление
      final removed = _imagePaths.where((p) => !result.contains(p)).toList();
      setState(() {
        _imagePaths = result;
        _deletedImagePaths.addAll(removed);
      });
      _backupNote();
    }
  }

  Widget _buildImageThumbnail(String imagePath, int index) {
    return GestureDetector(
      onTap: () => _openImageFullScreen(index),
      child: Container(
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
    );
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _titleController.removeListener(_backupNote);
    _contentController.removeListener(_backupNote);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.note == null ? 'Новый конспект' : 'Редактирование'),
          actions: [], // значок "сохранить" удалён
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
                const Text('Прикрепленные изображения:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imagePaths.length,
                    itemBuilder: (context, index) => _buildImageThumbnail(_imagePaths[index], index),
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
      ),
    );
  }
}

class ImageViewerScreen extends StatefulWidget {
  final int initialIndex;
  final List<String> imagePaths;
  // флаг: если true — viewer сам удаляет файлы с диска; если false — только возвращает список без удалённых элементов
  final bool deleteFiles;

  const ImageViewerScreen({
    super.key,
    required this.initialIndex,
    required this.imagePaths,
    this.deleteFiles = true,
  });

  @override
  _ImageViewerScreenState createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late PageController _pageController;
  late List<String> _paths;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _paths = List.from(widget.imagePaths);
    _currentIndex = widget.initialIndex.clamp(0, _paths.isEmpty ? 0 : _paths.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  Future<void> _deleteCurrentImage() async {
    if (_paths.isEmpty) return;

    final int indexToDelete = _currentIndex;
    final String pathToDelete = _paths[indexToDelete];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить изображение?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    if (widget.deleteFiles) {
      try {
        final File file = File(pathToDelete);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // ignore
      }
    }
    setState(() {
      _paths.removeAt(indexToDelete);
      if (_paths.isEmpty) {
        Navigator.pop(context, _paths);
        return;
      }
      if (_currentIndex >= _paths.length) {
        _currentIndex = _paths.length - 1;
      }
      _pageController = PageController(initialPage: _currentIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context, _paths),
        ),
        actions: [
          if (_paths.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteCurrentImage,
            ),
        ],
      ),
      body: _paths.isEmpty
          ? const Center(child: Text('Нет изображений', style: TextStyle(color: Colors.white)))
          : PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // отключаем свайп; навигация только стрелками
              itemCount: _paths.length,
              onPageChanged: (idx) => setState(() => _currentIndex = idx),
              itemBuilder: (context, index) {
                final imgPath = _paths[index];
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return Center(
                      child: InteractiveViewer(
                        panEnabled: true,
                        scaleEnabled: true,
                        boundaryMargin: const EdgeInsets.all(40),
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Container(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                            color: Colors.black,
                          ),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            child: Image.file(
                              File(imgPath),
                              errorBuilder: (context, error, stackTrace) => const SizedBox(
                                child: Center(child: Icon(Icons.broken_image, color: Colors.white, size: 48)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      bottomNavigationBar: _paths.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${_currentIndex + 1} / ${_paths.length}', style: const TextStyle(color: Colors.white)),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (_currentIndex > 0) {
                              _pageController.previousPage(duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
                            }
                          },
                          icon: const Icon(Icons.chevron_left, color: Colors.white),
                        ),
                        IconButton(
                          onPressed: () {
                            if (_currentIndex < _paths.length - 1) {
                              _pageController.nextPage(duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
                            }
                          },
                          icon: const Icon(Icons.chevron_right, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
