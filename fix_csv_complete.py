#!/usr/bin/env python3
"""
Script to fix the AWS MLA C01 CSV file by removing incomplete rows.
"""

import csv
import sys

def fix_csv_file(input_file, output_file):
    """
    Fix the CSV file by removing rows with insufficient columns.
    Expected format: id,type,text,question_images,answer_images,options,answers,explanation
    """
    fixed_rows = []
    removed_rows = []
    
    with open(input_file, 'r', encoding='utf-8') as infile:
        reader = csv.reader(infile)
        
        for row_num, row in enumerate(reader, 1):
            # Check if row has the expected number of columns (9 columns)
            if len(row) == 9:
                fixed_rows.append(row)
            else:
                removed_rows.append((row_num, row))
                print(f"Removing row {row_num}: Insufficient columns (expected 9, got {len(row)})")
                if len(row) > 0:
                    print(f"  Content: {row[0][:100]}...")
    
    # Write the fixed CSV
    with open(output_file, 'w', encoding='utf-8', newline='') as outfile:
        writer = csv.writer(outfile)
        writer.writerows(fixed_rows)
    
    print(f"\nFixed CSV file created: {output_file}")
    print(f"Total rows processed: {len(fixed_rows) + len(removed_rows)}")
    print(f"Valid rows kept: {len(fixed_rows)}")
    print(f"Invalid rows removed: {len(removed_rows)}")
    
    return len(fixed_rows), len(removed_rows)

if __name__ == "__main__":
    input_file = "csv/aws_mla_c01.csv"
    output_file = "csv/aws_mla_c01_fixed.csv"
    
    try:
        valid_count, removed_count = fix_csv_file(input_file, output_file)
        print(f"\n✅ Successfully fixed CSV file!")
        print(f"✅ Valid questions: {valid_count}")
        print(f"✅ Removed incomplete questions: {removed_count}")
    except Exception as e:
        print(f"❌ Error fixing CSV file: {e}")
        sys.exit(1) 