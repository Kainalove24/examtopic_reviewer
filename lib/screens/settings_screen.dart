// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/exam_provider.dart';
import '../providers/progress_provider.dart';
import '../services/data_management_service.dart';
import '../services/admin_auth_service.dart';

class SettingsScreen extends StatefulWidget {
  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final Color themeColor;
  final ValueChanged<Color> onThemeColorChanged;
  final bool notificationsEnabled;
  final ValueChanged<bool> onNotificationsChanged;

  const SettingsScreen({
    super.key,
    required this.darkMode,
    required this.onDarkModeChanged,
    required this.themeColor,
    required this.onThemeColorChanged,
    required this.notificationsEnabled,
    required this.onNotificationsChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appearance Section
            _buildSectionHeader(context, 'Appearance', Icons.palette),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    _buildSettingTile(
                      context: context,
                      icon: Icons.brightness_6,
                      title: 'Dark Mode',
                      subtitle: 'Switch between light and dark themes',
                      trailing: Switch(
                        value: widget.darkMode,
                        onChanged: widget.onDarkModeChanged,
                        activeColor: theme.colorScheme.primary,
                      ),
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16),
                    _buildSettingTile(
                      context: context,
                      icon: Icons.color_lens,
                      title: 'Theme Color',
                      subtitle: 'Choose your preferred accent color',
                      trailing: GestureDetector(
                        onTap: () async {
                          final color = await showDialog<Color>(
                            context: context,
                            builder: (context) =>
                                _ThemeColorDialog(current: widget.themeColor),
                          );
                          if (color != null) widget.onThemeColorChanged(color);
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: widget.themeColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.outline.withOpacity(0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: widget.themeColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Study Preferences Section
            _buildSectionHeader(context, 'Study Preferences', Icons.school),
            const SizedBox(height: 12),
            Consumer<SettingsProvider>(
              builder: (context, settings, child) {
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      children: [
                        _buildSettingTile(
                          context: context,
                          icon: Icons.save_alt,
                          title: 'Auto-save Progress',
                          subtitle: 'Automatically save your study progress',
                          trailing: Switch(
                            value: settings.autoSaveProgress,
                            onChanged: (value) =>
                                settings.setAutoSaveProgress(value),
                            activeColor: theme.colorScheme.primary,
                          ),
                        ),
                        const Divider(height: 1, indent: 56, endIndent: 16),
                        _buildSettingTile(
                          context: context,
                          icon: Icons.lightbulb_outline,
                          title: 'Show Hints',
                          subtitle: 'Display helpful hints during quizzes',
                          trailing: Switch(
                            value: settings.showHints,
                            onChanged: (value) => settings.setShowHints(value),
                            activeColor: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Notifications Section
            _buildSectionHeader(context, 'Notifications', Icons.notifications),
            const SizedBox(height: 12),
            Consumer<SettingsProvider>(
              builder: (context, settings, child) {
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      children: [
                        _buildSettingTile(
                          context: context,
                          icon: Icons.notifications_active,
                          title: 'Enable Notifications',
                          subtitle: 'Receive study reminders and updates',
                          trailing: Switch(
                            value: widget.notificationsEnabled,
                            onChanged: widget.onNotificationsChanged,
                            activeColor: theme.colorScheme.primary,
                          ),
                        ),
                        const Divider(height: 1, indent: 56, endIndent: 16),
                        _buildSettingTile(
                          context: context,
                          icon: Icons.volume_up,
                          title: 'Sound Effects',
                          subtitle: 'Play sounds for correct/incorrect answers',
                          trailing: Switch(
                            value: settings.soundEnabled,
                            onChanged: (value) =>
                                settings.setSoundEnabled(value),
                            activeColor: theme.colorScheme.primary,
                          ),
                        ),
                        const Divider(height: 1, indent: 56, endIndent: 16),
                        _buildSettingTile(
                          context: context,
                          icon: Icons.vibration,
                          title: 'Vibration',
                          subtitle: 'Vibrate on quiz interactions',
                          trailing: Switch(
                            value: settings.vibrationEnabled,
                            onChanged: (value) =>
                                settings.setVibrationEnabled(value),
                            activeColor: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Data Management Section
            _buildSectionHeader(context, 'Data Management', Icons.storage),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    _buildSettingTile(
                      context: context,
                      icon: Icons.backup,
                      title: 'Create Backup',
                      subtitle: 'Backup all your data locally',
                      trailing: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: () => _showBackupDialog(context),
                      ),
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16),
                    _buildSettingTile(
                      context: context,
                      icon: Icons.restore,
                      title: 'Restore from Backup',
                      subtitle: 'Restore your data from a backup file',
                      trailing: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: () => _showRestoreDialog(context),
                      ),
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16),
                    _buildSettingTile(
                      context: context,
                      icon: Icons.file_download,
                      title: 'Export Data',
                      subtitle: 'Export all data to a JSON file',
                      trailing: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: () => _showExportDialog(context),
                      ),
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16),
                    _buildSettingTile(
                      context: context,
                      icon: Icons.file_upload,
                      title: 'Import Data',
                      subtitle: 'Import data from a JSON file',
                      trailing: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: () => _showImportDialog(context),
                      ),
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16),
                    _buildSettingTile(
                      context: context,
                      icon: Icons.analytics,
                      title: 'Data Statistics',
                      subtitle: 'View your data usage and statistics',
                      trailing: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: () => _showDataStatisticsDialog(context),
                      ),
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16),
                    _buildSettingTile(
                      context: context,
                      icon: Icons.delete_sweep,
                      title: 'Clear All Data',
                      subtitle: 'Remove all progress and imported exams',
                      trailing: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: () => _showClearDataDialog(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // AI Settings Section
            _buildSectionHeader(context, 'AI Features', Icons.psychology),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Consumer<SettingsProvider>(
                  builder: (context, settings, child) {
                    return Column(
                      children: [
                        _buildSettingTile(
                          context: context,
                          icon: Icons.psychology,
                          title: 'AI Explanations',
                          subtitle: 'Get AI-powered explanations for questions',
                          trailing: Switch(
                            value: settings.aiExplanationsEnabled,
                            onChanged: settings.setAiExplanationsEnabled,
                            activeColor: theme.colorScheme.primary,
                          ),
                        ),
                        if (settings.aiExplanationsEnabled) ...[
                          const Divider(height: 1, indent: 56, endIndent: 16),
                          Container(
                            margin: const EdgeInsets.all(12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'API Key Configured',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'AI explanations are ready to use',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: Colors.green.shade700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Account Section
            _buildSectionHeader(context, 'Account', Icons.account_circle),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    if (auth.user == null || auth.user!.isAnonymous) ...[
                      _buildAuthButton(
                        context: context,
                        icon: Icons.email,
                        title: 'Sign in with Email',
                        subtitle: 'Use your email and password',
                        onTap: () => _showEmailSignInDialog(context, auth),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _buildAuthButton(
                        context: context,
                        icon: Icons.g_mobiledata,
                        title: 'Sign in with Google',
                        subtitle: 'Quick and secure sign-in',
                        onTap: () => auth.signInWithGoogle(),
                      ),
                    ] else ...[
                      _buildSettingTile(
                        context: context,
                        icon: Icons.account_circle,
                        title: 'Signed in as',
                        subtitle: auth.user!.email ?? 'Guest User',
                        trailing: IconButton(
                          icon: const Icon(Icons.logout),
                          onPressed: () => auth.signOut(),
                          tooltip: 'Sign out',
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.errorContainer,
                            foregroundColor: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _buildSettingTile(
                        context: context,
                        icon: Icons.security,
                        title: 'Privacy Settings',
                        subtitle: 'Manage your privacy preferences',
                        trailing: IconButton(
                          icon: const Icon(Icons.arrow_forward_ios),
                          onPressed: () => _showPrivacyDialog(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Voucher Entry Section (for all users)
            _buildSectionHeader(context, 'Voucher Access', Icons.card_giftcard),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    _buildSettingTile(
                      context: context,
                      icon: Icons.card_giftcard,
                      title: 'Enter Voucher',
                      subtitle: 'Redeem voucher to access exams',
                      trailing: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: () => context.go('/voucher-entry'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Admin Section (only for authenticated admins)
            FutureBuilder<bool>(
              future: AdminAuthService.isAuthenticated(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data == true) {
                  return Column(
                    children: [
                      _buildSectionHeader(
                        context,
                        'Administration',
                        Icons.admin_panel_settings,
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            children: [
                              _buildSettingTile(
                                context: context,
                                icon: Icons.download,
                                title: 'Admin Portal',
                                subtitle: 'Manage exams and generate vouchers',
                                trailing: IconButton(
                                  icon: const Icon(Icons.arrow_forward_ios),
                                  onPressed: () {
                                    context.go('/admin');
                                  },
                                ),
                              ),
                              const Divider(
                                height: 1,
                                indent: 56,
                                endIndent: 16,
                              ),
                              _buildSettingTile(
                                context: context,
                                icon: Icons.swap_horiz,
                                title: 'Switch to Admin Portal',
                                subtitle:
                                    'Access admin features and management',
                                trailing: IconButton(
                                  icon: const Icon(Icons.arrow_forward_ios),
                                  onPressed: () {
                                    context.go('/admin');
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  );
                }
                return SizedBox.shrink(); // Hide completely for normal users
              },
            ),

            // Hidden Admin Login (for direct access)
            // This is completely hidden from UI but accessible via direct navigation
            // Users can access /admin-login directly if they know the route
            _buildSettingTile(
              context: context,
              icon: Icons.app_settings_alt,
              title: 'App Version',
              subtitle: '1.0.0',
              trailing: const Icon(Icons.chevron_right),
            ),
            const SizedBox(height: 32),

            // App Info Section
            _buildSectionHeader(context, 'About', Icons.info),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    _buildSettingTile(
                      context: context,
                      icon: Icons.app_settings_alt,
                      title: 'App Version',
                      subtitle: '1.0.0',
                      trailing: const Icon(Icons.chevron_right),
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16),
                    _buildSettingTile(
                      context: context,
                      icon: Icons.description,
                      title: 'Terms of Service',
                      subtitle: 'Read our terms and conditions',
                      trailing: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: () => _showTermsDialog(context),
                      ),
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16),
                    _buildSettingTile(
                      context: context,
                      icon: Icons.privacy_tip,
                      title: 'Privacy Policy',
                      subtitle: 'Learn about our privacy practices',
                      trailing: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: () => _showPrivacyPolicyDialog(context),
                      ),
                    ),
                    const Divider(height: 1, indent: 56, endIndent: 16),
                    _buildSettingTile(
                      context: context,
                      icon: Icons.feedback,
                      title: 'Send Feedback',
                      subtitle: 'Help us improve the app',
                      trailing: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: () => _showFeedbackDialog(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: theme.colorScheme.onPrimaryContainer,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: theme.colorScheme.primary, size: 20),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildAuthButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: theme.colorScheme.primary, size: 20),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Sign In',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  // Dialog Methods

  void _showBackupDialog(BuildContext context) async {
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final progressProvider = Provider.of<ProgressProvider>(
      context,
      listen: false,
    );
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final dataService = DataManagementService();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Creating Backup'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Creating backup...'),
          ],
        ),
      ),
    );

    try {
      final backupPath = await dataService.backupData(
        examProvider: examProvider,
        progressProvider: progressProvider,
        settingsProvider: settingsProvider,
      );

      Navigator.pop(context); // Close loading dialog

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Backup Created'),
          content: Text('Backup saved to:\n$backupPath'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Backup Failed'),
          content: Text('Failed to create backup: $e'),
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

  void _showRestoreDialog(BuildContext context) async {
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final progressProvider = Provider.of<ProgressProvider>(
      context,
      listen: false,
    );
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final dataService = DataManagementService();

    try {
      final backups = await dataService.getAvailableBackups();

      if (backups.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No Backups Found'),
            content: const Text(
              'No backup files found. Create a backup first.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Backup to Restore'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: backups.length,
              itemBuilder: (context, index) {
                final backup = backups[index];
                final stat = backup.statSync();
                final date = stat.modified;

                return ListTile(
                  title: Text(backup.path.split('/').last),
                  subtitle: Text(
                    'Created: ${date.toString().substring(0, 19)}',
                  ),
                  onTap: () async {
                    Navigator.pop(context); // Close selection dialog

                    // Show confirmation dialog
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirm Restore'),
                        content: const Text(
                          'This will overwrite all current data. Are you sure?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Restore'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      // Show loading dialog
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => AlertDialog(
                          title: const Text('Restoring Data'),
                          content: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Restoring from backup...'),
                            ],
                          ),
                        ),
                      );

                      try {
                        await dataService.restoreFromBackup(
                          filePath: backup.path,
                          examProvider: examProvider,
                          progressProvider: progressProvider,
                          settingsProvider: settingsProvider,
                        );

                        Navigator.pop(context); // Close loading dialog

                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Restore Complete'),
                            content: const Text(
                              'Data has been restored successfully.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      } catch (e) {
                        Navigator.pop(context); // Close loading dialog

                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Restore Failed'),
                            content: Text('Failed to restore data: $e'),
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
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to load backups: $e'),
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

  void _showExportDialog(BuildContext context) async {
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final progressProvider = Provider.of<ProgressProvider>(
      context,
      listen: false,
    );
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final dataService = DataManagementService();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Exporting Data'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Preparing export...'),
          ],
        ),
      ),
    );

    try {
      final jsonData = await dataService.exportAllData(
        examProvider: examProvider,
        progressProvider: progressProvider,
        settingsProvider: settingsProvider,
      );

      Navigator.pop(context); // Close loading dialog

      final filePath = await dataService.saveExportFile(jsonData);

      if (filePath != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Export Complete'),
            content: Text('Data exported to:\n$filePath'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Export Cancelled'),
            content: const Text('Export was cancelled.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export Failed'),
          content: Text('Failed to export data: $e'),
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

  void _showImportDialog(BuildContext context) async {
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final progressProvider = Provider.of<ProgressProvider>(
      context,
      listen: false,
    );
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final dataService = DataManagementService();

    try {
      final filePath = await dataService.pickImportFile();

      if (filePath == null) {
        return; // User cancelled
      }

      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Import'),
          content: const Text(
            'This will import data from the selected file. Existing data may be overwritten. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Importing Data'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Importing data...'),
              ],
            ),
          ),
        );

        try {
          final file = File(filePath);
          final jsonData = await file.readAsString();

          await dataService.importData(
            jsonData: jsonData,
            examProvider: examProvider,
            progressProvider: progressProvider,
            settingsProvider: settingsProvider,
            overwriteExisting: true,
          );

          Navigator.pop(context); // Close loading dialog

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Import Complete'),
              content: const Text('Data has been imported successfully.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } catch (e) {
          Navigator.pop(context); // Close loading dialog

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Import Failed'),
              content: Text('Failed to import data: $e'),
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
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Error'),
          content: Text('Failed to select file: $e'),
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

  void _showDataStatisticsDialog(BuildContext context) async {
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final progressProvider = Provider.of<ProgressProvider>(
      context,
      listen: false,
    );
    final dataService = DataManagementService();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Loading Statistics'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Calculating statistics...'),
          ],
        ),
      ),
    );

    try {
      final stats = await dataService.getDataStatistics(
        examProvider: examProvider,
        progressProvider: progressProvider,
      );

      Navigator.pop(context); // Close loading dialog

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Data Statistics'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Exams: ${stats['totalExams']}'),
              const SizedBox(height: 8),
              Text('Total Questions: ${stats['totalQuestions']}'),
              const SizedBox(height: 8),
              Text('Backup Files: ${stats['backupCount']}'),
              if (stats['lastBackup'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Last Backup: ${stats['lastBackup'].toString().substring(0, 19)}',
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to load statistics: $e'),
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

  void _showImageImportDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Images'),
        content: const Text(
          'This feature allows you to import folders of images for use with your exams. '
          'Images will be copied to the app\'s image directory and can be referenced in CSV files.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import Images'),
          ),
        ],
      ),
    );

    if (result == true) {
      // Navigate to image import screen (to be implemented)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image import feature coming soon!')),
      );
    }
  }

  void _showClearDataDialog(BuildContext context) async {
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final progressProvider = Provider.of<ProgressProvider>(
      context,
      listen: false,
    );
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final dataService = DataManagementService();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all your progress and imported exams. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Clearing Data'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Clearing all data...'),
            ],
          ),
        ),
      );

      try {
        await dataService.clearAllData(
          examProvider: examProvider,
          progressProvider: progressProvider,
          settingsProvider: settingsProvider,
        );

        Navigator.pop(context); // Close loading dialog

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Data Cleared'),
            content: const Text('All data has been cleared successfully.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } catch (e) {
        Navigator.pop(context); // Close loading dialog

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clear Failed'),
            content: Text('Failed to clear data: $e'),
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
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Settings'),
        content: const Text('Privacy settings will be available soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const Text('Terms of service will be available soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const Text('Privacy policy will be available soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Feedback'),
        content: const Text('Feedback feature will be available soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEmailSignInDialog(
    BuildContext context,
    AuthProvider auth,
  ) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.email, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Sign in with Email'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outlined),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await auth.signInWithEmail(
                emailController.text.trim(),
                passwordController.text.trim(),
              );
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}

class _ThemeColorDialog extends StatelessWidget {
  final Color current;
  const _ThemeColorDialog({required this.current});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = [
      const Color(0xFF7C83FD), // blue-purple
      const Color(0xFF6AD7E5), // teal
      const Color(0xFFB388FF), // purple
      const Color(0xFF81C784), // green
      const Color(0xFFFFB6B9), // pink
      const Color(0xFFFFB74D), // orange
      const Color(0xFFF06292), // pink-red
      const Color(0xFF4FC3F7), // light blue
      const Color(0xFF9575CD), // deep purple
      const Color(0xFF4DB6AC), // teal green
    ];

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.color_lens, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Choose Theme Color'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Select your preferred accent color',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: colors.map((color) {
              final isSelected = current == color;
              return GestureDetector(
                onTap: () => Navigator.pop(context, color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withOpacity(0.3),
                      width: isSelected ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: isSelected ? 12 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 24)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
