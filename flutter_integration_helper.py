#!/usr/bin/env python3
"""
Flutter Integration Helper
Assists with integrating converted CSV files into the Flutter exam reviewer app.
"""

import os
import shutil
import json
from pathlib import Path

class FlutterIntegrationHelper:
    def __init__(self):
        self.flutter_csv_dir = "csv"
        self.flutter_assets_dir = "assets/csv"
    
    def copy_to_flutter_project(self, csv_file: str, exam_name: str = None) -> str:
        """
        Copy the converted CSV file to the Flutter project's csv directory.
        
        Args:
            csv_file: Path to the converted CSV file
            exam_name: Optional custom name for the exam
            
        Returns:
            Path to the copied file in the Flutter project
        """
        if not os.path.exists(csv_file):
            raise FileNotFoundError(f"CSV file not found: {csv_file}")
        
        # Create exam name from filename if not provided
        if not exam_name:
            base_name = os.path.splitext(os.path.basename(csv_file))[0]
            exam_name = base_name.replace('_flutter_compatible', '')
        
        # Create the destination filename
        dest_filename = f"{exam_name}.csv"
        dest_path = os.path.join(self.flutter_csv_dir, dest_filename)
        
        # Ensure the csv directory exists
        os.makedirs(self.flutter_csv_dir, exist_ok=True)
        
        # Copy the file
        shutil.copy2(csv_file, dest_path)
        
        print(f"✅ Copied {csv_file} to {dest_path}")
        return dest_path
    
    def create_flutter_import_code(self, csv_file: str, exam_name: str = None) -> str:
        """
        Generate Flutter code to import the CSV file.
        
        Args:
            csv_file: Path to the CSV file
            exam_name: Optional custom name for the exam
            
        Returns:
            Flutter code snippet for importing the exam
        """
        if not exam_name:
            base_name = os.path.splitext(os.path.basename(csv_file))[0]
            exam_name = base_name.replace('_flutter_compatible', '')
        
        flutter_code = f"""
// Generated Flutter code for importing {exam_name}
// Add this to your Flutter app

import 'package:flutter/services.dart';
import '../models/exam_question.dart';
import '../utils/csv_question_parser.dart';

class {exam_name.replace('-', '_').replace('_', '').title()}Exam {{
  static Future<List<ExamQuestion>> loadQuestions() async {{
    try {{
      final csvString = await rootBundle.loadString('csv/{exam_name}.csv');
      final questions = parseQuestionsFromCsv(csvString);
      
      return questions.map((q) => ExamQuestion(
        id: q.id,
        type: q.type,
        text: q.text,
        questionImages: q.questionImages,
        answerImages: q.answerImages,
        options: q.choices.map((c) => c.text).toList(),
        answers: q.type == 'hotspot'
            ? q.correctIndices.map((i) => q.choices[i].text).toList()
            : q.correctIndices.map((i) => i.toString()).toList(),
        explanation: null,
      )).toList();
    }} catch (e) {{
      print('Error loading {exam_name} questions: $e');
      return [];
    }}
  }}
}}

// Usage in your app:
// final questions = await {exam_name.replace('-', '_').replace('_', '').title()}Exam.loadQuestions();
"""
        
        return flutter_code
    
    def create_pubspec_yaml_entry(self, csv_file: str) -> str:
        """
        Generate pubspec.yaml entry for the CSV file.
        
        Args:
            csv_file: Path to the CSV file
            
        Returns:
            pubspec.yaml entry
        """
        filename = os.path.basename(csv_file)
        
        pubspec_entry = f"""
  # Add this to your pubspec.yaml under the assets section:
  - csv/{filename}
"""
        
        return pubspec_entry
    
    def validate_flutter_compatibility(self, csv_file: str) -> dict:
        """
        Validate that the CSV file is compatible with Flutter app requirements.
        
        Args:
            csv_file: Path to the CSV file
            
        Returns:
            Validation results
        """
        import csv
        
        results = {
            'valid': True,
            'issues': [],
            'question_count': 0,
            'supported_types': 0,
            'unsupported_types': 0
        }
        
        try:
            with open(csv_file, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                questions = list(reader)
            
            results['question_count'] = len(questions)
            
            # Check required fields
            required_fields = ['id', 'type', 'text', 'options', 'answers']
            for i, question in enumerate(questions):
                for field in required_fields:
                    if field not in question or not question[field]:
                        results['issues'].append(f"Question {i+1}: Missing or empty {field}")
                        results['valid'] = False
                
                # Check question type
                question_type = question.get('type', '').lower()
                if question_type in ['multiple_choice', 'hotspot']:
                    results['supported_types'] += 1
                else:
                    results['unsupported_types'] += 1
                    results['issues'].append(f"Question {i+1}: Unsupported type '{question_type}'")
            
            # Check for common issues
            if results['question_count'] == 0:
                results['issues'].append("No questions found in CSV file")
                results['valid'] = False
            
            if results['unsupported_types'] > 0:
                results['issues'].append(f"Found {results['unsupported_types']} questions with unsupported types")
            
        except Exception as e:
            results['issues'].append(f"Error reading CSV file: {e}")
            results['valid'] = False
        
        return results
    
    def generate_integration_guide(self, csv_file: str, exam_name: str = None) -> str:
        """
        Generate a complete integration guide for the Flutter app.
        
        Args:
            csv_file: Path to the CSV file
            exam_name: Optional custom name for the exam
            
        Returns:
            Complete integration guide
        """
        if not exam_name:
            base_name = os.path.splitext(os.path.basename(csv_file))[0]
            exam_name = base_name.replace('_flutter_compatible', '')
        
        # Validate the file first
        validation = self.validate_flutter_compatibility(csv_file)
        
        guide = f"""
# 🚀 Flutter Integration Guide for {exam_name}

## 📋 Summary
- **File**: {os.path.basename(csv_file)}
- **Questions**: {validation['question_count']}
- **Supported Types**: {validation['supported_types']}
- **Unsupported Types**: {validation['unsupported_types']}
- **Status**: {'✅ Valid' if validation['valid'] else '❌ Issues Found'}

## 🔧 Integration Steps

### 1. Copy CSV File
```bash
# Copy the converted CSV file to your Flutter project
cp {csv_file} csv/{exam_name}.csv
```

### 2. Update pubspec.yaml
Add this to your `pubspec.yaml` under the assets section:
```yaml
  - csv/{exam_name}.csv
```

### 3. Create Exam Class
Create a new file `lib/data/{exam_name.lower().replace('-', '_')}_exam.dart`:

{self.create_flutter_import_code(csv_file, exam_name)}

### 4. Add to Exam Provider
In your `lib/providers/exam_provider.dart`, add:

```dart
// Import the exam
import '../data/{exam_name.lower().replace('-', '_')}_exam.dart';

// In your provider initialization:
final questions = await {exam_name.replace('-', '_').replace('_', '').title()}Exam.loadQuestions();
final examEntry = ExamEntry(
  id: '{exam_name}',
  title: '{exam_name.replace('-', ' ').title()}',
  questions: questions,
);
examProvider.addExam(examEntry);
```

### 5. Test Integration
Run your Flutter app and verify that:
- The exam appears in the exam list
- Questions load correctly
- Images display properly (if any)
- Answer options are formatted correctly

## ⚠️ Issues Found
"""
        
        if validation['issues']:
            for issue in validation['issues']:
                guide += f"- {issue}\n"
        else:
            guide += "- No issues found! ✅\n"
        
        guide += f"""
## 📊 Question Types Breakdown
- Multiple Choice: {validation['supported_types']} questions
- Hotspot: {validation['supported_types']} questions
- Other: {validation['unsupported_types']} questions

## 🎯 Next Steps
1. Copy the CSV file to your Flutter project
2. Update pubspec.yaml
3. Create the exam class
4. Test the integration
5. Add to your exam provider
6. Test the complete workflow

## 📝 Notes
- Make sure your Flutter app has the required dependencies
- Test with a small subset first
- Check that images load correctly if present
- Verify answer formatting works as expected

Happy coding! 🎉
"""
        
        return guide

def main():
    """Main function for command-line usage."""
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Flutter Integration Helper for ExamTopics CSV files",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python flutter_integration_helper.py --csv converted_file.csv
  python flutter_integration_helper.py --csv converted_file.csv --copy
  python flutter_integration_helper.py --csv converted_file.csv --validate
  python flutter_integration_helper.py --csv converted_file.csv --guide
        """
    )
    
    parser.add_argument('--csv', '-c', required=True, help='Path to converted CSV file')
    parser.add_argument('--copy', action='store_true', help='Copy file to Flutter project')
    parser.add_argument('--validate', action='store_true', help='Validate Flutter compatibility')
    parser.add_argument('--guide', action='store_true', help='Generate integration guide')
    parser.add_argument('--exam-name', help='Custom exam name')
    
    args = parser.parse_args()
    
    helper = FlutterIntegrationHelper()
    
    if args.validate:
        print("🔍 Validating Flutter compatibility...")
        validation = helper.validate_flutter_compatibility(args.csv)
        
        print(f"📊 Validation Results:")
        print(f"   Questions: {validation['question_count']}")
        print(f"   Supported Types: {validation['supported_types']}")
        print(f"   Unsupported Types: {validation['unsupported_types']}")
        print(f"   Status: {'✅ Valid' if validation['valid'] else '❌ Issues Found'}")
        
        if validation['issues']:
            print(f"\n⚠️  Issues Found:")
            for issue in validation['issues']:
                print(f"   • {issue}")
    
    if args.copy:
        print("📁 Copying file to Flutter project...")
        dest_path = helper.copy_to_flutter_project(args.csv, args.exam_name)
        print(f"✅ File copied to: {dest_path}")
    
    if args.guide:
        print("📖 Generating integration guide...")
        guide = helper.generate_integration_guide(args.csv, args.exam_name)
        print(guide)
        
        # Save guide to file
        guide_file = f"flutter_integration_guide_{os.path.splitext(os.path.basename(args.csv))[0]}.md"
        with open(guide_file, 'w', encoding='utf-8') as f:
            f.write(guide)
        print(f"📄 Guide saved to: {guide_file}")
    
    if not any([args.validate, args.copy, args.guide]):
        # Default: show all options
        print("🎯 Flutter Integration Helper")
        print("=" * 40)
        print(f"📁 CSV File: {args.csv}")
        print("\nAvailable actions:")
        print("  --validate: Check Flutter compatibility")
        print("  --copy: Copy file to Flutter project")
        print("  --guide: Generate integration guide")
        print("\nExample:")
        print(f"  python flutter_integration_helper.py --csv {args.csv} --validate --copy --guide")

if __name__ == "__main__":
    main() 