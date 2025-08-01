// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/admin_auth_service.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showEmailForm = false;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (auth.user != null) {
        // Use GoRouter navigation for correct routing
        if (ModalRoute.of(context)?.settings.name != '/library') {
          // Avoid navigation loop
          context.go('/library');
        }
      }
    });

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withOpacity(0.1),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: auth.isLoading
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Signing you in...',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This may take a few moments',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(
                            0.7,
                          ),
                        ),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // App Logo/Title
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.school_rounded,
                            size: 48,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'ExamTopic Reviewer',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Master your exams with AI-powered learning',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),

                        // Admin Mode Indicator (if admin is authenticated)
                        FutureBuilder<bool>(
                          future: AdminAuthService.isAuthenticated(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data == true) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.admin_panel_settings,
                                      color: theme.colorScheme.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Admin Mode Active',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.primary,
                                          ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: () => context.go('/admin'),
                                      child: Text(
                                        'Go to Admin Portal',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return SizedBox.shrink();
                          },
                        ),

                        if (!_showEmailForm) ...[
                          // Guest Sign In
                          _buildAuthButton(
                            context: context,
                            icon: Icons.person_outline_rounded,
                            title: 'Continue as Guest',
                            subtitle: 'Start learning without an account',
                            onTap: auth.signInAnonymously,
                            isPrimary: true,
                          ),
                          const SizedBox(height: 16),

                          // Email Sign In
                          _buildAuthButton(
                            context: context,
                            icon: Icons.email_outlined,
                            title: 'Sign in with Email',
                            subtitle: 'Use your email and password',
                            onTap: () => setState(() => _showEmailForm = true),
                            isPrimary: false,
                          ),
                          const SizedBox(height: 16),

                          // Google Sign In
                          _buildGoogleAuthButton(context, auth),
                        ] else ...[
                          // Email Form
                          Card(
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.email_rounded,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Sign in with Email',
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  TextField(
                                    controller: _emailController,
                                    decoration: const InputDecoration(
                                      labelText: 'Email',
                                      prefixIcon: Icon(Icons.email_outlined),
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _passwordController,
                                    decoration: const InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: Icon(Icons.lock_outlined),
                                    ),
                                    obscureText: true,
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => setState(
                                            () => _showEmailForm = false,
                                          ),
                                          child: const Text('Back'),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            final email = _emailController.text
                                                .trim();
                                            final password = _passwordController
                                                .text
                                                .trim();

                                            if (email.isEmpty) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Please enter your email',
                                                  ),
                                                ),
                                              );
                                              return;
                                            }

                                            if (password.isEmpty) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Please enter your password',
                                                  ),
                                                ),
                                              );
                                              return;
                                            }

                                            try {
                                              // Check if this is an admin login
                                              if (email == 'admin@admin.com' ||
                                                  email == 'admin') {
                                                final adminSuccess =
                                                    await AdminAuthService.authenticate(
                                                      email,
                                                      password,
                                                    );
                                                if (adminSuccess) {
                                                  // Navigate to admin portal
                                                  context.go('/admin');
                                                  return;
                                                } else {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Invalid admin credentials',
                                                      ),
                                                    ),
                                                  );
                                                  return;
                                                }
                                              }

                                              // Regular user authentication
                                              await auth.signInWithEmail(
                                                email,
                                                password,
                                              );
                                            } catch (e) {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Sign-in failed: $e',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          child: const Text('Sign In'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // Footer
                        Text(
                          'By continuing, you agree to our Terms of Service and Privacy Policy',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isPrimary
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isPrimary
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: theme.colorScheme.onSurfaceVariant,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleAuthButton(BuildContext context, AuthProvider auth) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () async {
          try {
            await auth.signInWithGoogle();
          } catch (e) {
            if (!mounted) return;

            // Show a more user-friendly error message
            String errorMessage = 'Google Sign-In failed';
            if (e.toString().contains('cancelled')) {
              errorMessage = 'Sign-in was cancelled';
            } else if (e.toString().contains('network') ||
                e.toString().contains('connection')) {
              errorMessage = 'Network error. Please check your connection';
            } else if (e.toString().contains('timeout')) {
              errorMessage = 'Sign-in timed out. Please try again';
            } else if (e.toString().contains('configuration') ||
                e.toString().contains('invalid_client')) {
              errorMessage =
                  'Google Sign-In configuration error. Please contact support.';
            } else if (e.toString().contains('popup_blocked')) {
              errorMessage =
                  'Popup was blocked. Please allow popups for this site and try again.';
            } else if (e.toString().contains('tokens')) {
              errorMessage = 'Authentication failed. Please try again';
            } else {
              errorMessage = 'Google Sign-In failed: ${e.toString()}';
            }

            // Show error dialog with options
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Google Sign-In Failed'),
                content: Text(errorMessage),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Try anonymous sign-in as fallback
                      auth.signInAnonymously();
                    },
                    child: const Text('Continue as Guest'),
                  ),
                ],
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.google,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sign in with Google',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Quick and secure sign-in',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: theme.colorScheme.onSurfaceVariant,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
