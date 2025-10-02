class Note {
  int? id;
  String title;
  String content;
  DateTime createdAt;
  DateTime nextReview;
  int intervalIndex;
  List<String> imagePaths;
  bool isLearned;

  Note({
    this.id,
    this.title = '',
    this.content = '',
    DateTime? createdAt,
    DateTime? nextReview,
    this.imagePaths = const [],
    this.isLearned = false,
    this.intervalIndex = 0,
  }) : createdAt = createdAt ?? DateTime.now(),
       nextReview = nextReview ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'nextReview': nextReview.millisecondsSinceEpoch,
      'intervalIndex': intervalIndex,
      'imagePaths': imagePaths.join('|'),
      'isLearned': isLearned ? 1 : 0,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      nextReview: DateTime.fromMillisecondsSinceEpoch(map['nextReview']),
      intervalIndex: map['intervalIndex'] ?? 0,
      imagePaths: (map['imagePaths'] as String).split('|').where((path) => path.isNotEmpty).toList(),
      isLearned: map['isLearned'] == 1,
    );
  }
  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      createdAt: _parseDate(json['createdAt']),
      nextReview: _parseDate(json['nextReview']),
      intervalIndex: json['intervalIndex'] is int ? json['intervalIndex'] : int.tryParse(json['intervalIndex']?.toString() ?? '0') ?? 0,
      imagePaths: (json['imagePaths'] is List)
          ? List<String>.from(json['imagePaths'])
          : (json['imagePaths']?.toString().split('|') ?? <String>[]),
      isLearned: json['isLearned'] == true || json['isLearned'] == 1,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is int) {
      // либо миллисекунды, либо секунды
      return value > 2000000000
          ? DateTime.fromMillisecondsSinceEpoch(value)
          : DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

}