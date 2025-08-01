class ImportedExam {
  final String id;
  final String title;
  final String filename;
  final DateTime importedAt;

  ImportedExam({
    required this.id,
    required this.title,
    required this.filename,
    required this.importedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'filename': filename,
    'importedAt': importedAt.toIso8601String(),
  };

  factory ImportedExam.fromMap(Map<String, dynamic> map) => ImportedExam(
    id: map['id'] as String,
    title: map['title'] as String,
    filename: map['filename'] as String,
    importedAt: DateTime.parse(map['importedAt'] as String),
  );
}
