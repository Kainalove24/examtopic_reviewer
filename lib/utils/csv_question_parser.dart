import 'package:csv/csv.dart';

class Choice {
  final String text;
  final bool isCorrect;
  Choice({required this.text, required this.isCorrect});
}

class Question {
  final int id;
  final String type;
  final String text;
  final List<String> questionImages;
  final List<String> answerImages;
  final List<Choice> choices;
  final List<int> correctIndices;

  Question({
    required this.id,
    required this.type,
    required this.text,
    required this.questionImages,
    required this.answerImages,
    required this.choices,
    required this.correctIndices,
  });
}

List<Question> parseQuestionsFromCsv(String csvContent) {
  final rows = const CsvToListConverter(
    eol: '\n',
    shouldParseNumbers: false,
  ).convert(csvContent);
  if (rows.isEmpty || rows.length < 2) return [];
  final headers = rows.first.map((e) => e.toString()).toList();
  final idIdx = headers.indexOf('id');
  final typeIdx = headers.indexOf('type');
  final textIdx = headers.indexOf('text');
  final imageUrlIdx = headers.indexOf('question_images');
  final answerImagesIdx = headers.indexOf('answer_images');
  final optionsIdx = headers.indexOf('options');
  final correctIdx = headers.indexOf('answers');

  List<Question> questions = [];
  for (int i = 1; i < rows.length; i++) {
    final row = rows[i];
    int id = int.tryParse(row[idIdx]?.toString() ?? '') ?? 0;
    String type = row[typeIdx]?.toString() ?? '';
    String text = row[textIdx]?.toString() ?? '';
    String imageUrlStr = imageUrlIdx >= 0
        ? row[imageUrlIdx]?.toString() ?? ''
        : '';
    String answerImagesStr = answerImagesIdx >= 0
        ? row[answerImagesIdx]?.toString() ?? ''
        : '';
    String optionsStr = optionsIdx >= 0
        ? row[optionsIdx]?.toString() ?? ''
        : '';
    String correctStr = correctIdx >= 0
        ? row[correctIdx]?.toString() ?? ''
        : '';

    List<String> questionImages = imageUrlStr.isNotEmpty
        ? imageUrlStr.split('|').map((e) => e.trim()).toList()
        : [];
    List<String> answerImages = answerImagesStr.isNotEmpty
        ? answerImagesStr.split('|').map((e) => e.trim()).toList()
        : [];
    List<String> options = [];
    if (optionsStr.isNotEmpty) {
      // Remove surrounding quotes if present
      String cleaned = optionsStr;
      if ((cleaned.startsWith('"') && cleaned.endsWith('"')) ||
          (cleaned.startsWith("'") && cleaned.endsWith("'"))) {
        cleaned = cleaned.substring(1, cleaned.length - 1);
      }
      options = cleaned
          .split('|')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    List<Choice> choices = [];
    List<int> correctIndices = [];

    if (_parseType(type) == 'mcq') {
      // MCQ: correct answers can be A,B or A|B
      final correctLetters = correctStr
          .split(RegExp(r'[|,]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      for (int j = 0; j < options.length; j++) {
        final opt = options[j];
        final match = RegExp(r'^(\w)[.、．．:：\)]').firstMatch(opt);
        final letter = match?.group(1);
        final isCorrect = letter != null && correctLetters.contains(letter);
        choices.add(Choice(text: opt, isCorrect: isCorrect));
        if (isCorrect) correctIndices.add(j);
      }
    } else if (_parseType(type) == 'hotspot') {
      // Hotspot: correct is option text separated by pipes

      for (int j = 0; j < options.length; j++) {
        choices.add(Choice(text: options[j], isCorrect: false));
      }
      if (correctStr.isNotEmpty) {
        // For hotspot, the correct answer is the option text in order
        final correctOrder = correctStr
            .split('|')
            .map((e) => e.trim())
            .toList();
        print('Debug CSV Parser: correctOrder after split: $correctOrder');

        for (var correctText in correctOrder) {
          final idx = options.indexWhere((opt) => opt.trim() == correctText);
          print(
            'Debug CSV Parser: Looking for "$correctText", found at index $idx',
          );
          if (idx >= 0) {
            correctIndices.add(idx);
          }
        }
        print('Debug CSV Parser: Final correctIndices: $correctIndices');
      }
    } else {
      // Non-MCQ: correct is indices (e.g., 0,2,3)
      for (int j = 0; j < options.length; j++) {
        choices.add(Choice(text: options[j], isCorrect: false));
      }
      if (correctStr.isNotEmpty) {
        correctIndices = correctStr
            .split(',')
            .map((e) => int.tryParse(e.trim()) ?? -1)
            .where((i) => i >= 0)
            .toList();
      }
    }

    questions.add(
      Question(
        id: id,
        type: type,
        text: text,
        questionImages: questionImages,
        answerImages: answerImages,
        choices: choices,
        correctIndices: correctIndices,
      ),
    );
  }
  return questions;
}

String _parseType(String type) {
  final t = type.toLowerCase();
  if (t.contains('mcq') || t == 'choice') return 'mcq';
  if (t == 'hotspot') return 'hotspot';
  return t;
}
