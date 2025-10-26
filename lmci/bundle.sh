#!/bin/bash

# Script to list files matching provided patterns and recursively include directory contents
# Usage: ./bundle.sh [--refspec <commit|branch|tag>] <file_pattern1> <directory1> <file_pattern2> ...

# Parse --refspec option
refspec=""
patterns=()

while [ $# -gt 0 ]; do
  case "$1" in
    --refspec)
      if [ -z "$2" ]; then
        echo "Error: --refspec requires a value" >&2
        exit 1
      fi
      refspec="$2"
      shift 2
      ;;
    *)
      patterns+=("$1")
      shift
      ;;
  esac
done

# Restore positional parameters
set -- "${patterns[@]}"

if [ $# -eq 0 ]; then
  echo "Usage: $0 [--refspec <commit|branch|tag>] <file_pattern1> [<file_pattern2> ...]" >&2
  echo "Example: $0 --refspec HEAD src/ include/*.h" >&2
  exit 1
fi

# Validate refspec if provided
if [[ -n "$refspec" ]]; then
  if ! git rev-parse --verify "$refspec" >/dev/null 2>&1; then
    echo "Error: Invalid refspec: $refspec" >&2
    exit 1
  fi
  echo "Using Git refspec: $refspec" >&2
fi

# ============================================================================
# Utility functions
# ============================================================================

# Get file content from filesystem or git
get_content() {
  local file="$1"
  if [[ -n "$refspec" ]]; then
    git show "$refspec:$file" 2>/dev/null
  else
    cat "$file"
  fi
}

# Return 0 if file is likely text, 1 otherwise
is_text_file() {
  local file="$1"
  if command -v file >/dev/null 2>&1; then
    local mtype
    if [[ -n "$refspec" ]]; then
      # Git mode: pipe content through file
      mtype=$(git show "$refspec:$file" 2>/dev/null | file -b --mime-type - 2>/dev/null)
    else
      # Filesystem mode
      mtype=$(file -b --mime-type "$file" 2>/dev/null)
    fi
    case "$mtype" in
      text/*|application/x-sh|application/x-shellscript) return 0 ;;
      *) return 1 ;;
    esac
  else
    # Fallback heuristic: look for null bytes
    if [[ -n "$refspec" ]]; then
      git show "$refspec:$file" 2>/dev/null | head -c 512 | grep -q $'\x00' && return 1 || return 0
    else
      head -c 512 "$file" 2>/dev/null | grep -q $'\x00' && return 1 || return 0
    fi
  fi
}

# Safely output text content, converting if needed
output_file_content() {
  local file="$1"
  if ! is_text_file "$file"; then
    echo "[Binary content not shown]" >&2
    return
  fi

  local enc
  if [[ -n "$refspec" ]]; then
    # Git mode: pipe content through file
    enc=$(git show "$refspec:$file" 2>/dev/null | file -b --mime-encoding - 2>/dev/null)
  else
    # Filesystem mode
    enc=$(file -b --mime-encoding "$file" 2>/dev/null)
  fi

  case "$enc" in
    utf-8|us-ascii)
      get_content "$file"
      ;;
    utf-16*)
      if command -v iconv >/dev/null 2>&1; then
        get_content "$file" | iconv -f "$enc" -t UTF-8 2>/dev/null || get_content "$file"
      else
        get_content "$file"
      fi
      ;;
    iso-8859-*|windows-1252|unknown-8bit)
      if command -v iconv >/dev/null 2>&1; then
        # Try the detected encoding first, fall back to ISO-8859-1, then raw
        get_content "$file" | iconv -f "$enc" -t UTF-8 2>/dev/null || \
        get_content "$file" | iconv -f ISO-8859-1 -t UTF-8 2>/dev/null || \
        get_content "$file"
      else
        get_content "$file"
      fi
      ;;
    *)
      # Last resort: raw output, warn
      echo "[File encoding: $enc]" >&2
      get_content "$file"
      ;;
  esac
}

# Initialize empty array for concrete files
files=()

# First pass: collect all concrete filenames from patterns and directories
if [[ -n "$refspec" ]]; then
  # Git mode: use git ls-tree with pathspecs
  # Use git ls-tree to list files matching patterns
  while IFS= read -r file; do
    if is_text_file "$file"; then
      files+=("$file")
    else
      echo "Skipping binary file: $file" >&2
    fi
  done < <(git ls-tree -r --name-only "$refspec" -- "$@" | sort)

  echo "Added files from Git refspec $refspec" >&2
else
  # Filesystem mode: use find-based collection
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
        if is_text_file "$dir_file"; then
          files+=("$dir_file")
        else
          echo "Skipping binary file: $dir_file" >&2
        fi
      done < <(find "$pattern" -type f -not -path "*/\.*" | sort)

      # Inform user we processed a directory
      echo "Added files from directory: $pattern" >&2
    elif [[ "$pattern" == *\** || "$pattern" == *\?* || "$pattern" == *\[* ]]; then
      # if there's a slash plus wildcard, do a recursive find
      if [[ "$pattern" == */*[\*\?\[]* ]]; then
        dir=${pattern%/*}
        pat=${pattern##*/}
        while IFS= read -r f; do
          if is_text_file "$f"; then
            files+=("$f")
          else
            echo "Skipping binary file: $f" >&2
          fi
        done < <(find "$dir" -type f -name "$pat" -not -path "*/\.*" | sort)
        echo "Added recursive glob files for pattern: $pattern" >&2
        continue
      fi

      # Check if expansion returned any files
      if [ ${#glob_files[@]} -eq 0 ] || [ "${glob_files[0]}" = "$pattern" ]; then
        echo "No files matching pattern: $pattern" >&2
        continue
      fi

      # Add expanded files to our list
      for gf in "${glob_files[@]}"; do
        if [ -f "$gf" ] && is_text_file "$gf"; then
          files+=("$gf")
        elif [ -f "$gf" ]; then
          echo "Skipping binary file: $gf" >&2
        fi
      done
      echo "Added files matching pattern: $pattern" >&2
    else
      # Add concrete file to the list
      if [ -f "$pattern" ] && is_text_file "$pattern"; then
        files+=("$pattern")
        echo "Added individual file: $pattern" >&2
      elif [ -f "$pattern" ]; then
        echo "Skipping binary file: $pattern" >&2
      else
        files+=("$pattern")
        echo "Added individual file: $pattern" >&2
      fi
    fi
  done
fi

# Echo the total count of files to process
echo "Processing ${#files[@]} files:" >&2
echo "" >&2

# Print column headers
printf "Chars Lines File\n" >&2

# Initialize totals
total_chars=0
total_lines=0

# Second pass: count and report stats for each file
for file in "${files[@]}"; do
  # In git mode, we don't check if file exists on filesystem
  if [[ -n "$refspec" ]] || [ -f "$file" ]; then
    # Count characters and lines
    char_count=$(get_content "$file" | wc -c | tr -d ' ')
    line_count=$(get_content "$file" | wc -l | tr -d ' ')

    # Accumulate totals
    total_chars=$((total_chars + char_count))
    total_lines=$((total_lines + line_count))

    # Echo the file being processed to stderr with formatted columns
    printf "%5d %5d %s\n" "$char_count" "$line_count" "$file" >&2
  else
    echo "File not found: $file" >&2
  fi
done

# Print totals
printf "%5d %5d TOTAL\n" "$total_chars" "$total_lines" >&2

# Output the wrapper fence for base64-encoded file pack
echo '```filepack-base64'

# Third pass: generate all fenced file contents and pipe through base64
(
  for file in "${files[@]}"; do
    # In git mode, we don't check if file exists on filesystem
    if [[ -n "$refspec" ]] || [ -f "$file" ]; then
      # Count characters and lines for metadata
      char_count=$(get_content "$file" | wc -c | tr -d ' ')
      line_count=$(get_content "$file" | wc -l | tr -d ' ')

      # Output the file contents with fenced blocks including metadata
      printf '```filename=%s chars=%d lines=%d\n' "$file" "$char_count" "$line_count"
      output_file_content "$file"
      echo '```'
      echo    # blank line for readability
    fi
  done
) | if base64 --help 2>&1 | grep -q -- --wrap; then
  base64 -w 0
else
  base64 -b 0
fi

# Close the wrapper fence
echo '```'

