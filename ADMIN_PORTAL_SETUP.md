# Admin Portal & Voucher System Setup Guide 🎯

This guide explains how to set up and use the integrated admin portal with scraper integration and voucher system.

## 🚀 **Quick Start**

### **Step 1: Start the Python Scraper API Server**

```bash
# Navigate to the scraper directory
cd scraper

# Install dependencies
pip install -r requirements.txt

# Start the API server
python api_server.py
```

The server will start on `http://localhost:5000` and provide these endpoints:
- `GET /api/health` - Health check
- `GET /api/categories` - List available categories
- `GET /api/exams/<category>` - List exams for category
- `POST /api/scrape` - Start scraping job
- `GET /api/job/<job_id>` - Get job status
- `GET /api/jobs` - List all jobs
- `GET /api/download/<job_id>` - Download CSV
- `DELETE /api/cleanup/<job_id>` - Clean up job

### **Step 2: Run the Flutter App**

```bash
# In the main project directory
flutter pub get
flutter run
```

### **Step 3: Access Admin Portal**

1. Open the Flutter app
2. Go to **Settings** → **Administration** → **Admin Portal**
3. The admin portal has 3 tabs:
   - **Scraper**: Import exams from ExamTopics
   - **Vouchers**: Generate and manage vouchers
   - **Exams**: View and manage imported exams

## 📱 **Admin Portal Features**

### **🔧 Scraper Tab**
- **Connection Status**: Shows if connected to Python scraper API
- **Category Selection**: Choose from available exam categories (AWS, Microsoft, etc.)
- **Exam Selection**: Select specific exam codes
- **Start Scraping**: Begin the scraping process
- **Import Exam**: Add scraped questions to the app
- **Progress Tracking**: Real-time progress updates
- **Results Preview**: View scraped questions before importing

### **🎫 Vouchers Tab**
- **Generate Voucher**: Create new voucher codes (8 characters, alphanumeric)
- **Voucher List**: View all generated vouchers with status
- **Voucher Details**: 
  - Creation date
  - Expiry date (3 months from creation)
  - Usage status (Active/Used/Expired)
  - Used by (if applicable)

### **📚 Exams Tab**
- **Imported Exams**: List all exams imported via scraper
- **Exam Details**: Category, code, question count, import date
- **Delete Exam**: Remove exams from the system

## 👥 **User Experience Flow**

### **For Users (Voucher Holders)**
1. **Enter Voucher**: Go to Settings → Administration → Enter Voucher
2. **Validate Code**: Enter 8-character voucher code
3. **Redeem Voucher**: One-time use, expires after 3 months
4. **Access Exams**: Browse available exams
5. **Start Studying**: Begin quiz mode with imported questions

### **For Administrators**
1. **Start Scraper**: Run Python API server
2. **Access Admin Portal**: Settings → Administration → Admin Portal
3. **Import Exams**: Use scraper to import exam questions
4. **Generate Vouchers**: Create voucher codes for users
5. **Manage Content**: View and delete imported exams

## 🔧 **Technical Architecture**

### **Components**
- **Python Scraper API**: Flask server with ExamTopics scraper
- **Flutter Admin Portal**: UI for managing exams and vouchers
- **Voucher System**: Local storage with SharedPreferences
- **Exam Management**: Import/export exam data
- **User Interface**: Voucher entry and exam selection screens

### **Data Flow**
```
Python Scraper → Flask API → Flutter App → Local Storage
     ↓              ↓           ↓           ↓
ExamTopics → CSV Data → Admin Portal → User Access
```

### **Storage**
- **Vouchers**: Stored in SharedPreferences with JSON serialization
- **Exams**: Stored in SharedPreferences with question data
- **Progress**: Existing progress system maintained

## 🛠 **Configuration**

### **Python Dependencies**
```txt
requests>=2.28.0
beautifulsoup4>=4.11.0
lxml>=4.9.0
pandas>=1.5.0
flask>=2.3.0
flask-cors>=4.0.0
```

### **Flutter Dependencies**
```yaml
http: ^1.2.0
shared_preferences: ^2.2.2
```

## 🔒 **Security Features**

### **Voucher System**
- **Unique Codes**: 8-character alphanumeric codes
- **One-time Use**: Vouchers can only be used once
- **Expiry**: 3-month validity period
- **Validation**: Real-time voucher validation
- **Usage Tracking**: Track who used which voucher

### **Admin Access**
- **Local Access**: Admin portal accessible through settings
- **No Authentication**: Simple access for demo purposes
- **Data Isolation**: Voucher and exam data stored locally

## 📊 **Usage Examples**

### **Importing an AWS Exam**
1. Start Python scraper API
2. Open Flutter app → Settings → Admin Portal
3. Select "amazon" category
4. Select "mla-c01" exam
5. Click "Start Scraping"
6. Wait for completion (progress bar)
7. Click "Import Exam"
8. Generate vouchers for users

### **Generating Vouchers**
1. Go to Vouchers tab in Admin Portal
2. Click "Generate New Voucher"
3. Copy the generated code (e.g., "ABC12345")
4. Share with users
5. Monitor usage in voucher list

### **User Redemption**
1. User opens app → Settings → Enter Voucher
2. Enters voucher code
3. Clicks "Validate Voucher"
4. Clicks "Redeem Voucher"
5. Accesses available exams
6. Starts studying

## 🚨 **Troubleshooting**

### **Common Issues**

**Python Scraper Not Connecting**
- Check if `python api_server.py` is running
- Verify port 5000 is not blocked
- Check firewall settings

**Voucher Not Working**
- Ensure voucher code is exactly 8 characters
- Check if voucher is expired (3 months)
- Verify voucher hasn't been used before

**No Exams Available**
- Import exams through admin portal first
- Check if scraper API is connected
- Verify exam data was imported successfully

**Flutter App Errors**
- Run `flutter pub get` to install dependencies
- Check console for error messages
- Restart the app if needed

## 🔄 **Maintenance**

### **Regular Tasks**
- **Monitor Vouchers**: Check for expired vouchers
- **Update Exams**: Import new exam versions
- **Backup Data**: Export voucher and exam data
- **Clean Up**: Remove old/expired data

### **Data Management**
- **Export Vouchers**: Save voucher data for backup
- **Import Exams**: Add new exam content
- **User Analytics**: Track voucher usage patterns
- **Content Updates**: Refresh exam questions

## 📈 **Future Enhancements**

### **Planned Features**
- **User Authentication**: Secure admin access
- **Cloud Storage**: Store data in Firebase
- **Analytics Dashboard**: Usage statistics
- **Bulk Operations**: Import multiple exams
- **Auto-updates**: Automatic exam updates
- **User Management**: Track individual users

### **Advanced Features**
- **Real-time Sync**: Live data synchronization
- **Offline Mode**: Work without internet
- **Multi-language**: Internationalization
- **Advanced Analytics**: Detailed usage reports
- **API Integration**: Connect to external services

---

## 🎉 **Success!**

You now have a complete admin portal with:
- ✅ **Integrated Scraper**: Python API + Flutter UI
- ✅ **Voucher System**: Generate and redeem codes
- ✅ **Exam Management**: Import and manage content
- ✅ **User Access**: Simple voucher-based access
- ✅ **Admin Controls**: Full management interface

The system is ready for production use! 🚀 