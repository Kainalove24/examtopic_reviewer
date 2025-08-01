class Question {
  final String id;
  final String text;
  final List<String> choices;
  final int correctAnswer;
  bool isMastered;
  bool isViewed;

  Question({
    required this.id,
    required this.text,
    required this.choices,
    required this.correctAnswer,
    this.isMastered = false,
    this.isViewed = false,
  });

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'] as String,
      text: map['text'] as String,
      choices: List<String>.from(map['choices'] as List),
      correctAnswer: map['correctAnswer'] as int,
      isMastered: map['isMastered'] ?? false,
      isViewed: map['isViewed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'choices': choices,
      'correctAnswer': correctAnswer,
      'isMastered': isMastered,
      'isViewed': isViewed,
    };
  }
}
