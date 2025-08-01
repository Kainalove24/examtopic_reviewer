import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/admin_service.dart';
import '../services/firebase_voucher_service.dart';
import '../models/voucher.dart';

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
          _validationMessage =
              '✅ Cloud voucher is valid! You can now redeem it.$examInfo';
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
      _validationMessage = 'Redeeming voucher...';
    });

    try {
      final userId =
          'user_${DateTime.now().millisecondsSinceEpoch}'; // Simple user ID

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
      body: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
                            child: Text('Redeem Voucher'),
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
                      Text(
                        'Status: ACTIVE',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Spacer(),

            // Footer
            Text(
              'Vouchers are valid for 3 months and can only be used once',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
