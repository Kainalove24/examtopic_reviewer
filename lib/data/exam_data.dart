import 'package:flutter/services.dart' show rootBundle;
import '../utils/csv_question_parser.dart';
import '../models/exam_question.dart';

class ExamData {
  static Future<List<ExamQuestion>> loadFromCsv(String filename) async {
    final csvString = await rootBundle.loadString('csv/$filename');
    final questions = parseQuestionsFromCsv(csvString);
    // Convert each Question to ExamQuestion
    return questions
        .map(
          (q) => ExamQuestion(
            id: q.id,
            type: q.type,
            text: q.text,
            questionImages: q.questionImages,
            answerImages: q.answerImages,
            options: q.choices.map((c) => c.text).toList(),
            answers: q.type == 'hotspot'
                ? (() {
                    print('Debug ExamData: Hotspot question detected');
                    print(
                      'Debug ExamData: correctIndices: ${q.correctIndices}',
                    );
                    print(
                      'Debug ExamData: choices: ${q.choices.map((c) => c.text).toList()}',
                    );
                    final result = q.correctIndices
                        .map((i) => q.choices[i].text)
                        .toList();
                    print('Debug ExamData: Final answers for hotspot: $result');
                    return result;
                  })()
                : q.correctIndices.map((i) => i.toString()).toList(),
            explanation: null,
          ),
        )
        .toList();
  }
}
