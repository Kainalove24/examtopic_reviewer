#!/usr/bin/env python3
"""
CSV Converter for Flutter App Compatibility
Converts ExamTopics CSV files to be compatible with the Flutter exam reviewer app.
"""

import csv
import json
import re
from typing import List, Dict, Any
import os
from datetime import datetime

class CsvConverter:
    def __init__(self):
        self.supported_types = ['multiple_choice', 'hotspot', 'ordering']
    
    def convert_csv_for_flutter(self, input_file: str, output_file: str = None) -> str:
        """
        Convert CSV file to be compatible with Flutter app.
        
        Args:
            input_file: Path to input CSV file
            output_file: Path to output CSV file (optional)
            
        Returns:
            Path to the converted CSV file
        """
        if not output_file:
            base_name = os.path.splitext(input_file)[0]
            output_file = f"{base_name}_flutter_compatible.csv"
        
        print(f"🔄 Converting {input_file} for Flutter app compatibility...")
        
        # Read the original CSV
        questions = self._read_csv(input_file)
        
        # Convert each question
        converted_questions = []
        for question in questions:
            converted_question = self._convert_question(question)
            converted_questions.append(converted_question)
        
        # Write the converted CSV
        self._write_csv(converted_questions, output_file)
        
        print(f"✅ Conversion completed! Output saved to: {output_file}")
        print(f"📊 Converted {len(converted_questions)} questions")
        
        return output_file
    
    def _read_csv(self, file_path: str) -> List[Dict[str, str]]:
        """Read CSV file and return list of questions."""
        questions = []
        
        with open(file_path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                questions.append(row)
        
        return questions
    
    def _convert_question(self, question: Dict[str, str]) -> Dict[str, str]:
        """
        Convert a single question to Flutter-compatible format.
        
        Args:
            question: Original question dictionary
            
        Returns:
            Converted question dictionary
        """
        converted = {}
        
        # Basic fields
        converted['id'] = question.get('id', '')
        converted['type'] = self._format_question_type(question.get('type', 'multiple_choice'))
        converted['text'] = self._clean_text(question.get('text', ''))
        
        # Handle images
        converted['question_images'] = self._format_images(question.get('question_images', ''))
        converted['answer_images'] = self._format_images(question.get('answer_images', ''))
        
        # Handle options and answers based on question type
        question_type = question.get('type', '').lower()
        
        if question_type == 'hotspot':
            # For hotspot questions, extract options from question text if not provided
            options = question.get('options', '')
            if not options or options.strip() == '':
                options = self._format_options_for_hotspot(question.get('text', ''))
            converted['options'] = self._format_options(options)
            
            # For hotspot questions, extract answers from explanation field
            converted['answers'] = self._format_answers_for_hotspot(question.get('explanation', ''))
        else:
            # For other question types, use standard formatting
            converted['options'] = self._format_options(question.get('options', ''))
            converted['answers'] = self._format_answers(question.get('answers', ''), question_type)
        
        # Handle explanation
        converted['explanation'] = self._clean_explanation(question.get('explanation', ''))
        
        return converted
    
    def _clean_text(self, text: str) -> str:
        """Clean and format question text."""
        if not text:
            return ""
        
        # Remove extra whitespace
        text = re.sub(r'\s+', ' ', text.strip())
        
        # Clean up common formatting issues
        text = text.replace('"', '"').replace('"', '"')
        text = text.replace(''', "'").replace(''', "'")
        text = text.replace('…', '...')
        
        return text
    
    def _format_question_type(self, question_type: str) -> str:
        """Format question type for Flutter compatibility."""
        if not question_type:
            return "mcq"
        
        question_type = question_type.lower().strip()
        
        if question_type in ['multiple_choice', 'mcq', 'choice']:
            return "mcq"
        elif question_type == 'hotspot':
            return "hotspot"
        else:
            return "mcq"  # Default to mcq
    
    def _format_images(self, images: str) -> str:
        """Format image URLs for Flutter app."""
        if not images or images.strip() == '':
            return ""
        
        # Split by pipe and clean each URL
        image_list = [img.strip() for img in images.split('|') if img.strip()]
        
        # Filter out empty URLs
        image_list = [img for img in image_list if img and img != '']
        
        return '|'.join(image_list)
    
    def _format_options(self, options: str) -> str:
        """Format answer options for Flutter app."""
        if not options or options.strip() == '':
            return ""
        
        # Split by pipe and clean each option
        option_list = []
        for i, option in enumerate(options.split('|')):
            option = option.strip()
            if option:
                # Add letter prefix (A, B, C, D, etc.)
                letter = chr(65 + i)  # A=65, B=66, etc.
                cleaned_option = self._clean_text(option)
                option_list.append(f"{letter}.{cleaned_option}")
        
        return '|'.join(option_list)
    
    def _format_answers(self, answers: str, question_type: str) -> str:
        """Format answers based on question type."""
        if not answers or answers.strip() == '':
            return ""
        
        if question_type == 'hotspot':
            # For hotspot questions, return the answer text directly
            return self._clean_text(answers)
        elif question_type == 'multiple_choice' or question_type == 'mcq':
            # For multiple choice, return the answer letter(s)
            answer_list = []
            for answer in answers.split('|'):
                answer = answer.strip()
                if answer:
                    # Extract just the letter (A, B, C, D)
                    match = re.match(r'^([A-Z])', answer)
                    if match:
                        answer_list.append(match.group(1))
                    else:
                        # If no letter found, use the full answer
                        answer_list.append(answer)
            return '|'.join(answer_list)
        else:
            # For other types, return as is
            return self._clean_text(answers)
    
    def _format_options_for_hotspot(self, question_text: str) -> str:
        """Extract options from hotspot question text."""
        # Look for bullet points or numbered lists in the question text
        options = []
        
        # Split by common bullet point patterns
        lines = question_text.split('\n')
        for line in lines:
            line = line.strip()
            # Look for bullet points (•, -, *, etc.)
            if re.match(r'^[•\-*]\s*', line):
                option = re.sub(r'^[•\-*]\s*', '', line)
                if option:
                    options.append(option)
            # Look for numbered items
            elif re.match(r'^\d+\.\s*', line):
                option = re.sub(r'^\d+\.\s*', '', line)
                if option:
                    options.append(option)
        
        # If no options found in lines, try to extract from the text directly
        if not options:
            # Look for bullet points in the entire text
            bullet_pattern = r'[•\-*]\s*([^•\-*\n]+)'
            matches = re.findall(bullet_pattern, question_text)
            for match in matches:
                option = match.strip()
                if option:
                    options.append(option)
        
        return '|'.join(options)
    
    def _format_answers_for_hotspot(self, explanation: str) -> str:
        """Extract answers from hotspot question explanation."""
        if not explanation or explanation.strip() == '':
            return ""
        
        # Look for patterns that indicate the correct answers
        # Common patterns in hotspot explanations
        patterns = [
            r'Order of steps:\s*([^|]+)',
            r'Correct Steps \(In Order\):\s*([^|]+)',
            r'([A-Z][a-z]+)\s+([A-Z][a-z]+)\s+([A-Z][a-z]+)',
            r'(\d+\.\s*[^|]+)',
            r'([A-Z][a-z]+)\s+=\s+([^;]+)',
        ]
        
        for pattern in patterns:
            matches = re.findall(pattern, explanation, re.IGNORECASE)
            if matches:
                # Return the first match as the answer
                match = matches[0]
                if isinstance(match, tuple):
                    # If it's a tuple, join the elements
                    return ' '.join(match).strip()
                else:
                    return match.strip()
        
        # If no patterns match, return the first sentence of the explanation
        sentences = explanation.split('.')
        if sentences:
            return sentences[0].strip()
        
        return ""
    
    def _clean_explanation(self, explanation: str) -> str:
        """Clean and format explanation text."""
        if not explanation or explanation.strip() == '':
            return ""
        
        # Split by pipe and clean each explanation part
        explanation_parts = []
        for part in explanation.split('|'):
            part = part.strip()
            if part:
                part = self._clean_text(part)
                explanation_parts.append(part)
        
        return '|'.join(explanation_parts)
    
    def _write_csv(self, questions: List[Dict[str, str]], output_file: str):
        """Write converted questions to CSV file."""
        fieldnames = ['id', 'type', 'text', 'question_images', 'answer_images', 'options', 'answers', 'explanation']
        
        with open(output_file, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            
            for question in questions:
                writer.writerow(question)
    
    def validate_conversion(self, input_file: str, output_file: str) -> Dict[str, Any]:
        """
        Validate the conversion by checking the output file.
        
        Args:
            input_file: Path to original input file
            output_file: Path to converted output file
            
        Returns:
            Validation results dictionary
        """
        print(f"🔍 Validating conversion...")
        
        # Read original and converted files
        original_questions = self._read_csv(input_file)
        converted_questions = self._read_csv(output_file)
        
        validation_results = {
            'original_count': len(original_questions),
            'converted_count': len(converted_questions),
            'success': len(original_questions) == len(converted_questions),
            'issues': []
        }
        
        # Check for common issues
        for i, (orig, conv) in enumerate(zip(original_questions, converted_questions)):
            # Check if ID is preserved
            if orig.get('id') != conv.get('id'):
                validation_results['issues'].append(f"Question {i+1}: ID mismatch")
            
            # Check if text is not empty
            if not conv.get('text', '').strip():
                validation_results['issues'].append(f"Question {i+1}: Empty text")
            
            # Check if type is valid
            if conv.get('type') not in self.supported_types:
                validation_results['issues'].append(f"Question {i+1}: Invalid type '{conv.get('type')}'")
        
        if validation_results['issues']:
            print(f"⚠️  Found {len(validation_results['issues'])} issues:")
            for issue in validation_results['issues']:
                print(f"   • {issue}")
        else:
            print(f"✅ Validation passed! All {validation_results['converted_count']} questions converted successfully.")
        
        return validation_results
    
    def create_sample_data(self, output_file: str = "sample_flutter_data.csv"):
        """
        Create a sample CSV file with the expected Flutter format.
        
        Args:
            output_file: Path to output sample file
        """
        sample_questions = [
            {
                'id': '1',
                'type': 'multiple_choice',
                'text': 'What is the primary purpose of Amazon SageMaker?',
                'question_images': '',
                'answer_images': '',
                'options': 'Build and train machine learning models|Deploy web applications|Store data|Process payments',
                'answers': 'A',
                'explanation': 'Amazon SageMaker is a fully managed service for building, training, and deploying machine learning models.'
            },
            {
                'id': '2',
                'type': 'hotspot',
                'text': 'Select the correct region for deploying your ML model.',
                'question_images': 'https://example.com/image1.png',
                'answer_images': 'https://example.com/image2.png',
                'options': 'US East (N. Virginia)|US West (Oregon)|Europe (Ireland)|Asia Pacific (Tokyo)',
                'answers': 'US East (N. Virginia)',
                'explanation': 'US East (N. Virginia) is the primary region for AWS services.'
            }
        ]
        
        self._write_csv(sample_questions, output_file)
        print(f"📝 Sample data created: {output_file}")

def main():
    """Main function for command-line usage."""
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Convert ExamTopics CSV files for Flutter app compatibility",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python csv_converter.py --input data.csv
  python csv_converter.py --input data.csv --output converted_data.csv
  python csv_converter.py --validate data.csv converted_data.csv
  python csv_converter.py --sample
        """
    )
    
    parser.add_argument('--input', '-i', help='Input CSV file path')
    parser.add_argument('--output', '-o', help='Output CSV file path (optional)')
    parser.add_argument('--validate', '-v', nargs=2, metavar=('INPUT', 'OUTPUT'), 
                       help='Validate conversion between input and output files')
    parser.add_argument('--sample', '-s', action='store_true', 
                       help='Create a sample CSV file with Flutter-compatible format')
    
    args = parser.parse_args()
    
    converter = CsvConverter()
    
    if args.sample:
        converter.create_sample_data()
    elif args.validate:
        input_file, output_file = args.validate
        converter.validate_conversion(input_file, output_file)
    elif args.input:
        output_file = args.output
        converted_file = converter.convert_csv_for_flutter(args.input, output_file)
        print(f"\n🎉 Conversion completed successfully!")
        print(f"📁 Original file: {args.input}")
        print(f"📁 Converted file: {converted_file}")
        
        # Validate the conversion
        converter.validate_conversion(args.input, converted_file)
    else:
        parser.print_help()

if __name__ == "__main__":
    main() 