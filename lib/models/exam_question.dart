class ExamQuestion {
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'text': text,
      'question_images': questionImages,
      'answer_images': answerImages,
      'options': options,
      'answers': answers,
      'explanation': explanation,
      'ai_explanation': aiExplanation,
    };
  }

  final int id;
  final String type;
  final String text;
  final List<String> questionImages;
  final List<String> answerImages;
  final List<String> options;
  final List<String> answers;
  final String? explanation;
  final String? aiExplanation;

  ExamQuestion({
    required this.id,
    required this.type,
    required this.text,
    required this.questionImages,
    required this.answerImages,
    required this.options,
    required this.answers,
    this.explanation,
    this.aiExplanation,
  });

  factory ExamQuestion.fromCsv(Map<String, String> row) {
    return ExamQuestion(
      id: int.tryParse(row['id'] ?? '') ?? 0,
      type: row['type'] ?? '',
      text: row['text'] ?? '',
      questionImages: _splitAndClean(row['question_images'], sep: '|'),
      answerImages: _splitAndClean(row['answer_images'], sep: '|'),
      options: _splitAndClean(row['options'], sep: '|'),
      answers: _splitAndClean(row['answers'], sep: '|'),
      explanation: (row['explanation'] ?? '').isEmpty
          ? null
          : row['explanation'],
      aiExplanation: (row['ai_explanation'] ?? '').isEmpty
          ? null
          : row['ai_explanation'],
    );
  }

  factory ExamQuestion.fromMap(Map<String, dynamic> map) {
    return ExamQuestion(
      id: map['id'] ?? 0,
      type: map['type'] ?? '',
      text: map['text'] ?? '',
      questionImages: List<String>.from(map['question_images'] ?? []),
      answerImages: List<String>.from(map['answer_images'] ?? []),
      options: List<String>.from(map['options'] ?? []),
      answers: List<String>.from(map['answers'] ?? []),
      explanation: map['explanation'],
      aiExplanation: map['ai_explanation'],
    );
  }

  // Create a copy of this question with updated AI explanation
  ExamQuestion copyWith({
    int? id,
    String? type,
    String? text,
    List<String>? questionImages,
    List<String>? answerImages,
    List<String>? options,
    List<String>? answers,
    String? explanation,
    String? aiExplanation,
  }) {
    return ExamQuestion(
      id: id ?? this.id,
      type: type ?? this.type,
      text: text ?? this.text,
      questionImages: questionImages ?? this.questionImages,
      answerImages: answerImages ?? this.answerImages,
      options: options ?? this.options,
      answers: answers ?? this.answers,
      explanation: explanation ?? this.explanation,
      aiExplanation: aiExplanation ?? this.aiExplanation,
    );
  }

  static List<String> _splitAndClean(String? value, {String sep = ','}) {
    if (value == null || value.trim().isEmpty) return [];
    return value
        .split(sep)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}
