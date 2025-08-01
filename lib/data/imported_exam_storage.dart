import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/imported_exam.dart';

class ImportedExamStorage {
  static const _key = 'imported_exams';

  static Future<List<ImportedExam>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final List data = jsonDecode(raw);
    return data.map((e) => ImportedExam.fromMap(e)).toList();
  }

  static Future<void> saveAll(List<ImportedExam> exams) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(exams.map((e) => e.toMap()).toList());
    await prefs.setString(_key, data);
  }

  static Future<void> addExam(ImportedExam exam) async {
    final exams = await loadAll();
    exams.add(exam);
    await saveAll(exams);
  }

  static Future<void> removeExam(String id) async {
    final exams = await loadAll();
    exams.removeWhere((e) => e.id == id);
    await saveAll(exams);
  }
}
