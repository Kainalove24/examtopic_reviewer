# ExamTopic Reviewer

A comprehensive exam preparation app with AI-powered learning features and admin management capabilities.

## Features

### For Students
- 📚 Study library with imported exams
- 🧠 AI-powered explanations for questions
- 📊 Progress tracking and analytics
- 🎯 Quiz modes with customizable ranges
- 🔄 Mistake review system
- 🎁 Voucher-based exam access

### For Administrators
- 🔧 **Admin Portal** - Complete exam management system
- 📥 **Scraper Integration** - Import exams from external sources
- 🎫 **Voucher Management** - Generate and manage access vouchers
- 📊 **Exam Analytics** - View imported exams and statistics
- 🔄 **App Switching** - Seamlessly switch between admin portal and regular app

## Admin Portal Switching Feature

The app now includes a seamless switching mechanism between the admin portal and the regular student app:

### For Admins
- **Switch to Admin Portal**: Available in Settings → Administration section
- **Admin Button in App Bar**: Quick access button in Library and Stats screens
- **Auth Screen Indicator**: Shows "Admin Mode Active" when logged in as admin

### For Regular Users
- **Switch to App**: Available in Admin Portal app bar (swap icon)
- **Seamless Navigation**: Maintains admin session while using regular app features

### How to Access Admin Portal
1. Go to Settings screen
2. Look for "Administration" section (only visible for authenticated admins)
3. Click "Switch to Admin Portal" or "Admin Portal"
4. Alternatively, use the admin button in the Library or Stats screen app bar

### Default Admin Credentials
- **Email**: `admin@admin.com` or `admin`
- **Password**: `admin123`

## Voucher System

The app includes a comprehensive voucher system for exam access:

### For Admins
- **Generate Vouchers**: Create vouchers in Admin Portal → Vouchers tab
- **Voucher Types**: 
  - General vouchers (unlock all exams)
  - Specific exam vouchers (unlock particular exams)
- **Voucher Management**: Edit, copy, and delete vouchers
- **3-Month Expiry**: All vouchers expire after 3 months

### For Users
- **Voucher Entry**: Access via Settings → Voucher Access
- **Validation**: Real-time voucher code validation
- **Redeem**: One-time use vouchers that unlock exams
- **Library Access**: Unlocked exams appear in the library

### Voucher Features
- ✅ **Secure Generation**: 8-character alphanumeric codes
- ✅ **Validation**: Real-time voucher validation
- ✅ **Expiry Management**: Automatic 3-month expiry
- ✅ **One-Time Use**: Vouchers can only be used once
- ✅ **Exam Linking**: Can link to specific exams or general access
- ✅ **Error Handling**: Comprehensive error handling and user feedback
- ✅ **Copy Function**: Easy voucher code copying
- ✅ **Admin Management**: Full CRUD operations for vouchers

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# ☁️ Cloud Voucher System

## Overview
The cloud voucher system provides a centralized, secure way to manage vouchers and exams using Firebase Firestore. This system ensures that vouchers are validated against the cloud and provides real-time synchronization across devices.

## Features

### 🔐 Enhanced Security
- **Cloud-based validation**: All vouchers are validated against Firebase Firestore
- **Real-time updates**: Changes are reflected immediately across all devices
- **Secure access control**: Firestore security rules protect voucher data
- **One-time use**: Vouchers can only be redeemed once

### 📊 Centralized Management
- **Admin portal**: Complete voucher management interface
- **Statistics dashboard**: Real-time voucher usage analytics
- **Bulk operations**: Generate, edit, and delete vouchers in bulk
- **Cross-device sync**: Vouchers work across all devices and browsers

### 🎯 Smart Fallback Support
- **Cloud-first approach**: Primary validation through Firebase
- **Local fallback**: Graceful degradation if cloud is unavailable
- **Hybrid mode**: Supports both cloud and local vouchers during transition

### 📱 Cross-Device Synchronization
- **Real-time updates**: Changes sync instantly across devices
- **Offline support**: Local caching for offline functionality
- **Browser compatibility**: Works on any device with a web browser

## Technical Implementation

### Firebase Collections

#### `vouchers` Collection
Stores all generated vouchers with the following structure:
```json
{
  "id": "voucher_id",
  "code": "ABC12345",
  "name": "AWS SAA Voucher",
  "examId": "cloud_exam_id",
  "examData": {...}, // Embedded exam data (backward compatibility)
  "examExpiryDuration": 2592000000, // 30 days in milliseconds
  "createdDate": "2024-01-01T00:00:00Z",
  "expiryDate": "2024-04-01T00:00:00Z",
  "isUsed": false,
  "usedBy": null,
  "usedDate": null
}
```

#### `redeemed_vouchers` Collection
Tracks voucher redemptions:
```json
{
  "voucherId": "voucher_id",
  "voucherCode": "ABC12345",
  "userId": "user_123456789",
  "redeemedAt": "2024-01-15T10:30:00Z",
  "examId": "cloud_exam_id",
  "examData": {...}
}
```

#### `exams` Collection
Stores exam data in the cloud:
```json
{
  "id": "exam_id",
  "title": "AWS Solutions Architect Associate",
  "category": "AWS",
  "examCode": "SAA-C03",
  "questionCount": 150,
  "questions": [...],
  "description": "Practice exam for AWS SAA certification",
  "metadata": {
    "difficulty": "intermediate",
    "tags": ["aws", "cloud", "certification"]
  },
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z",
  "version": 1
}
```

### Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Vouchers - read access for authenticated users
    match /vouchers/{voucherId} {
      allow read: if request.auth != null;
      allow write: if false; // Admin only
    }
    
    // Redeemed vouchers - users can create their own redemptions
    match /redeemed_vouchers/{redemptionId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && 
        request.resource.data.userId == request.auth.uid;
      allow update, delete: if false;
    }
    
    // Exams - read access for authenticated users
    match /exams/{examId} {
      allow read: if request.auth != null;
      allow write: if false; // Admin only
    }
  }
}
```

## Cloud Exam System

### Overview
The cloud exam system allows storing and managing exams in Firebase Firestore, providing several advantages over local storage:

### Benefits
- **Centralized storage**: All exams stored in one place
- **Easy updates**: Update exam content without redistributing vouchers
- **Reduced voucher size**: Vouchers only contain exam IDs, not full exam data
- **Version control**: Track exam versions and updates
- **Cross-device access**: Access exams from any device

### How It Works

#### 1. Exam Upload Process
```dart
// Upload exam to cloud
final examId = await CloudExamService.uploadExam(
  title: "AWS SAA Practice Exam",
  category: "AWS",
  examCode: "SAA-C03",
  questions: examQuestions,
  description: "Comprehensive practice exam",
  metadata: {"difficulty": "intermediate"}
);
```

#### 2. Voucher Generation with Cloud Exam
```dart
// Generate voucher linked to cloud exam
final voucher = await FirebaseVoucherService.generateCloudVoucher(
  name: "AWS SAA Voucher",
  examId: cloudExamId, // References cloud exam
  examExpiryDuration: Duration(days: 30)
);
```

#### 3. Voucher Redemption Process
```dart
// When user redeems voucher:
// 1. Validate voucher
final voucher = await FirebaseVoucherService.validateCloudVoucher(code);

// 2. Get exam from cloud
final examData = await FirebaseVoucherService.getExamFromCloud(voucher.examId!);

// 3. Unlock exam for user
await UserExamService.unlockExam(voucher.examId!, examData);
```

### Fallback Strategy
The system uses a multi-tier fallback approach:

1. **Cloud exam first**: Try to get exam from `exams` collection
2. **Embedded data**: If not found, use exam data embedded in voucher
3. **Local storage**: Finally, fall back to local exam storage

## Setup Instructions

### 1. Deploy Firestore Rules
```bash
firebase deploy --only firestore:rules
```

### 2. Enable Firestore
- Go to Firebase Console
- Navigate to Firestore Database
- Create database if not exists
- Choose production or test mode

### 3. Configure Firebase in App
Ensure your `firebase_options.dart` is properly configured with your Firebase project settings.

## Voucher Types

### Cloud Vouchers (Primary)
- **Storage**: Firebase Firestore
- **Validation**: Real-time cloud validation
- **Sync**: Cross-device synchronization
- **Security**: Firestore security rules
- **Admin**: Full management through admin portal

### Local Vouchers (Legacy)
- **Storage**: SharedPreferences
- **Validation**: Local validation only
- **Sync**: Device-specific
- **Security**: Basic local encryption
- **Admin**: Limited management options

## Admin Portal Features

### Statistics Dashboard
- Total vouchers generated
- Active vouchers count
- Redeemed vouchers count
- Real-time updates

### Voucher Operations
- **Generate**: Create new vouchers with exam links
- **View**: List all vouchers with status
- **Edit**: Modify voucher names and details
- **Delete**: Remove vouchers and redemption records
- **Copy**: Copy voucher codes to clipboard
- **Share**: Generate shareable URLs

### Cloud Exam Management
- **Upload**: Store exams in cloud
- **Download**: Retrieve exams from cloud
- **Update**: Modify exam content
- **Delete**: Remove exams from cloud
- **Search**: Find exams by category or criteria

## User Experience

### Voucher Validation Flow
1. User enters voucher code
2. App validates against cloud first
3. If valid, shows voucher details
4. User can redeem voucher
5. Exam is unlocked for user

### Error Handling
- **Network issues**: Graceful fallback to local validation
- **Invalid codes**: Clear error messages
- **Expired vouchers**: Informative expiration notices
- **Already redeemed**: Prevent double redemption

## Security Features

### Access Control
- **Authentication required**: All operations require Firebase Auth
- **User-specific redemptions**: Users can only redeem vouchers once
- **Admin-only operations**: Voucher generation restricted to admins

### Data Protection
- **Encrypted storage**: Sensitive data encrypted at rest
- **Secure transmission**: All data transmitted over HTTPS
- **Audit trail**: All operations logged for security

## Usage Examples

### Generate a Cloud Voucher
```dart
final voucher = await AdminService.generateVoucher(
  name: "AWS SAA Practice Exam",
  examId: "cloud_exam_id",
  examExpiryDuration: Duration(days: 30)
);
```

### Validate and Redeem Voucher
```dart
// Validate voucher
final isValid = await AdminService.validateVoucher("ABC12345");

if (isValid) {
  // Redeem voucher
  final success = await AdminService.useVoucher("ABC12345", userId);
  if (success) {
    // Exam unlocked successfully
  }
}
```

### Get Voucher Statistics
```dart
final stats = await FirebaseVoucherService.getVoucherStats();
print('Total: ${stats['total']}');
print('Redeemed: ${stats['redeemed']}');
print('Active: ${stats['active']}');
```

## Technical Details

### FirebaseVoucherService
Main service for cloud voucher operations:
- `generateCloudVoucher()`: Create new vouchers
- `validateCloudVoucher()`: Validate voucher codes
- `redeemCloudVoucher()`: Mark vouchers as used
- `getAllCloudVouchers()`: Retrieve all vouchers
- `getVoucherStats()`: Get usage statistics

### Voucher Model
```dart
class Voucher {
  final String id;
  final String code;
  final String name;
  final String? examId;
  final Map<String, dynamic>? examData;
  final Duration? examExpiryDuration;
  final DateTime createdDate;
  final DateTime expiryDate;
  final bool isUsed;
  final String? usedBy;
  final DateTime? usedDate;
}
```

## Migration from Local Vouchers

### Step-by-Step Migration
1. **Deploy cloud infrastructure**: Set up Firestore and security rules
2. **Update app**: Deploy new version with cloud support
3. **Generate cloud vouchers**: Create new vouchers in cloud
4. **Test thoroughly**: Ensure cloud vouchers work correctly
5. **Remove local support**: Remove local voucher functionality

### Backward Compatibility
- Existing local vouchers continue to work
- Gradual migration to cloud vouchers
- No data loss during transition

## Analytics and Monitoring

### Voucher Analytics
- **Generation rate**: Vouchers created per day
- **Redemption rate**: Vouchers redeemed per day
- **Popular exams**: Most frequently unlocked exams
- **User patterns**: Redemption behavior analysis

### Performance Metrics
- **Response time**: Cloud validation speed
- **Success rate**: Successful redemptions
- **Error rates**: Failed validations
- **Network usage**: Data transfer statistics

## Troubleshooting

### Common Issues

#### Voucher Not Found
- Check voucher code spelling
- Verify voucher exists in cloud
- Ensure network connectivity

#### Redemption Failed
- Check if voucher already redeemed
- Verify voucher not expired
- Ensure exam data available

#### Cloud Connection Issues
- Check Firebase configuration
- Verify internet connectivity
- Review Firestore security rules

### Debug Information
Enable debug logging to troubleshoot issues:
```dart
// Enable debug mode
FirebaseFirestore.instance.settings = Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

## Future Enhancements

### Planned Features
- **Bulk voucher generation**: Generate multiple vouchers at once
- **Advanced analytics**: Detailed usage reports
- **Email notifications**: Automated voucher delivery
- **QR code support**: Scan vouchers with camera
- **Offline mode**: Enhanced offline functionality

### API Extensions
- **REST API**: External voucher management
- **Webhooks**: Real-time notifications
- **Third-party integrations**: Connect with other systems

---

This cloud voucher system provides a robust, scalable solution for managing exam vouchers with enhanced security, real-time synchronization, and comprehensive admin controls. The system is designed to handle both current needs and future growth while maintaining backward compatibility during the transition period.
