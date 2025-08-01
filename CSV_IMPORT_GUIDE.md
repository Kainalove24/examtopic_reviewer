# CSV Import Guide - Enhanced with Base64 Image Conversion

## Overview

The CSV import feature has been enhanced to support both scraper format and custom format CSV files, with automatic conversion of image URLs to Base64 for offline viewing.

## Supported Formats

### 1. Scraper Format (Recommended)
This format matches the output from the ExamTopics scraper:

```csv
id,type,text,question_images,answer_images,options,answers,explanation
1,mcq,"What is the capital of France?",,,A. Paris|B. London|C. Berlin|D. Madrid,A,Paris is the capital of France
2,hotspot,"HOTSPOT - Select the correct answer",https://img.examtopics.com/image1.png,https://img.examtopics.com/image2.png,Option A|Option B|Option C|Option D,A|B,Explanation here
```

**Columns:**
- `id`: Question ID (optional, auto-generated if missing)
- `type`: Question type (mcq, hotspot, etc.)
- `text`: Question text
- `question_images`: Image URLs separated by `|` (will be converted to Base64)
- `answer_images`: Answer image URLs separated by `|` (will be converted to Base64)
- `options`: Answer options separated by `|`
- `answers`: Correct answers separated by `|`
- `explanation`: Explanation text (optional)

### 2. Custom Format
Traditional format for manual CSV creation:

```csv
question,option_a,option_b,option_c,option_d,correct_answer,explanation,image_url,base64_image
"What is the capital of France?",Paris,London,Berlin,Madrid,A,Paris is the capital of France,https://example.com/image.jpg,
```

**Columns:**
- `question`: Question text
- `option_a`, `option_b`, `option_c`, `option_d`: Answer options
- `correct_answer`: Correct answer (A, B, C, or D)
- `explanation`: Explanation text (optional)
- `image_url`: Image URL (will be converted to Base64)
- `base64_image`: Pre-encoded Base64 image data

## Image Processing Features

### Automatic Base64 Conversion
- **HTTP URLs**: Automatically downloaded and converted to Base64
- **Data URIs**: Already Base64 encoded, used as-is
- **Local files**: Used as-is (for local development)
- **Failed conversions**: Original URL preserved as fallback

### Supported Image Formats
- PNG, JPEG, GIF, WebP
- Automatic MIME type detection
- Size optimization for mobile viewing

### Conversion Process
1. **Detection**: Identifies image URLs in CSV
2. **Download**: Fetches images from URLs
3. **Encoding**: Converts to Base64 with proper MIME type
4. **Storage**: Embeds Base64 data in question objects
5. **Fallback**: Preserves original URL if conversion fails

## Usage Instructions

### 1. Access CSV Import
1. Navigate to Admin Portal
2. Go to "Exams" tab
3. Scroll to "CSV Import" section

### 2. Import Process
1. **Pick CSV File**: Click "Pick CSV File" button
2. **Validation**: System automatically detects format and validates
3. **Image Processing**: Images are converted to Base64 (may take time)
4. **Review Results**: Check validation results and image conversions
5. **Import**: Click "Import Questions" to save to exam storage

### 3. Status Indicators
- **Processing**: Shows progress during file parsing and image conversion
- **Format Detection**: Displays detected format (scraper/custom)
- **Image Conversions**: Lists successful and failed image conversions
- **Validation Errors**: Shows any parsing errors

## Example: Importing aws_mla_c01.csv

The `aws_mla_c01.csv` file contains:
- **Format**: Scraper format
- **Images**: 20+ image URLs from ExamTopics
- **Questions**: 114 AWS Machine Learning questions

**Import Process:**
1. Select the CSV file
2. System detects scraper format
3. Downloads and converts all image URLs to Base64
4. Shows conversion status for each image
5. Imports questions with embedded Base64 images

**Result:**
- All images converted to Base64 for offline viewing
- Questions work without internet connection
- Faster image loading in the app

## Error Handling

### Common Issues
1. **Invalid CSV Format**: Check column headers match supported formats
2. **Image Download Failures**: Network issues or invalid URLs
3. **Large Files**: Very large images may timeout
4. **Memory Issues**: Too many large images at once

### Troubleshooting
- **Format Errors**: Ensure CSV headers match exactly
- **Image Failures**: Check URL accessibility and format
- **Timeout Issues**: Break large imports into smaller files
- **Memory Issues**: Process fewer images per import

## Best Practices

### For Scraper Output
1. Use scraper format directly from ExamTopics scraper
2. Images are automatically converted to Base64
3. No manual processing required

### For Custom CSVs
1. Follow the custom format structure
2. Use image_url column for external images
3. Use base64_image column for pre-encoded images

### Performance Tips
1. **Batch Processing**: Import smaller files for better performance
2. **Image Optimization**: Use compressed images before import
3. **Network Stability**: Ensure stable connection for image downloads
4. **Memory Management**: Monitor app memory during large imports

## Technical Details

### Base64 Conversion Process
```dart
// Example conversion flow
1. Detect image URL: "https://img.examtopics.com/image1.png"
2. Download image bytes via HTTP
3. Detect MIME type: "image/png"
4. Encode to Base64: "iVBORw0KGgoAAAANSUhEUgAA..."
5. Create data URI: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA..."
6. Store in question object
```

### Error Recovery
- Failed downloads preserve original URL
- Network timeouts retry once
- Invalid images skip conversion
- Memory errors show warning

### Storage Format
```json
{
  "id": 1,
  "type": "mcq",
  "text": "Question text",
  "questionImages": [
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA..."
  ],
  "answerImages": [],
  "options": ["A", "B", "C", "D"],
  "answers": ["A"],
  "explanation": "Explanation text"
}
```

## Migration from Old Format

If you have existing CSV files in the old format:
1. **No Action Required**: System automatically detects format
2. **Backward Compatible**: Old format still supported
3. **Enhanced Features**: New format adds image conversion

## Future Enhancements

- **Batch Image Processing**: Process multiple images in parallel
- **Image Compression**: Automatic compression for large images
- **Caching**: Cache converted images for reuse
- **Progress Tracking**: Real-time progress for large imports
- **Resume Support**: Resume interrupted imports

---

**Note**: The enhanced CSV import system provides seamless integration with the ExamTopics scraper output while maintaining compatibility with custom CSV formats. All images are automatically converted to Base64 for optimal offline viewing experience. 