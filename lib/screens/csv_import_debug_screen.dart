// ignore_for_file: use_build_context_synchronously, depend_on_referenced_packages, curly_braces_in_flow_control_structures, deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:csv/csv.dart';
// import '../models/exam_question.dart';
import '../utils/csv_question_parser.dart';
import '../models/imported_exam.dart';
import '../data/imported_exam_storage.dart';
import 'package:path/path.dart' as p;
import 'package:go_router/go_router.dart';
import 'dart:io';

class CsvImportDebugScreen extends StatefulWidget {
  const CsvImportDebugScreen({super.key});

  @override
  State<CsvImportDebugScreen> createState() => _CsvImportDebugScreenState();
}

class _CsvImportDebugScreenState extends State<CsvImportDebugScreen> {
  List<Question> questions = [];
  String? error;
  bool loading = false;
  String? examName;
  String? fileName;
  String? filePath;
  String? imageFolderPath;
  List<String> copiedImages = [];
  List<String> missingImages = [];

  Future<void> pickAndParseCsv() async {
    setState(() {
      error = null;
      questions = [];
      loading = true;
      examName = null;
      fileName = null;
      filePath = null;
      imageFolderPath = null;
      copiedImages.clear();
      missingImages.clear();
    });

    try {
      // Step 1: Pick CSV file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result == null || result.files.single.bytes == null) {
        setState(() {
          error = 'No CSV file selected.';
          loading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No CSV file selected.')),
          );
        }
        return;
      }

      final pickedFileName = result.files.single.name;
      final csvString = utf8.decode(result.files.single.bytes!);
      if (csvString.trim().isEmpty) {
        setState(() {
          error = 'CSV file is empty.';
          loading = false;
        });
        return;
      }

      // Step 2: Parse CSV to get image references
      final parsedQuestions = parseQuestionsFromCsv(csvString);
      questions = parsedQuestions;
      if (questions.isEmpty) {
        setState(() {
          error = 'No questions found in CSV.';
          loading = false;
        });
        return;
      }

      // Step 3: Collect all image references from questions
      Set<String> allImagePaths = {};
      for (final question in questions) {
        allImagePaths.addAll(question.questionImages);
        allImagePaths.addAll(question.answerImages);
      }

      // Step 4: If there are images, prompt for image folder
      if (allImagePaths.isNotEmpty) {
        final imageDirPath = await FilePicker.platform.getDirectoryPath(
          dialogTitle:
              'Select folder containing the images referenced in the CSV',
        );

        if (imageDirPath != null) {
          imageFolderPath = imageDirPath;

          // Step 5: Copy images to app's images directory
          await _copyImagesToAppDirectory(allImagePaths, imageDirPath);
        } else {
          setState(() {
            error =
                'Image folder selection cancelled. Images will not be available.';
            loading = false;
          });
          return;
        }
      }

      // Step 6: Prompt for exam name
      final existingExams = await ImportedExamStorage.loadAll();
      final name = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController(
            text: p.basenameWithoutExtension(pickedFileName),
          );
          return AlertDialog(
            title: const Text('Name Your Exam'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(labelText: 'Exam Name'),
                ),
                if (copiedImages.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${copiedImages.length} images will be imported',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
                if (missingImages.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${missingImages.length} images not found',
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ],
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, controller.text);
                },
                child: const Text('Import'),
              ),
            ],
          );
        },
      );

      if (name == null || name.trim().isEmpty) {
        setState(() {
          error = 'Import cancelled.';
          loading = false;
        });
        return;
      }

      if (existingExams.any(
        (e) => e.title.toLowerCase() == name.trim().toLowerCase(),
      )) {
        setState(() {
          error = 'An exam with this name already exists.';
          loading = false;
        });
        return;
      }

      if (existingExams.any((e) => e.filename == pickedFileName)) {
        setState(() {
          error = 'A file with this name has already been imported.';
          loading = false;
        });
        return;
      }

      // Step 7: Save CSV file to app storage
      String savePath;
      try {
        final appDir = await FilePicker.platform.getDirectoryPath();
        savePath = appDir != null
            ? p.join(appDir, pickedFileName)
            : p.join('.', 'csv', pickedFileName);
        final file = File(savePath);
        await file.writeAsBytes(result.files.single.bytes!);
      } catch (e) {
        setState(() {
          error = 'Failed to save CSV file: $e';
          loading = false;
        });
        return;
      }

      // Step 8: Save metadata
      final importedExam = ImportedExam(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: name.trim(),
        filename: pickedFileName,
        importedAt: DateTime.now(),
      );
      await ImportedExamStorage.addExam(importedExam);

      setState(() {
        examName = name.trim();
        fileName = pickedFileName;
        filePath = savePath;
        loading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported "$examName" with ${questions.length} questions${copiedImages.isNotEmpty ? ' and ${copiedImages.length} images' : ''}.',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        error = 'Failed to parse CSV: $e';
        loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to parse CSV: $e')));
      }
    }
  }

  Future<void> _copyImagesToAppDirectory(
    Set<String> imagePaths,
    String sourceDir,
  ) async {
    copiedImages.clear();
    missingImages.clear();

    // Get the app's images directory
    final appImagesDir = Directory('images');
    if (!await appImagesDir.exists()) {
      await appImagesDir.create(recursive: true);
    }

    for (final imagePath in imagePaths) {
      try {
        // Get just the filename from the path
        final fileName = p.basename(imagePath);
        final sourceFile = File(p.join(sourceDir, fileName));
        final destFile = File(p.join('images', fileName));

        if (await sourceFile.exists()) {
          // Copy the file
          await sourceFile.copy(destFile.path);
          copiedImages.add(fileName);
        } else {
          missingImages.add(fileName);
        }
      } catch (e) {
        print('Error copying image $imagePath: $e');
        missingImages.add(p.basename(imagePath));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Use GoRouter's pop for best practice
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          if (mounted) GoRouter.of(context).pop();
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CSV & Image Import'),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () => _showHelpDialog(),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Import button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: loading ? null : pickAndParseCsv,
                  icon: const Icon(Icons.upload_file),
                  label: Text(loading ? 'Importing...' : 'Import CSV & Images'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: loading ? Colors.grey : null,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

              if (loading) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Processing import...',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],

              if (error != null && !loading) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (examName != null && !loading) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import Summary',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Exam: $examName'),
                        if (fileName != null) Text('CSV File: $fileName'),
                        if (questions.isNotEmpty)
                          Text('Questions: ${questions.length}'),
                        if (copiedImages.isNotEmpty)
                          Text(
                            'Images Copied: ${copiedImages.length}',
                            style: const TextStyle(color: Colors.green),
                          ),
                        if (missingImages.isNotEmpty)
                          Text(
                            'Missing Images: ${missingImages.length}',
                            style: const TextStyle(color: Colors.orange),
                          ),
                        if (imageFolderPath != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Image Source: ${p.basename(imageFolderPath!)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Questions list
              Expanded(
                child: questions.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.upload_file,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No questions loaded.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Click "Import CSV & Images" to get started',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: questions.length,
                        itemBuilder: (context, i) {
                          final q = questions[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              title: Text('Q${q.id}: ${q.text}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Type: ${q.type}'),
                                  if (q.questionImages.isNotEmpty)
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.image,
                                          size: 16,
                                          color: Colors.blue,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Q Images: ${q.questionImages.join(", ")}',
                                            style: const TextStyle(
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (q.answerImages.isNotEmpty)
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.image,
                                          size: 16,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'A Images: ${q.answerImages.join(", ")}',
                                            style: const TextStyle(
                                              color: Colors.green,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (q.choices.isNotEmpty)
                                    Text(
                                      'Options: ${q.choices.map((c) => c.text).join(" | ")}',
                                    ),
                                  if (q.correctIndices.isNotEmpty)
                                    Text(
                                      'Correct: ${q.correctIndices.join(", ")}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Help'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How to import CSV with images:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. Prepare your CSV file with columns:'),
              Text(
                '   • id, type, text, question_images, answer_images, options, answers',
              ),
              SizedBox(height: 8),
              Text('2. Place all referenced images in a folder'),
              SizedBox(height: 8),
              Text('3. Click "Import CSV & Images"'),
              SizedBox(height: 8),
              Text('4. Select your CSV file'),
              SizedBox(height: 8),
              Text('5. Select the folder containing your images'),
              SizedBox(height: 8),
              Text('6. Enter an exam name'),
              SizedBox(height: 8),
              Text('7. The app will copy images to its images directory'),
              SizedBox(height: 16),
              Text(
                'Image format in CSV:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Single image: "image1.png"'),
              Text('• Multiple images: "image1.png|image2.png"'),
              Text('• Use just filenames, not full paths'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
