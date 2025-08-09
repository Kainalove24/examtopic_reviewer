#!/usr/bin/env pwsh
<#
.SYNOPSIS
    ExamTopics Scraper Runner
.DESCRIPTION
    A PowerShell script to run the ExamTopics scraper with various options
.PARAMETER Test
    Run test scraper with first 3 questions
.PARAMETER Basic
    Run basic scraper for all questions
.PARAMETER Advanced
    Run advanced scraper for all questions
.PARAMETER Summary
    Run advanced scraper with summary report
.PARAMETER Range
    Run advanced scraper for specific range
.PARAMETER Start
    Start index for range scraping
.PARAMETER End
    End index for range scraping
.PARAMETER Delay
    Delay between requests in seconds (default: 2.0)
#>

param(
    [switch]$Test,
    [switch]$Basic,
    [switch]$Advanced,
    [switch]$Summary,
    [switch]$Range,
    [int]$Start = 0,
    [int]$End = 10,
    [double]$Delay = 2.0
)

Write-Host "ExamTopics Scraper" -ForegroundColor Green
Write-Host "==================" -ForegroundColor Green

# Check if Python is installed
try {
    $pythonVersion = python --version 2>&1
    Write-Host "Python found: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "Error: Python is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

# Check if requirements are installed
Write-Host "Checking dependencies..." -ForegroundColor Yellow
try {
    $requestsInstalled = pip show requests 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Installing dependencies..." -ForegroundColor Yellow
        pip install -r scraper_requirements.txt
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error: Failed to install dependencies" -ForegroundColor Red
            exit 1
        }
    }
} catch {
    Write-Host "Error checking dependencies" -ForegroundColor Red
    exit 1
}

# Check if CSV file exists
$csvFile = "csv/az800_examtopics_links.csv"
if (-not (Test-Path $csvFile)) {
    Write-Host "Error: CSV file not found at $csvFile" -ForegroundColor Red
    exit 1
}

# Function to run scraper
function Run-Scraper {
    param(
        [string]$Command,
        [string]$Description
    )
    
    Write-Host "Running $Description..." -ForegroundColor Cyan
    Write-Host "Command: $Command" -ForegroundColor Gray
    
    try {
        Invoke-Expression $Command
        if ($LASTEXITCODE -eq 0) {
            Write-Host "$Description completed successfully!" -ForegroundColor Green
        } else {
            Write-Host "$Description failed with exit code $LASTEXITCODE" -ForegroundColor Red
        }
    } catch {
        Write-Host "Error running $Description : $_" -ForegroundColor Red
    }
}

# Determine which scraper to run based on parameters
if ($Test) {
    Run-Scraper "python test_scraper.py" "Test scraper"
} elseif ($Basic) {
    Run-Scraper "python examtopics_scraper.py $csvFile --delay $Delay" "Basic scraper"
} elseif ($Advanced) {
    Run-Scraper "python advanced_examtopics_scraper.py $csvFile --delay $Delay" "Advanced scraper"
} elseif ($Summary) {
    Run-Scraper "python advanced_examtopics_scraper.py $csvFile --delay $Delay --summary" "Advanced scraper with summary"
} elseif ($Range) {
    Run-Scraper "python advanced_examtopics_scraper.py $csvFile --delay $Delay --start $Start --end $End" "Advanced scraper (range $Start-$End)"
} else {
    # Interactive mode
    Write-Host ""
    Write-Host "Available options:" -ForegroundColor Yellow
    Write-Host "1. Test scraper (first 3 questions)"
    Write-Host "2. Run basic scraper (all questions)"
    Write-Host "3. Run advanced scraper (all questions)"
    Write-Host "4. Run advanced scraper with summary"
    Write-Host "5. Run advanced scraper (first 10 questions)"
    Write-Host "6. Custom range scraping"
    Write-Host ""
    
    $choice = Read-Host "Enter your choice (1-6)"
    
    switch ($choice) {
        "1" { Run-Scraper "python test_scraper.py" "Test scraper" }
        "2" { Run-Scraper "python examtopics_scraper.py $csvFile --delay $Delay" "Basic scraper" }
        "3" { Run-Scraper "python advanced_examtopics_scraper.py $csvFile --delay $Delay" "Advanced scraper" }
        "4" { Run-Scraper "python advanced_examtopics_scraper.py $csvFile --delay $Delay --summary" "Advanced scraper with summary" }
        "5" { Run-Scraper "python advanced_examtopics_scraper.py $csvFile --delay $Delay --end 10" "Advanced scraper (first 10)" }
        "6" {
            $customStart = Read-Host "Enter start index"
            $customEnd = Read-Host "Enter end index"
            Run-Scraper "python advanced_examtopics_scraper.py $csvFile --delay $Delay --start $customStart --end $customEnd" "Advanced scraper (range $customStart-$customEnd)"
        }
        default { Write-Host "Invalid choice" -ForegroundColor Red; exit 1 }
    }
}

Write-Host ""
Write-Host "Scraping completed!" -ForegroundColor Green
Write-Host "Check the generated files for results." -ForegroundColor Yellow

# List generated files
$generatedFiles = @(
    "*.json",
    "*.csv",
    "scraper.log",
    "advanced_scraper.log",
    "summary_report_*.json"
)

Write-Host ""
Write-Host "Generated files:" -ForegroundColor Cyan
foreach ($pattern in $generatedFiles) {
    $files = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        Write-Host "  - $($file.Name)" -ForegroundColor Gray
    }
} 