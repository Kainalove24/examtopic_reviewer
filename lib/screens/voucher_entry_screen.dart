import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/admin_service.dart';
import '../services/firebase_voucher_service.dart';
import '../models/voucher.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added for guest user check

class VoucherEntryScreen extends StatefulWidget {
  const VoucherEntryScreen({super.key});

  @override
  _VoucherEntryScreenState createState() => _VoucherEntryScreenState();
}

class _VoucherEntryScreenState extends State<VoucherEntryScreen> {
  final TextEditingController _voucherController = TextEditingController();
  bool _isValidating = false;
  bool _isValid = false;
  String _validationMessage = '';
  Voucher? _currentVoucher;

  @override
  void initState() {
    super.initState();
    // Check for voucher in URL when screen loads
    _checkForVoucherInUrl();
  }

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  Future<void> _checkForVoucherInUrl() async {
    try {
      final voucher = await AdminService.getVoucherFromUrl();
      if (voucher != null) {
        setState(() {
          _currentVoucher = voucher;
          _isValid = true;
          _validationMessage = 'Voucher found in URL! You can now redeem it.';
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voucher found in URL: ${voucher.code}'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error checking for voucher in URL: $e');
    }
  }

  Future<void> _validateVoucher() async {
    final code = _voucherController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _validationMessage = 'Please enter a voucher code';
        _isValid = false;
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _validationMessage = 'Validating voucher with cloud...';
    });

    try {
      // Only use cloud validation
      Voucher? cloudVoucher = await FirebaseVoucherService.validateCloudVoucher(
        code,
      );

      if (cloudVoucher != null) {
        setState(() {
          _isValid = true;
          String examInfo = '';
          if (cloudVoucher.examData != null &&
              cloudVoucher.examData!.isNotEmpty) {
            // Old format: embedded exam data
            final examData = cloudVoucher.examData!;
            examInfo =
                '\n📚 Exam: ${examData['title'] ?? examData['examCode'] ?? 'Unknown'}';
            examInfo += '\n📊 Questions: ${examData['questionCount'] ?? 0}';
            if (cloudVoucher.examExpiryDuration != null) {
              examInfo +=
                  '\n⏰ Expires in: ${cloudVoucher.examExpiryDuration!.inDays} days after redemption';
            }
          } else if (cloudVoucher.examId != null) {
            // New format: examId reference
            examInfo = '\n📚 Exam ID: ${cloudVoucher.examId}';
            examInfo += '\n🔗 Exam data will be fetched from Firebase';
            if (cloudVoucher.examExpiryDuration != null) {
              examInfo +=
                  '\n⏰ Expires in: ${cloudVoucher.examExpiryDuration!.inDays} days after redemption';
            }
          } else {
            examInfo = '\n🎯 General voucher (unlocks all exams)';
          }

          // Check if user is guest and add login requirement notice
          final user = FirebaseAuth.instance.currentUser;
          final isGuest = user == null || user.isAnonymous;
          String loginNotice = '';
          if (isGuest) {
            loginNotice =
                '\n⚠️ Login required to redeem this voucher and prevent data loss.';
          }

          _validationMessage =
              '✅ Cloud voucher is valid! You can now redeem it.$examInfo$loginNotice';
          _currentVoucher = cloudVoucher;
        });
      } else {
        setState(() {
          _isValid = false;
          _validationMessage =
              '❌ Invalid or expired voucher code. Please check your code and try again.';
          _currentVoucher = null;
        });
      }
    } catch (e) {
      setState(() {
        _isValid = false;
        _validationMessage = '❌ Error validating voucher. Please try again.';
        _currentVoucher = null;
      });
      print('Voucher validation error: $e');
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }

  Future<void> _redeemVoucher() async {
    if (!_isValid || _currentVoucher == null) return;

    setState(() {
      _isValidating = true;
      _validationMessage = 'Checking user status...';
    });

    try {
      // Check if user is guest (not authenticated)
      final user = FirebaseAuth.instance.currentUser;
      final isGuest = user == null || user.isAnonymous;

      if (isGuest) {
        // Guest user - prompt to log in
        setState(() {
          _isValidating = false;
          _validationMessage =
              'Please log in to redeem this voucher and prevent data loss.';
        });

        // Show login prompt dialog
        final shouldLogin = await _showLoginPromptDialog();
        if (shouldLogin) {
          // Navigate to auth screen
          if (mounted) {
            context.go('/auth');
          }
        }
        return; // Don't proceed with redemption
      }

      // User is authenticated - proceed with redemption
      setState(() {
        _validationMessage = 'Redeeming voucher...';
      });

      final userId = user.uid; // Use actual user ID

      // Use AdminService to handle embedded exam data
      bool success = await AdminService.useVoucher(
        _currentVoucher!.code,
        userId,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 Voucher redeemed successfully! Check your library for the unlocked exam.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate to library to see unlocked exam
        // Use a longer delay to ensure the exam is fully saved
        await Future.delayed(Duration(seconds: 1));
        if (mounted) {
          // Navigate to library with a refresh parameter
          context.go('/library?refresh=true');
        }
      } else {
        setState(() {
          _isValid = false;
          _validationMessage =
              '❌ Failed to redeem voucher. It may have already been used or expired.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to redeem voucher. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isValid = false;
        _validationMessage = '❌ Error redeeming voucher. Please try again.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error redeeming voucher. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      print('Voucher redemption error: $e');
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }

  // Show login prompt dialog
  Future<bool> _showLoginPromptDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Text('Login Required'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'To redeem this voucher and prevent data loss, you need to log in.',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[700],
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Why login is required:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• Your unlocked exams will be saved to the cloud\n'
                        '• You can access them from any device\n'
                        '• Your progress will be synchronized\n'
                        '• No risk of losing data if you switch devices',
                        style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Your voucher will remain valid and can be redeemed after logging in.',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text('Log In'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _formatExpiryDuration(Duration? duration) {
    if (duration == null) return 'No expiry (Permanent)';

    if (duration.inDays == 0) {
      return '${duration.inHours} hours';
    } else if (duration.inDays == 1) {
      return '1 day';
    } else if (duration.inDays < 7) {
      return '${duration.inDays} days';
    } else if (duration.inDays < 30) {
      final weeks = (duration.inDays / 7).round();
      return '$weeks week${weeks > 1 ? 's' : ''}';
    } else {
      final months = (duration.inDays / 30).round();
      return '$months month${months > 1 ? 's' : ''}';
    }
  }

  Future<void> _copyVoucherCode() async {
    if (_currentVoucher == null) return;

    try {
      await Clipboard.setData(ClipboardData(text: _currentVoucher!.code));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Voucher code copied to clipboard: ${_currentVoucher!.code}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to copy voucher code: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Enter Voucher'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Icon(Icons.card_giftcard, size: 80, color: Colors.deepPurple),
            SizedBox(height: 24),

            Text(
              'Welcome to ExamTopics Reviewer',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),

            Text(
              'Enter your voucher code to access exam questions',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),

            // Voucher Input
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Voucher Code',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 12),

                    TextField(
                      controller: _voucherController,
                      decoration: InputDecoration(
                        hintText: 'Enter voucher code (e.g., ABCD-EFGH)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.confirmation_number),
                        suffixIcon: _isValidating
                            ? Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[A-Z0-9\-]'),
                        ),
                      ],
                      onChanged: (value) {
                        if (_isValid) {
                          setState(() {
                            _isValid = false;
                            _validationMessage = '';
                            _currentVoucher = null;
                          });
                        }
                      },
                    ),
                    SizedBox(height: 16),

                    // Validation Message
                    if (_validationMessage.isNotEmpty)
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isValid ? Colors.green[50] : Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isValid ? Colors.green : Colors.red,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isValid ? Icons.check_circle : Icons.error,
                              color: _isValid ? Colors.green : Colors.red,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _validationMessage,
                                style: TextStyle(
                                  color: _isValid
                                      ? Colors.green[700]
                                      : Colors.red[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 16),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isValidating ? null : _validateVoucher,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: Text('Validate Voucher'),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isValid ? _redeemVoucher : null,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              // Check if user is guest and show appropriate text
                              () {
                                if (!_isValid) return 'Redeem Voucher';
                                final user = FirebaseAuth.instance.currentUser;
                                final isGuest =
                                    user == null || user.isAnonymous;
                                return isGuest
                                    ? 'Login to Redeem'
                                    : 'Redeem Voucher';
                              }(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),

            // Voucher Details (if valid)
            if (_currentVoucher != null)
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Voucher Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.copy, color: Colors.blue),
                            onPressed: _copyVoucherCode,
                            tooltip: 'Copy voucher code',
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text('Code: ${_currentVoucher!.code}'),
                      if (_currentVoucher!.examId != null) ...[
                        Text(
                          'Unlocks: Specific Exam',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Unlocks: All Exams',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      Text(
                        'Created: ${_currentVoucher!.createdDate.toString().split('.')[0]}',
                      ),
                      Text(
                        'Expires: ${_currentVoucher!.expiryDate.toString().split('.')[0]}',
                      ),
                      if (_currentVoucher!.examExpiryDuration != null) ...[
                        Text(
                          'Exam Access: ${_formatExpiryDuration(_currentVoucher!.examExpiryDuration)}',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      Text(
                        'Status: ACTIVE',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Show login requirement for guest users
                      if (() {
                        final user = FirebaseAuth.instance.currentUser;
                        final isGuest = user == null || user.isAnonymous;
                        return isGuest;
                      }()) ...[
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning,
                                color: Colors.orange[700],
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Login required to redeem this voucher and prevent data loss.',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            SizedBox(height: 32),

            // Footer
            Text(
              'Vouchers can only be used once and have varying expiry durations',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16), // Extra padding at bottom
          ],
        ),
      ),
    );
  }
}
