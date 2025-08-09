@echo off
echo ExamTopics Scraper
echo ==================

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo Error: Python is not installed or not in PATH
    pause
    exit /b 1
)

REM Check if requirements are installed
echo Checking dependencies...
pip show requests >nul 2>&1
if errorlevel 1 (
    echo Installing dependencies...
    pip install -r scraper_requirements.txt
    if errorlevel 1 (
        echo Error: Failed to install dependencies
        pause
        exit /b 1
    )
)

REM Check if CSV file exists
if not exist "csv\az800_examtopics_links.csv" (
    echo Error: CSV file not found at csv\az800_examtopics_links.csv
    pause
    exit /b 1
)

echo.
echo Available options:
echo 1. Test scraper (first 3 questions)
echo 2. Run basic scraper (all questions)
echo 3. Run advanced scraper (all questions)
echo 4. Run advanced scraper with summary
echo 5. Run advanced scraper (first 10 questions)
echo 6. Custom range scraping
echo.

set /p choice="Enter your choice (1-6): "

if "%choice%"=="1" (
    echo Running test scraper...
    python test_scraper.py
) else if "%choice%"=="2" (
    echo Running basic scraper...
    python examtopics_scraper.py csv\az800_examtopics_links.csv --delay 2.0
) else if "%choice%"=="3" (
    echo Running advanced scraper...
    python advanced_examtopics_scraper.py csv\az800_examtopics_links.csv --delay 2.0
) else if "%choice%"=="4" (
    echo Running advanced scraper with summary...
    python advanced_examtopics_scraper.py csv\az800_examtopics_links.csv --delay 2.0 --summary
) else if "%choice%"=="5" (
    echo Running advanced scraper (first 10 questions)...
    python advanced_examtopics_scraper.py csv\az800_examtopics_links.csv --delay 2.0 --end 10
) else if "%choice%"=="6" (
    set /p start="Enter start index: "
    set /p end="Enter end index: "
    echo Running advanced scraper (questions %start%-%end%)...
    python advanced_examtopics_scraper.py csv\az800_examtopics_links.csv --delay 2.0 --start %start% --end %end%
) else (
    echo Invalid choice
    pause
    exit /b 1
)

echo.
echo Scraping completed!
echo Check the generated files for results.
pause 