import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'services/user_exam_service.dart';
import 'services/expiry_cleanup_service.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Clean up expired exams on app startup
  await UserExamService.cleanupExpiredExams();

  // Start periodic cleanup
  ExpiryCleanupService.startPeriodicCleanup();

  runApp(const MyApp());
}
