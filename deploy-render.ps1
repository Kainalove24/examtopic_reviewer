# Render Deployment Script
Write-Host "🚀 Render Deployment Script" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green
Write-Host ""

Write-Host "📋 Checking prerequisites..." -ForegroundColor Yellow

# Check if git is available
try {
    $gitVersion = git --version
    Write-Host "✅ Git is available: $gitVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Git is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Git from: https://git-scm.com/" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Check if we're in a git repository
try {
    git status | Out-Null
    Write-Host "✅ In git repository" -ForegroundColor Green
} catch {
    Write-Host "❌ Not in a git repository" -ForegroundColor Red
    Write-Host "Please navigate to your project directory" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "🔄 Checking for changes..." -ForegroundColor Yellow
$changes = git status --porcelain
if ($changes) {
    Write-Host "📤 Pushing changes to GitHub..." -ForegroundColor Yellow
    git add .
    git commit -m "Update for Render deployment"
    git push
    Write-Host "✅ Changes pushed to GitHub" -ForegroundColor Green
} else {
    Write-Host "✅ No changes to push" -ForegroundColor Green
}

Write-Host ""
Write-Host "🎯 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Go to https://render.com" -ForegroundColor White
Write-Host "2. Sign up/Login with GitHub" -ForegroundColor White
Write-Host "3. Click 'New +' → 'Blueprint'" -ForegroundColor White
Write-Host "4. Select your repository: examtopic_reviewer" -ForegroundColor White
Write-Host "5. Click 'Apply' to deploy" -ForegroundColor White
Write-Host ""
Write-Host "📖 For detailed instructions, see: RENDER_DEPLOYMENT.md" -ForegroundColor Yellow
Write-Host ""
Write-Host "🚀 Your API will be available at: https://your-app-name.onrender.com" -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to continue" 