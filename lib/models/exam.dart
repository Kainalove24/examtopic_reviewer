import 'study_set.dart';

class Exam {
  final String id;
  final String title;
  final List<StudySet> sets;
  int currentSetIndex;

  Exam({
    required this.id,
    required this.title,
    required this.sets,
    this.currentSetIndex = 0,
  });

  factory Exam.fromMap(Map<String, dynamic> map) {
    return Exam(
      id: map['id'] as String,
      title: map['title'] as String,
      sets: (map['sets'] as List)
          .map((e) => StudySet.fromMap(e as Map<String, dynamic>))
          .toList(),
      currentSetIndex: map['currentSetIndex'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'sets': sets.map((e) => e.toMap()).toList(),
      'currentSetIndex': currentSetIndex,
    };
  }
}
