import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_voucher_service.dart';
import '../services/admin_service.dart';
import '../models/voucher.dart';

class CloudVoucherManagementScreen extends StatefulWidget {
  const CloudVoucherManagementScreen({super.key});

  @override
  State<CloudVoucherManagementScreen> createState() =>
      _CloudVoucherManagementScreenState();
}

class _CloudVoucherManagementScreenState
    extends State<CloudVoucherManagementScreen> {
  bool _isLoading = false;
  List<Voucher> _vouchers = [];
  Map<String, dynamic> _stats = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCloudVouchers();
    _loadStats();
  }

  Future<void> _loadCloudVouchers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final vouchers = await FirebaseVoucherService.getAllCloudVouchers();
      setState(() {
        _vouchers = vouchers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load cloud vouchers: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await FirebaseVoucherService.getVoucherStats();
      setState(() {
        _stats = stats;
      });
    } catch (e) {
      print('Error loading stats: $e');
    }
  }

  Future<void> _generateCloudVoucher() async {
    final nameController = TextEditingController();
    String? selectedExamId;
    Duration? selectedExpiryDuration;
    List<Map<String, dynamic>> importedExams = [];

    // Load imported exams for dropdown
    try {
      importedExams = await AdminService.getImportedExams();
    } catch (e) {
      print('Error loading imported exams: $e');
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.card_giftcard, color: Colors.deepPurple),
              SizedBox(width: 8),
              Text('Generate Cloud Voucher'),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 400, maxHeight: 600),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Voucher Name
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Voucher Name',
                      hintText: 'Enter voucher name',
                      prefixIcon: Icon(Icons.label),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Exam Selection Dropdown
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Exam (Optional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedExamId,
                        decoration: InputDecoration(
                          labelText: 'Choose an exam',
                          hintText:
                              'Select an exam or leave empty for general voucher',
                          prefixIcon: Icon(Icons.quiz),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          isDense: true,
                        ),
                        items: [
                          // General voucher option
                          DropdownMenuItem<String>(
                            value: null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.all_inclusive,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '🎯 General Voucher (All Exams)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Imported exams
                          ...importedExams.map((exam) {
                            return DropdownMenuItem<String>(
                              value: exam['id'] as String,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.quiz,
                                    color: Colors.blue,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${exam['examCode'] ?? 'Unknown'} (${exam['questionCount'] ?? 0} questions)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedExamId = value;
                          });
                        },
                        isExpanded: true,
                        menuMaxHeight: 300,
                      ),
                    ],
                  ),

                  // Info text
                  if (importedExams.isEmpty) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange[700]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No imported exams found. Import exams first to create specific vouchers.',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: 16),

                  // Expiry Duration Selection
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voucher Expiry Duration',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      DropdownButtonFormField<Duration?>(
                        value: selectedExpiryDuration,
                        decoration: InputDecoration(
                          labelText: 'Select expiry duration',
                          hintText: 'Choose when the voucher expires',
                          prefixIcon: Icon(Icons.access_time),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem<Duration?>(
                            value: null,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.all_inclusive,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text('No Expiry (Permanent)'),
                              ],
                            ),
                          ),
                          DropdownMenuItem<Duration?>(
                            value: Duration(days: 3),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  color: Colors.red,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text('3 Days'),
                              ],
                            ),
                          ),
                          DropdownMenuItem<Duration?>(
                            value: Duration(days: 7),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  color: Colors.orange,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text('7 Days'),
                              ],
                            ),
                          ),
                          DropdownMenuItem<Duration?>(
                            value: Duration(days: 30),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  color: Colors.blue,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text('1 Month'),
                              ],
                            ),
                          ),
                          DropdownMenuItem<Duration?>(
                            value: Duration(days: 90),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  color: Colors.purple,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text('3 Months (Default)'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedExpiryDuration = value;
                          });
                        },
                        isExpanded: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop({
                  'name': nameController.text.trim(),
                  'examId': selectedExamId ?? '',
                  'expiryDuration': selectedExpiryDuration,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: Text('Generate Voucher'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final voucher = await AdminService.generateVoucher(
          name: result['name']!.isNotEmpty ? result['name'] : null,
          examId: result['examId']!.isNotEmpty ? result['examId'] : null,
          examExpiryDuration: result['expiryDuration'] as Duration?,
        );

        if (voucher != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 Cloud voucher generated: ${voucher.code}'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to generate voucher'),
              backgroundColor: Colors.red,
            ),
          );
        }

        _loadCloudVouchers();
        _loadStats();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to generate voucher: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteVoucher(Voucher voucher) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Voucher'),
        content: Text(
          'Are you sure you want to delete voucher ${voucher.code}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final success = await FirebaseVoucherService.deleteCloudVoucher(
          voucher.id,
        );
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🗑️ Voucher deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadCloudVouchers();
          _loadStats();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to delete voucher'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error deleting voucher: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _copyVoucherCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 Voucher code copied: $code'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('☁️ Cloud Voucher Management'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadCloudVouchers,
            tooltip: 'Refresh vouchers',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadCloudVouchers,
                    child: Text('Retry'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Statistics Cards
                  _buildStatsCards(theme),
                  SizedBox(height: 24),

                  // Generate Voucher Button
                  _buildGenerateButton(theme),
                  SizedBox(height: 24),

                  // Vouchers List
                  _buildVouchersList(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsCards(ThemeData theme) {
    // Get screen width to determine responsive layout
    final screenWidth = MediaQuery.of(context).size.width;

    // Use different layouts based on screen size
    if (screenWidth < 600) {
      // Mobile: Single column layout
      return Column(
        children: [
          _buildStatCard(
            theme,
            'Total Vouchers',
            '${_stats['totalVouchers'] ?? 0}',
            Icons.card_giftcard,
            Colors.blue,
          ),
          SizedBox(height: 12),
          _buildStatCard(
            theme,
            'Active Vouchers',
            '${_stats['activeVouchers'] ?? 0}',
            Icons.check_circle,
            Colors.green,
          ),
          SizedBox(height: 12),
          _buildStatCard(
            theme,
            'Redeemed',
            '${_stats['totalRedeemed'] ?? 0}',
            Icons.check_circle_outline,
            Colors.orange,
          ),
        ],
      );
    } else {
      // Tablet/Desktop: Grid layout
      return GridView.count(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: screenWidth < 800 ? 1.8 : 1.5,
        children: [
          _buildStatCard(
            theme,
            'Total Vouchers',
            '${_stats['totalVouchers'] ?? 0}',
            Icons.card_giftcard,
            Colors.blue,
          ),
          _buildStatCard(
            theme,
            'Active Vouchers',
            '${_stats['activeVouchers'] ?? 0}',
            Icons.check_circle,
            Colors.green,
          ),
          _buildStatCard(
            theme,
            'Redeemed',
            '${_stats['totalRedeemed'] ?? 0}',
            Icons.check_circle_outline,
            Colors.orange,
          ),
        ],
      );
    }
  }

  Widget _buildStatCard(
    ThemeData theme,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: isMobile
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 24, color: color),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            value,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 32, color: color),
                  SizedBox(height: 8),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildGenerateButton(ThemeData theme) {
    return Card(
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _generateCloudVoucher,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add, color: Colors.white, size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Generate Cloud Voucher',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Create a new voucher stored in Firebase',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVouchersList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cloud Vouchers (${_vouchers.length})',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        if (_vouchers.isEmpty)
          Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No cloud vouchers found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Generate your first cloud voucher to get started',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _vouchers.length,
            itemBuilder: (context, index) {
              final voucher = _vouchers[index];
              return Card(
                margin: EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: voucher.isValid
                        ? Colors.green
                        : Colors.red,
                    child: Icon(
                      voucher.isValid ? Icons.check : Icons.close,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    voucher.name,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Code: ${voucher.code}'),
                      Text(
                        voucher.isValid
                            ? 'Status: Active'
                            : 'Status: ${voucher.isUsed ? "Used" : "Expired"}',
                        style: TextStyle(
                          color: voucher.isValid ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (voucher.isUsed && voucher.usedDate != null) ...[
                        Text(
                          'Redeemed: ${voucher.usedDate!.toString().split(' ')[0]}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (voucher.usedBy != null)
                          Text(
                            'By: ${voucher.usedBy}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                      if (voucher.examData != null &&
                          voucher.examData!.isNotEmpty) ...[
                        Text(
                          '📚 Exam: ${voucher.examData!['title'] ?? voucher.examData!['examCode'] ?? 'Unknown'}',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '📊 Questions: ${voucher.examData!['questionCount'] ?? 0}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (voucher.examExpiryDuration != null)
                          Text(
                            '⏰ Expires in: ${voucher.examExpiryDuration!.inDays} days after redemption',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                            ),
                          ),
                      ] else if (voucher.examId != null)
                        Text(
                          '📚 Exam ID: ${voucher.examId}',
                          style: TextStyle(color: Colors.blue),
                        )
                      else
                        Text(
                          '🎯 General Voucher',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      Text(
                        'Expires: ${voucher.expiryDate.toString().split(' ')[0]}',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          children: [
                            Icon(Icons.copy, size: 16),
                            SizedBox(width: 8),
                            Text('Copy Code'),
                          ],
                        ),
                      ),
                      // Only show delete option for unused vouchers
                      if (!voucher.isUsed)
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onSelected: (value) {
                      if (value == 'copy') {
                        _copyVoucherCode(voucher.code);
                      } else if (value == 'delete') {
                        _deleteVoucher(voucher);
                      }
                    },
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
