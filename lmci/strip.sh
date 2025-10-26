#!/bin/bash
# Copyright 2025 Scale Invariant, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: Brad Hyslop <bhyslop@scaleinvariant.org>
#
# Compatible with Bash 3.2 (e.g., macOS default shell)

# Script to strip trailing whitespace from files matching provided patterns
# Usage: ./strip_whitespace.sh <file_pattern1> <directory1> <file_pattern2> ...

if [ $# -eq 0 ]; then
  echo "Usage: $0 <file_pattern1> <directory1> <file_pattern2> ..." >&2
  exit 1
fi

# Initialize empty array for concrete files
files=()

# First pass: collect all concrete filenames from patterns and directories
for pattern in "$@"; do
  # Fail if pattern contains double slash
  if [[ "$pattern" == *"//"* ]]; then
    echo "Error: Pattern contains double slash which is not supported: $pattern" >&2
    exit 1
  fi
  
  # Check if it's a directory
  if [ -d "$pattern" ]; then
    # Find all files recursively in the directory and add to list
    while IFS= read -r dir_file; do
      files+=("$dir_file")
    done < <(find "$pattern" -type f -not -path "*/\.*" | sort)
    
    # Inform user we processed a directory
    echo "Added files from directory: $pattern" >&2
  elif [[ "$pattern" == *\** || "$pattern" == *\?* || "$pattern" == *\[* ]]; then
    # if there's a slash plus wildcard, do a recursive find
    if [[ "$pattern" == */*[\*\?\[]* ]]; then
      dir=${pattern%/*}
      pat=${pattern##*/}
      while IFS= read -r f; do
        files+=("$f")
      done < <(find "$dir" -type f -name "$pat" -not -path "*/\.*" | sort)
      echo "Added recursive glob files for pattern: $pattern" >&2
      continue
    fi
    
    # Handle simple glob patterns
    glob_files=($pattern)
    
    # Check if expansion returned any files
    if [ ${#glob_files[@]} -eq 0 ] || [ "${glob_files[0]}" = "$pattern" ]; then
      echo "No files matching pattern: $pattern" >&2
      continue
    fi

    # Add expanded files to our list
    files+=("${glob_files[@]}")
    echo "Added files matching pattern: $pattern" >&2
  else
    # Add concrete file to the list
    files+=("$pattern")
    echo "Added individual file: $pattern" >&2
  fi
done

# Echo the total count of files to process
echo "Processing ${#files[@]} files:" >&2

# Second pass: process the list of files
for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    # Check if file is binary
    if file -b --mime-encoding "$file" | grep -q binary; then
      echo "Error: Binary file detected: $file" >&2
      exit 1
    fi
    
    # Create a temporary file
    tmpfile=$(mktemp)

    # Process the file: strip trailing whitespace and ensure final newline
    sed 's/[[:space:]]*$//' "$file" > "$tmpfile"
    
    # Ensure final newline
    if [ -s "$tmpfile" ] && [ "$(tail -c 1 "$tmpfile" | wc -l)" -eq 0 ]; then
      echo >> "$tmpfile"
    fi
    
    # Replace original file only if there were changes
    if ! cmp -s "$file" "$tmpfile"; then
      # Save original file mode
      mode=$(stat -c '%a' "$file")
      mv "$tmpfile" "$file"
      chmod "$mode" "$file"
      echo "Stripped whitespace: $file" >&2
    else
      rm "$tmpfile"
    fi
  else
    echo "File not found: $file" >&2
  fi
done

# eof

