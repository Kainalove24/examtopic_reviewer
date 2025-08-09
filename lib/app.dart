// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/auth_provider.dart';
import 'providers/progress_provider.dart';
import 'providers/exam_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/library_screen.dart';
import 'screens/exam_info_screen.dart';

import 'screens/quiz_mode_screen.dart';

import 'screens/settings_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/mistake_review_screen.dart';
import 'screens/enhanced_csv_import_screen.dart';
import 'screens/comprehensive_import_screen.dart';
import 'screens/enhanced_scraper_integration_screen.dart';
import 'data/theme_storage.dart';
import 'package:go_router/go_router.dart';
import 'screens/random_quiz_screen.dart';
import 'screens/admin_portal_screen.dart';

import 'screens/voucher_entry_screen.dart';
import 'screens/exam_selection_screen.dart';

// This main function is duplicated in main.dart - removing it from here

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool darkMode = false;
  Color themeColor = const Color(0xFF7C83FD);

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final loadedDark = await ThemeStorage.loadDarkMode();
    final loadedColor = await ThemeStorage.loadThemeColor();
    setState(() {
      darkMode = loadedDark;
      themeColor = loadedColor;
    });
  }

  Future<void> _saveTheme(bool dark, Color color) async {
    await ThemeStorage.saveTheme(dark, color);
  }

  late final GoRouter _router = GoRouter(
    initialLocation: '/auth',
    redirect: (context, state) {
      // Handle exam not found scenarios by redirecting to library
      final location = state.uri.toString();
      if (location.startsWith('/exam/') ||
          location.startsWith('/quiz/') ||
          location.startsWith('/randomquiz/') ||
          location.startsWith('/mistake-review/')) {
        final examId = state.pathParameters['examId'] ?? '';
        if (examId.isNotEmpty) {
          try {
            final examProvider = Provider.of<ExamProvider>(
              context,
              listen: false,
            );
            final exam = examProvider.getExamById(examId);
            if (exam == null) {
              // Exam not found, redirect to library
              return '/library';
            }
          } catch (e) {
            // If there's any error accessing ExamProvider, redirect to library
            return '/library';
          }
        }
      }
      return null; // No redirect needed
    },
    routes: [
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      ShellRoute(
        builder: (context, state, child) {
          int currentIndex = 0;
          final location = state.uri.toString();
          if (location.startsWith('/library'))
            currentIndex = 0;
          else if (location.startsWith('/stats'))
            currentIndex = 1;
          else if (location.startsWith('/settings'))
            currentIndex = 2;
          return Scaffold(
            body: child,
            bottomNavigationBar: _buildBottomNavigationBar(
              currentIndex,
              context,
            ),
          );
        },
        routes: [
          GoRoute(
            path: '/library',
            builder: (context, state) => const LibraryScreen(),
          ),
          GoRoute(
            path: '/stats',
            builder: (context, state) => const StatsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => SettingsScreen(
              darkMode: darkMode,
              onDarkModeChanged: (v) async {
                setState(() => darkMode = v);
                await _saveTheme(v, themeColor);
              },
              themeColor: themeColor,
              onThemeColorChanged: (c) async {
                setState(() => themeColor = c);
                await _saveTheme(darkMode, c);
              },
              notificationsEnabled: true,
              onNotificationsChanged: (v) {},
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/randomquiz/:examId/:start/:end',
        builder: (context, state) {
          final examId = state.pathParameters['examId'] ?? '';
          final start = int.tryParse(state.pathParameters['start'] ?? '1') ?? 1;
          final end = int.tryParse(state.pathParameters['end'] ?? '1') ?? 1;
          final examProvider = Provider.of<ExamProvider>(
            context,
            listen: false,
          );
          try {
            final exam = examProvider.getExamById(examId);
            if (exam == null) {
              // Fallback to library if exam not found
              return const LibraryScreen();
            }
            final questions = exam.questions.map((q) => q.toMap()).toList();
            return RandomQuizScreen(
              examTitle: exam.title,
              examId: exam.id,
              start: start,
              end: end,
              questions: questions,
            );
          } catch (e) {
            // Fallback to library on any error
            return const LibraryScreen();
          }
        },
      ),
      // All other routes remain outside the shell
      GoRoute(
        path: '/exam/:examId',
        builder: (context, state) {
          final examId = state.pathParameters['examId'] ?? '';
          final examProvider = Provider.of<ExamProvider>(
            context,
            listen: false,
          );
          try {
            final exam = examProvider.getExamById(examId);
            if (exam == null) {
              // Fallback to library if exam not found
              return const LibraryScreen();
            }
            final progressProvider = Provider.of<ProgressProvider>(
              context,
              listen: false,
            );
            final progress = progressProvider.progress;
            int mastered = 0;
            if (progress['masteredQuestions'] is List) {
              mastered = (progress['masteredQuestions'] as List).length;
            }
            return ExamInfoScreen(
              examTitle: exam.title,
              examId: exam.id,
              mastered: mastered,
              total: exam.questions.length,
              setsCompleted: 0,
              totalSets: 1,
              questions: exam.questions.map((q) => q.toMap()).toList(),
            );
          } catch (e) {
            // Fallback to library on any error
            return const LibraryScreen();
          }
        },
      ),

      GoRoute(
        path: '/quiz/:examId/:setIndex',
        builder: (context, state) {
          final examId = state.pathParameters['examId'] ?? '';
          final setIndex =
              int.tryParse(state.pathParameters['setIndex'] ?? '0') ?? 0;
          final examProvider = Provider.of<ExamProvider>(
            context,
            listen: false,
          );
          try {
            final exam = examProvider.getExamById(examId);
            if (exam == null) {
              // Fallback to library if exam not found
              return const LibraryScreen();
            }
            return QuizModeScreen(
              examTitle: exam.title,
              examId: examId,
              questions: exam.questions.map((q) => q.toMap()).toList(),
              setIndex: setIndex,
            );
          } catch (e) {
            // Fallback to library on any error
            return const LibraryScreen();
          }
        },
      ),
      GoRoute(
        path: '/quiz-range/:examId/:start/:end',
        builder: (context, state) {
          final examId = state.pathParameters['examId'] ?? '';
          final start = int.tryParse(state.pathParameters['start'] ?? '1') ?? 1;
          final end = int.tryParse(state.pathParameters['end'] ?? '1') ?? 1;
          final examProvider = Provider.of<ExamProvider>(
            context,
            listen: false,
          );
          try {
            final exam = examProvider.getExamById(examId);
            if (exam == null) {
              // Fallback to library if exam not found
              return const LibraryScreen();
            }
            return QuizModeScreen(
              examTitle: exam.title,
              examId: examId,
              questions: exam.questions.map((q) => q.toMap()).toList(),
              startQuestion: start,
              endQuestion: end,
            );
          } catch (e) {
            // Fallback to library on any error
            return const LibraryScreen();
          }
        },
      ),

      GoRoute(
        path: '/mistake-review/:examId',
        builder: (context, state) {
          final examId = state.pathParameters['examId'] ?? '';
          final examProvider = Provider.of<ExamProvider>(
            context,
            listen: false,
          );
          try {
            final exam = examProvider.getExamById(examId);
            if (exam == null) {
              // Fallback to library if exam not found
              return const LibraryScreen();
            }
            return MistakeReviewScreen(
              examId: examId,
              allQuestions: exam.questions,
            );
          } catch (e) {
            // Fallback to library on any error
            return const LibraryScreen();
          }
        },
      ),
      GoRoute(
        path: '/enhanced-csv-import',
        builder: (context, state) => const EnhancedCsvImportScreen(),
      ),
      GoRoute(
        path: '/comprehensive-import',
        builder: (context, state) => const ComprehensiveImportScreen(),
      ),
      // Admin Portal Routes
      GoRoute(path: '/admin', builder: (context, state) => AdminPortalScreen()),
      GoRoute(
        path: '/enhanced-scraper',
        builder: (context, state) => const EnhancedScraperIntegrationScreen(),
      ),
      GoRoute(
        path: '/voucher-entry',
        builder: (context, state) => VoucherEntryScreen(),
      ),
      GoRoute(
        path: '/exam-selection',
        builder: (context, state) => ExamSelectionScreen(),
      ),
      GoRoute(
        path: '/quiz-mode',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          final examId = args?['examId'] ?? '';
          final examCode = args?['examCode'] ?? '';
          // This would need to be implemented to load questions from AdminService
          return ExamSelectionScreen(); // Placeholder
        },
      ),
    ],
    errorBuilder: (context, state) {
      // Catch all errors and redirect to library
      return const LibraryScreen();
    },
  );

  Widget _buildBottomNavigationBar(int currentIndex, BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isSelected: currentIndex == 0,
                onTap: () => context.go('/library'),
                theme: theme,
              ),
              _buildNavItem(
                icon: Icons.bar_chart_rounded,
                label: 'Stats',
                isSelected: currentIndex == 1,
                onTap: () => context.go('/stats'),
                theme: theme,
              ),
              _buildNavItem(
                icon: Icons.settings_rounded,
                label: 'Settings',
                isSelected: currentIndex == 2,
                onTap: () => context.go('/settings'),
                theme: theme,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? themeColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? themeColor
                  : theme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? themeColor
                    : theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color seed = themeColor;
    final ColorScheme lightScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    final ColorScheme darkScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProgressProvider()),
        ChangeNotifierProvider(create: (_) => ExamProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: MaterialApp.router(
        title: 'ExamTopic Reviewer',
        debugShowCheckedModeBanner: false,
        theme: _buildLightTheme(lightScheme, seed),
        darkTheme: _buildDarkTheme(darkScheme, seed),
        themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
        routerConfig: _router,
      ),
    );
  }

  ThemeData _buildLightTheme(ColorScheme colorScheme, Color seed) {
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: GoogleFonts.poppins().fontFamily,
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        displaySmall: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        headlineLarge: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        headlineSmall: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        titleSmall: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface,
        ),
        bodySmall: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurfaceVariant,
        ),
        labelLarge: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        labelMedium: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        labelSmall: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: seed.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(color: colorScheme.outline, width: 1.5),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurfaceVariant,
        ),
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: colorScheme.surface,
        contentTextStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        elevation: 8,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withOpacity(0.3);
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withOpacity(0.2),
        thickness: 1,
        space: 1,
      ),

      // Icon Theme
      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant, size: 24),
    );
  }

  ThemeData _buildDarkTheme(ColorScheme colorScheme, Color seed) {
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: GoogleFonts.poppins().fontFamily,
      textTheme:
          GoogleFonts.poppinsTextTheme(
            ThemeData(brightness: Brightness.dark).textTheme,
          ).copyWith(
            displayLarge: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
            displayMedium: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            displaySmall: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            headlineLarge: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            headlineMedium: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            headlineSmall: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            titleLarge: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            titleMedium: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            titleSmall: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            bodyLarge: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: colorScheme.onSurface,
            ),
            bodyMedium: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: colorScheme.onSurface,
            ),
            bodySmall: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: colorScheme.onSurfaceVariant,
            ),
            labelLarge: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            labelMedium: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
            labelSmall: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: 4,
        shadowColor: seed.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(color: colorScheme.outline, width: 1.5),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurfaceVariant,
        ),
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: colorScheme.surface,
        contentTextStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        elevation: 8,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withOpacity(0.3);
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withOpacity(0.2),
        thickness: 1,
        space: 1,
      ),

      // Icon Theme
      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant, size: 24),
    );
  }
}
