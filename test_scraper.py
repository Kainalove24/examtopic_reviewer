#!/usr/bin/env python3
"""
Test Script for ExamTopics Scraper
Tests the scraper with a small sample of links
"""

import os
import sys
import json
from advanced_examtopics_scraper import AdvancedExamTopicsScraper

def test_scraper():
    """Test the scraper with a small sample"""
    
    # Check if CSV file exists
    csv_file = "csv/az800_examtopics_links.csv"
    if not os.path.exists(csv_file):
        print(f"Error: CSV file not found: {csv_file}")
        return False
    
    # Create scraper instance with shorter delays for testing
    scraper = AdvancedExamTopicsScraper(delay=1.0, max_retries=2)
    
    try:
        print("Testing scraper with first 3 questions...")
        
        # Test with first 3 questions
        questions = scraper.scrape_all_questions(
            csv_file,
            "test_output.json",
            start_index=0,
            end_index=3
        )
        
        if questions:
            print(f"Successfully scraped {len(questions)} questions")
            
            # Print sample data
            for i, question in enumerate(questions, 1):
                print(f"\n--- Question {i} ---")
                print(f"Topic: {question.topic}")
                print(f"Question Number: {question.question_number}")
                print(f"URL: {question.url}")
                print(f"Question Text: {question.question_text[:100]}...")
                print(f"Options: {len(question.options)} found")
                print(f"Images: {len(question.images)} found")
                print(f"Explanation: {len(question.explanation)} characters")
                print(f"Is Premium: {question.is_premium}")
            
            # Save test results
            scraper.save_questions(questions, "test_results.json")
            print("\nTest results saved to test_results.json")
            
            return True
        else:
            print("No questions were scraped")
            return False
            
    except Exception as e:
        print(f"Error during testing: {e}")
        return False

def test_single_question():
    """Test scraping a single question"""
    
    csv_file = "csv/az800_examtopics_links.csv"
    if not os.path.exists(csv_file):
        print(f"Error: CSV file not found: {csv_file}")
        return False
    
    scraper = AdvancedExamTopicsScraper(delay=1.0, max_retries=2)
    
    try:
        # Load first link
        links = scraper.load_links_from_csv(csv_file)
        if not links:
            print("No links found in CSV file")
            return False
        
        print("Testing single question scraping...")
        question = scraper.scrape_question(links[0])
        
        print(f"\n--- Single Question Test ---")
        print(f"Topic: {question.topic}")
        print(f"Question Number: {question.question_number}")
        print(f"URL: {question.url}")
        print(f"Question Text Length: {len(question.question_text)}")
        print(f"Options Count: {len(question.options)}")
        print(f"Images Count: {len(question.images)}")
        print(f"Explanation Length: {len(question.explanation)}")
        
        # Save single question result
        scraper.save_questions([question], "single_question_test.json")
        print("Single question test saved to single_question_test.json")
        
        return True
        
    except Exception as e:
        print(f"Error during single question test: {e}")
        return False

if __name__ == "__main__":
    print("Starting scraper tests...")
    
    # Test single question first
    print("\n=== Testing Single Question ===")
    single_success = test_single_question()
    
    # Test multiple questions
    print("\n=== Testing Multiple Questions ===")
    multiple_success = test_scraper()
    
    if single_success and multiple_success:
        print("\n✅ All tests passed!")
    else:
        print("\n❌ Some tests failed!")
        sys.exit(1) 