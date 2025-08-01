class StudySet {
  final String id;
  final String title;
  final List<String> questionIds;
  int masteredCount;
  int studyAttempts;
  int quizAttempts;
  int mistakesBeforeMastery;
  bool isLocked;
  bool isMastered;
  bool isQuizPassed;

  StudySet({
    required this.id,
    required this.title,
    required this.questionIds,
    this.masteredCount = 0,
    this.studyAttempts = 0,
    this.quizAttempts = 0,
    this.mistakesBeforeMastery = 0,
    this.isLocked = false,
    this.isMastered = false,
    this.isQuizPassed = false,
  });

  factory StudySet.fromMap(Map<String, dynamic> map) {
    return StudySet(
      id: map['id'] as String,
      title: map['title'] as String,
      questionIds: List<String>.from(map['questionIds'] as List),
      masteredCount: map['masteredCount'] ?? 0,
      studyAttempts: map['studyAttempts'] ?? 0,
      quizAttempts: map['quizAttempts'] ?? 0,
      mistakesBeforeMastery: map['mistakesBeforeMastery'] ?? 0,
      isLocked: map['isLocked'] ?? false,
      isMastered: map['isMastered'] ?? false,
      isQuizPassed: map['isQuizPassed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'questionIds': questionIds,
      'masteredCount': masteredCount,
      'studyAttempts': studyAttempts,
      'quizAttempts': quizAttempts,
      'mistakesBeforeMastery': mistakesBeforeMastery,
      'isLocked': isLocked,
      'isMastered': isMastered,
      'isQuizPassed': isQuizPassed,
    };
  }
}
