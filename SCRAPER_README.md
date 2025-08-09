# ExamTopics Scraper

A comprehensive Python scraping solution for extracting exam questions and data from ExamTopics.com links stored in CSV files.

## Features

- **Dual Scraper Options**: Basic and Advanced scrapers with different capabilities
- **Robust Error Handling**: Retry logic and graceful failure handling
- **Rate Limiting**: Respectful scraping with configurable delays
- **Multiple Output Formats**: JSON and CSV export options
- **Progress Tracking**: Real-time progress updates and periodic saves
- **Comprehensive Logging**: Detailed logs for debugging and monitoring
- **Range Scraping**: Ability to scrape specific ranges of questions
- **Summary Reports**: Generate detailed reports of scraping results

## Files Overview

### Core Scrapers
- `examtopics_scraper.py` - Basic scraper with essential functionality
- `advanced_examtopics_scraper.py` - Advanced scraper with enhanced features
- `test_scraper.py` - Test script to verify scraper functionality

### Configuration
- `scraper_requirements.txt` - Python dependencies for the scrapers
- `SCRAPER_README.md` - This documentation file

## Installation

1. **Install Python Dependencies**:
   ```bash
   pip install -r scraper_requirements.txt
   ```

2. **Verify Installation**:
   ```bash
   python test_scraper.py
   ```

## Usage

### Basic Scraper

```bash
# Scrape all questions from CSV file
python examtopics_scraper.py csv/az800_examtopics_links.csv

# Scrape with custom output file
python examtopics_scraper.py csv/az800_examtopics_links.csv --output my_questions.json

# Scrape with CSV output
python examtopics_scraper.py csv/az800_examtopics_links.csv --csv-output my_questions.csv

# Scrape with custom delay and retries
python examtopics_scraper.py csv/az800_examtopics_links.csv --delay 3.0 --retries 5
```

### Advanced Scraper

```bash
# Scrape all questions with advanced features
python advanced_examtopics_scraper.py csv/az800_examtopics_links.csv

# Scrape specific range of questions (first 10)
python advanced_examtopics_scraper.py csv/az800_examtopics_links.csv --start 0 --end 10

# Scrape with summary report
python advanced_examtopics_scraper.py csv/az800_examtopics_links.csv --summary

# Scrape with both JSON and CSV output
python advanced_examtopics_scraper.py csv/az800_examtopics_links.csv --output questions.json --csv-output questions.csv
```

## Command Line Options

### Basic Scraper Options
- `csv_file` - Path to CSV file containing links (required)
- `--output, -o` - Output JSON file name
- `--csv-output` - Output CSV file name
- `--delay` - Delay between requests in seconds (default: 1.0)
- `--retries` - Maximum retry attempts (default: 3)

### Advanced Scraper Options
- `csv_file` - Path to CSV file containing links (required)
- `--output, -o` - Output JSON file name
- `--csv-output` - Output CSV file name
- `--delay` - Delay between requests in seconds (default: 2.0)
- `--retries` - Maximum retry attempts (default: 3)
- `--start` - Start index for scraping range (default: 0)
- `--end` - End index for scraping range
- `--summary` - Generate summary report

## CSV File Format

The scraper expects a CSV file with the following columns:
- `Topic` - Topic number or category
- `Question` - Question number
- `Link` - Full URL to the exam question page

Example:
```csv
Topic,Question,Link
1,1,https://www.examtopics.com/discussions/microsoft/view/74986-exam-az-800-topic-1-question-1-discussion/
1,2,https://www.examtopics.com/discussions/microsoft/view/75085-exam-az-800-topic-1-question-2-discussion/
```

## Output Formats

### JSON Output
The scrapers save data in JSON format with the following structure:

```json
[
  {
    "topic": "1",
    "question_number": "1",
    "url": "https://www.examtopics.com/...",
    "question_text": "What is the correct answer?",
    "options": ["A. Option 1", "B. Option 2", "C. Option 3"],
    "correct_answer": "The correct answer is B",
    "explanation": "Detailed explanation...",
    "images": ["https://example.com/image1.jpg"],
    "difficulty": "",
    "tags": [],
    "discussion_comments": [],
    "vote_count": 0,
    "is_premium": false
  }
]
```

### CSV Output
CSV format with pipe-separated values for arrays:
```csv
topic,question_number,url,question_text,options,correct_answer,explanation,images,difficulty,tags,vote_count,is_premium
1,1,https://...,What is the correct answer?,A. Option 1|B. Option 2|C. Option 3,The correct answer is B,Detailed explanation...,https://example.com/image1.jpg,,,0,false
```

## Advanced Features

### Summary Reports
The advanced scraper can generate detailed summary reports:

```bash
python advanced_examtopics_scraper.py csv/az800_examtopics_links.csv --summary
```

This generates a report with:
- Total questions scraped
- Success rates for different data types
- Topic distribution
- Premium content detection

### Range Scraping
Scrape specific ranges of questions:

```bash
# Scrape questions 10-20
python advanced_examtopics_scraper.py csv/az800_examtopics_links.csv --start 10 --end 20

# Scrape first 50 questions
python advanced_examtopics_scraper.py csv/az800_examtopics_links.csv --end 50
```

### Progress Saving
Both scrapers automatically save progress every 5-10 questions to prevent data loss.

## Error Handling

The scrapers include robust error handling:
- **Network Errors**: Automatic retry with exponential backoff
- **Invalid Pages**: Skip pages that return errors or invalid content
- **Rate Limiting**: Configurable delays to respect server limits
- **Data Validation**: Checks for valid HTML responses

## Logging

All scrapers generate detailed logs:
- `scraper.log` - Basic scraper logs
- `advanced_scraper.log` - Advanced scraper logs
- Console output with real-time progress

## Best Practices

1. **Start Small**: Test with a few questions first
2. **Respect Rate Limits**: Use appropriate delays (2-3 seconds recommended)
3. **Monitor Progress**: Check logs for any issues
4. **Backup Data**: Progress files are saved automatically
5. **Test First**: Use `test_scraper.py` to verify functionality

## Troubleshooting

### Common Issues

1. **CSV File Not Found**
   - Ensure the CSV file path is correct
   - Check file permissions

2. **Network Errors**
   - Increase delay between requests
   - Check internet connection
   - Verify URLs are accessible

3. **No Data Extracted**
   - The website structure may have changed
   - Check if content requires login
   - Verify the page contains the expected data

4. **Memory Issues**
   - Use range scraping for large datasets
   - Process in smaller batches

### Debug Mode
For detailed debugging, modify the logging level in the scraper files:

```python
logging.basicConfig(level=logging.DEBUG)
```

## Legal and Ethical Considerations

- **Respect robots.txt**: Check the website's robots.txt file
- **Rate Limiting**: Use appropriate delays to avoid overwhelming the server
- **Terms of Service**: Ensure scraping complies with the website's terms
- **Data Usage**: Use scraped data responsibly and in accordance with applicable laws

## Support

For issues or questions:
1. Check the logs for error messages
2. Test with a small sample first
3. Verify the CSV file format
4. Ensure all dependencies are installed

## Example Workflow

1. **Prepare CSV file** with exam topic links
2. **Test the scraper** with a few questions:
   ```bash
   python test_scraper.py
   ```
3. **Run full scraping** with appropriate settings:
   ```bash
   python advanced_examtopics_scraper.py csv/az800_examtopics_links.csv --delay 2.0 --summary
   ```
4. **Check results** in the generated JSON/CSV files
5. **Review summary report** for success rates and statistics 