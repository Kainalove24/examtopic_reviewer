# ExamTopic Reviewer - Build and Install Script
Write-Host "🚀 Building and Installing ExamTopic Reviewer APK..." -ForegroundColor Green
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

# Check for connected devices
Write-Host "📱 Checking for connected devices..." -ForegroundColor Cyan
$devices = flutter devices
Write-Host $devices

# Check if any Android devices are connected
$androidDevices = $devices | Select-String "android"
if (-not $androidDevices) {
    Write-Host "❌ No Android devices found!" -ForegroundColor Red
    Write-Host "💡 Please connect your Android device and enable USB debugging" -ForegroundColor Yellow
    Write-Host "   Settings > Developer options > USB debugging" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Build and install APK
Write-Host "🔨 Building and installing APK..." -ForegroundColor Cyan
Write-Host "This may take a few minutes..." -ForegroundColor Yellow

flutter install --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Release build failed! Trying debug build..." -ForegroundColor Yellow
    flutter install --debug
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Debug build also failed!" -ForegroundColor Red
        Write-Host ""
        Write-Host "💡 Troubleshooting tips:" -ForegroundColor Yellow
        Write-Host "1. Make sure your Android device is connected and USB debugging is enabled" -ForegroundColor White
        Write-Host "2. Run 'flutter doctor' to check for issues" -ForegroundColor White
        Write-Host "3. Try 'flutter run' to see detailed error messages" -ForegroundColor White
        Write-Host "4. Check if your device has enough storage space" -ForegroundColor White
        Read-Host "Press Enter to exit"
        exit 1
    }
}

Write-Host ""
Write-Host "✅ APK built and installed successfully!" -ForegroundColor Green
Write-Host "🎉 Your app should now be running on your device" -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to exit" 