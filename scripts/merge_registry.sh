#!/bin/bash
# Check requirements
command -v jq >/dev/null 2>&1 || { echo "Error: jq is not installed. Run: brew install jq"; exit 1; }

# Check input files exist
for file in keynote_registry.json pages_registry.json numbers_registry.json; do
    if [ ! -f "$file" ]; then
        echo "Error: $file not found. Run ./extract_registry.sh first."
        exit 1
    fi
done

echo "Finding common entries (same key and value)..."

# Get all keys that exist in all three files with the same value
COMMON_KEYS=$(jq -s '
    .[0] as $keynote |
    .[1] as $pages |
    .[2] as $numbers |
    $keynote | to_entries | 
    map(select(
        .key as $k | .value as $v |
        ($pages[$k] == $v) and ($numbers[$k] == $v)
    )) |
    map(.key)
' keynote_registry.json pages_registry.json numbers_registry.json)

COMMON_COUNT=$(echo "$COMMON_KEYS" | jq 'length')
echo "Found $COMMON_COUNT common entries (identical key-value pairs)"

# Create common registry
echo "$COMMON_KEYS" | jq -s '
    .[1] as $keys |
    .[0] | to_entries | map(select(.key | . as $k | $keys | index($k))) | from_entries
' keynote_registry.json - > common_registry.json

echo "Created common_registry.json with $COMMON_COUNT entries"

# Remove common entries from each registry
for file in keynote_registry.json pages_registry.json numbers_registry.json; do
    ORIGINAL_COUNT=$(jq 'length' "$file")
    
    echo "$COMMON_KEYS" | jq -s '
        .[1] as $keys |
        .[0] | to_entries | map(select(.key | . as $k | $keys | index($k) | not)) | from_entries
    ' "$file" - > "${file}.tmp"
    
    mv "${file}.tmp" "$file"
    
    NEW_COUNT=$(jq 'length' "$file")
    REMOVED=$((ORIGINAL_COUNT - NEW_COUNT))
    
    echo "Updated $file: removed $REMOVED common entries, $NEW_COUNT unique entries remain"
done

echo ""
echo "Success! Common entries extracted to common_registry.json"
echo "Individual registries now contain only their unique key-value pairs"