# ExamTopic Reviewer - APK Build Script (PowerShell)
Write-Host "🚀 ExamTopic Reviewer - APK Build Script" -ForegroundColor Green
Write-Host ""

# Check if Flutter is available
try {
    $flutterVersion = flutter --version 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter not found"
    }
    Write-Host "✅ Flutter found" -ForegroundColor Green
} catch {
    Write-Host "❌ Flutter is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Flutter and add it to your PATH" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""

# Clean previous builds
Write-Host "🧹 Cleaning previous builds..." -ForegroundColor Cyan
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  Clean command had issues, continuing..." -ForegroundColor Yellow
}

# Get dependencies
Write-Host "📦 Getting dependencies..." -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to get dependencies" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Build APK
Write-Host "🔨 Building APK..." -ForegroundColor Cyan
Write-Host "This may take a few minutes..." -ForegroundColor Yellow
flutter build apk --debug

# Check if build was successful by looking for APK
$apkPath = "android\app\build\outputs\flutter-apk\app-debug.apk"
if (Test-Path $apkPath) {
    Write-Host ""
    Write-Host "✅ APK built successfully!" -ForegroundColor Green
    Write-Host "📁 Location: $apkPath" -ForegroundColor White
    
    # Get file size
    $fileInfo = Get-Item $apkPath
    $sizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
    Write-Host "📊 Size: $sizeMB MB" -ForegroundColor White
    
    Write-Host ""
    Write-Host "🔧 Fixing APK location for Flutter..." -ForegroundColor Cyan
    
    # Create build directory if it doesn't exist
    $flutterApkDir = "build\app\outputs\flutter-apk"
    if (-not (Test-Path $flutterApkDir)) {
        New-Item -ItemType Directory -Path $flutterApkDir -Force | Out-Null
    }
    
    # Copy APK to expected location
    $flutterApkPath = "$flutterApkDir\app-debug.apk"
    Copy-Item $apkPath $flutterApkPath -Force
    Write-Host "✅ APK copied to Flutter's expected location" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "📱 Installation Instructions:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Connect your Android device via USB" -ForegroundColor White
    Write-Host "2. Enable USB debugging on your device" -ForegroundColor White
    Write-Host "3. Run: flutter devices (to verify device is connected)" -ForegroundColor White
    Write-Host "4. Run: flutter install --debug (to install the APK)" -ForegroundColor White
    Write-Host ""
    Write-Host "💡 Alternative: You can manually install the APK from:" -ForegroundColor Cyan
    Write-Host "   $apkPath" -ForegroundColor White
    Write-Host ""
    
    # Check if any Android devices are currently connected
    Write-Host "🔍 Checking for connected devices..." -ForegroundColor Cyan
    $devices = flutter devices
    Write-Host $devices
    
    $androidDevices = $devices | Select-String "android"
    if ($androidDevices) {
        Write-Host ""
        Write-Host "🎉 Android device detected! You can now install the APK." -ForegroundColor Green
        Write-Host "Run: flutter install --debug" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "📱 No Android devices currently connected." -ForegroundColor Yellow
        Write-Host "Connect your device and run: flutter install --debug" -ForegroundColor White
    }
    
} else {
    Write-Host ""
    Write-Host "❌ APK build failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "1. Check for any error messages above" -ForegroundColor White
    Write-Host "2. Run 'flutter doctor' to check for issues" -ForegroundColor White
    Write-Host "3. Make sure all dependencies are properly installed" -ForegroundColor White
    Write-Host "4. Try running 'flutter build apk --debug --verbose' for more details" -ForegroundColor White
    Write-Host ""
}

Write-Host ""
Read-Host "Press Enter to exit" 