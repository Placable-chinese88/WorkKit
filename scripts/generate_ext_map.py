#!/usr/bin/env python3

import os
import re
import json
import sys
from pathlib import Path
from collections import defaultdict

def parse_swift_extensions(directory):
    """
    Parse Swift files to find MessageExtension declarations and build a mapping
    of extended types to their extension properties.
    """
    
    extensions_map = defaultdict(list)
    
    
    extension_pattern = re.compile(r'extension\s+(\w+)')
    enum_extensions_pattern = re.compile(r'enum\s+Extensions')
    static_let_pattern = re.compile(
        r'static\s+let\s+(\w+)\s+=\s+SwiftProtobuf\.MessageExtension<[^,]+,\s*(\w+)>\('
    )
    
    
    swift_files = Path(directory).rglob('*.swift')
    
    for filepath in swift_files:
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
                lines = content.split('\n')
                
                current_extension = None
                in_extensions_enum = False
                brace_depth = 0
                
                for line in lines:
                    
                    extension_match = extension_pattern.search(line)
                    if extension_match:
                        current_extension = extension_match.group(1)
                        in_extensions_enum = False
                        brace_depth = 0
                    
                    
                    if current_extension and enum_extensions_pattern.search(line):
                        in_extensions_enum = True
                    
                    
                    if in_extensions_enum:
                        brace_depth += line.count('{') - line.count('}')
                        if brace_depth <= 0:
                            in_extensions_enum = False
                    
                    
                    if current_extension and in_extensions_enum:
                        static_match = static_let_pattern.search(line)
                        if static_match:
                            property_name = static_match.group(1)
                            extended_type = static_match.group(2)
                            
                            
                            full_name = f"{current_extension}.Extensions.{property_name}"
                            
                            
                            extensions_map[extended_type].append(full_name)
        
        except Exception as e:
            print(f"Error processing {filepath}: {e}", file=sys.stderr)
    
    
    result = {}
    for extended_type in sorted(extensions_map.keys()):
        result[extended_type] = sorted(extensions_map[extended_type])
    
    return result

def main():
    if len(sys.argv) != 2:
        print("Usage: python script.py <directory>")
        print("Example: python script.py /path/to/swift/files")
        sys.exit(1)
    
    directory = sys.argv[1]
    
    if not os.path.isdir(directory):
        print(f"Error: '{directory}' is not a valid directory", file=sys.stderr)
        sys.exit(1)
    
    print(f"Scanning Swift files in: {directory}")
    extensions_map = parse_swift_extensions(directory)
    
    
    print("\nResults:")
    print(json.dumps(extensions_map, indent=2))
    
    
    output_file = "extensions_map.json"
    with open(output_file, 'w') as f:
        json.dump(extensions_map, f, indent=2)
    print(f"\nOutput written to: {output_file}")

if __name__ == "__main__":
    main()