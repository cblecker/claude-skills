#!/bin/bash
# Categorize files by type (code, tests, docs, config, other)
# Usage: echo -e "file1\nfile2" | ./categorize-files.sh

set -euo pipefail

# Arrays to hold categorized files
declare -a code_files=()
declare -a test_files=()
declare -a doc_files=()
declare -a config_files=()
declare -a other_files=()

# Function to categorize a single file
categorize_file() {
  local file="$1"
  local basename
  basename=$(basename "$file")
  local extension="${basename##*.}"
  local name_lower
  name_lower=$(echo "$basename" | tr '[:upper:]' '[:lower:]')

  # Test files (check first as they're also code)
  if [[ "$name_lower" == *"test"* ]] || [[ "$name_lower" == *"spec"* ]] || \
     [[ "$name_lower" == *"_test."* ]] || [[ "$name_lower" == *".test."* ]] || \
     [[ "$file" == *"/test/"* ]] || [[ "$file" == *"/tests/"* ]] || \
     [[ "$file" == *"/__tests__/"* ]] || [[ "$file" == *"/spec/"* ]] || \
     [[ "$file" == "test/"* ]] || [[ "$file" == "tests/"* ]] || \
     [[ "$file" == "__tests__/"* ]] || [[ "$file" == "spec/"* ]]; then
    test_files+=("$file")
    return
  fi

  # Documentation files
  if [[ "$extension" == "md" ]] || [[ "$extension" == "rst" ]] || \
     [[ "$extension" == "txt" ]] || [[ "$extension" == "adoc" ]] || \
     [[ "$name_lower" == "readme"* ]] || [[ "$name_lower" == "changelog"* ]] || \
     [[ "$name_lower" == "license"* ]] || [[ "$name_lower" == "contributing"* ]] || \
     [[ "$name_lower" == "authors"* ]] || [[ "$name_lower" == "contributors"* ]] || \
     [[ "$file" == *"/docs/"* ]] || [[ "$file" == *"/documentation/"* ]]; then
    doc_files+=("$file")
    return
  fi

  # Configuration files
  if [[ "$extension" == "json" ]] || [[ "$extension" == "yaml" ]] || \
     [[ "$extension" == "yml" ]] || [[ "$extension" == "toml" ]] || \
     [[ "$extension" == "ini" ]] || [[ "$extension" == "conf" ]] || \
     [[ "$extension" == "config" ]] || [[ "$extension" == "xml" ]] || \
     [[ "$basename" == "."* ]] || [[ "$basename" == "Dockerfile"* ]] || \
     [[ "$basename" == "Makefile"* ]] || [[ "$basename" == "package.json" ]] || \
     [[ "$basename" == "tsconfig.json" ]] || [[ "$basename" == "go.mod" ]] || \
     [[ "$basename" == "go.sum" ]] || [[ "$basename" == "Cargo.toml" ]] || \
     [[ "$basename" == "pyproject.toml" ]] || [[ "$basename" == "setup.py" ]] || \
     [[ "$file" == *"/config/"* ]] || [[ "$file" == *"/.github/"* ]]; then
    config_files+=("$file")
    return
  fi

  # Code files (common extensions)
  if [[ "$extension" == "ts" ]] || [[ "$extension" == "js" ]] || \
     [[ "$extension" == "tsx" ]] || [[ "$extension" == "jsx" ]] || \
     [[ "$extension" == "go" ]] || [[ "$extension" == "py" ]] || \
     [[ "$extension" == "rb" ]] || [[ "$extension" == "java" ]] || \
     [[ "$extension" == "c" ]] || [[ "$extension" == "cpp" ]] || \
     [[ "$extension" == "h" ]] || [[ "$extension" == "hpp" ]] || \
     [[ "$extension" == "cs" ]] || [[ "$extension" == "rs" ]] || \
     [[ "$extension" == "swift" ]] || [[ "$extension" == "kt" ]] || \
     [[ "$extension" == "scala" ]] || [[ "$extension" == "sh" ]] || \
     [[ "$extension" == "bash" ]] || [[ "$extension" == "zsh" ]] || \
     [[ "$extension" == "php" ]] || [[ "$extension" == "vue" ]] || \
     [[ "$extension" == "svelte" ]] || [[ "$extension" == "dart" ]] || \
     [[ "$file" == *"/src/"* ]] || [[ "$file" == *"/lib/"* ]]; then
    code_files+=("$file")
    return
  fi

  # Everything else
  other_files+=("$file")
}

# Read stdin line by line
while IFS= read -r file; do
  # Skip empty lines
  [ -z "$file" ] && continue

  categorize_file "$file"
done

# Build JSON output (jq is required)
if ! command -v jq &> /dev/null; then
  echo '{"error": "jq is required but not installed"}' >&2
  exit 1
fi

# Helper function to convert array elements to JSON (bash 3.2 compatible)
# Uses positional parameters to receive array elements
build_json_array() {
  if [ $# -eq 0 ]; then
    echo "[]"
  else
    printf '%s\0' "$@" | jq -R -s -c 'split("\u0000") | map(select(length > 0))'
  fi
}

# Build arrays safely using null-delimited streams (bash 3.2 compatible)
code_json=$(build_json_array "${code_files[@]+"${code_files[@]}"}")
test_json=$(build_json_array "${test_files[@]+"${test_files[@]}"}")
doc_json=$(build_json_array "${doc_files[@]+"${doc_files[@]}"}")
config_json=$(build_json_array "${config_files[@]+"${config_files[@]}"}")
other_json=$(build_json_array "${other_files[@]+"${other_files[@]}"}")

# Build final object
jq -n \
  --argjson code "$code_json" \
  --argjson tests "$test_json" \
  --argjson docs "$doc_json" \
  --argjson config "$config_json" \
  --argjson other "$other_json" \
  '{
    code: $code,
    tests: $tests,
    docs: $docs,
    config: $config,
    other: $other
  }'
