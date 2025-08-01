Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Flutter Web App Deploy Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/5] Cleaning previous build..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to clean build" -ForegroundColor Red
    Read-Host "Press Enter to continue"
    exit 1
}
Write-Host "✓ Clean completed" -ForegroundColor Green
Write-Host ""

Write-Host "[2/5] Getting dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to get dependencies" -ForegroundColor Red
    Read-Host "Press Enter to continue"
    exit 1
}
Write-Host "✓ Dependencies updated" -ForegroundColor Green
Write-Host ""

Write-Host "[3/5] Building web app..." -ForegroundColor Yellow
flutter build web
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to build web app" -ForegroundColor Red
    Read-Host "Press Enter to continue"
    exit 1
}
Write-Host "✓ Web build completed" -ForegroundColor Green
Write-Host ""

Write-Host "[4/5] Deploying to Firebase..." -ForegroundColor Yellow
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to deploy to Firebase" -ForegroundColor Red
    Read-Host "Press Enter to continue"
    exit 1
}
Write-Host "✓ Deployment completed" -ForegroundColor Green
Write-Host ""

Write-Host "[5/5] Deployment successful!" -ForegroundColor Green
Write-Host ""
Write-Host "Your app is now live at:" -ForegroundColor Cyan
Write-Host "https://examtopic-reviewer.web.app" -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to continue" 