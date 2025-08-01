Write-Host "🚀 Deploying Image Processing Server to Render..." -ForegroundColor Green
Write-Host ""

# Check if render CLI is installed
try {
    $null = render --version
} catch {
    Write-Host "❌ Render CLI not found. Please install it first:" -ForegroundColor Red
    Write-Host "   https://render.com/docs/install-cli" -ForegroundColor Yellow
    Read-Host "Press Enter to continue"
    exit 1
}

Write-Host "📦 Building and deploying to Render..." -ForegroundColor Cyan
render deploy

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Deployment successful!" -ForegroundColor Green
    Write-Host "🌐 Your image processing server should be available at:" -ForegroundColor Cyan
    Write-Host "   https://image-processing-server.onrender.com" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📋 API Endpoints:" -ForegroundColor Cyan
    Write-Host "   GET  / - Home page" -ForegroundColor White
    Write-Host "   POST /api/process-images - Process image URLs" -ForegroundColor White
    Write-Host "   GET  /api/images/<filename> - Serve processed images" -ForegroundColor White
    Write-Host "   GET  /api/health - Health check" -ForegroundColor White
    Write-Host "   GET  /api/stats - Server statistics" -ForegroundColor White
} else {
    Write-Host "❌ Deployment failed. Please check the logs above." -ForegroundColor Red
}

Read-Host "Press Enter to continue" 