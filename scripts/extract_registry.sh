#!/bin/bash

command -v jq >/dev/null 2>&1 || { echo "Error: jq is not installed. Run: brew install jq"; exit 1; }
command -v frida >/dev/null 2>&1 || { echo "Error: frida is not installed. Run: uv pip install frida-tools"; exit 1; }

SIP_STATUS=$(csrutil status 2>&1)
if [[ ! "$SIP_STATUS" =~ "disabled" ]]; then
    echo "Error: SIP must be disabled. Current status: $SIP_STATUS"
    echo "Reboot into Recovery Mode (Cmd+R) and run: csrutil disable"
    exit 1
fi

if [ -z "$1" ]; then
    echo "Usage: $0 <app-name>"
    echo "Example: $0 Keynote"
    exit 1
fi

APP_NAME=$1
OUTPUT_FILE="$(echo $APP_NAME | tr '[:upper:]' '[:lower:]')_registry.json"

echo "Extracting TSPRegistry from $APP_NAME..."

frida -n "$APP_NAME" -q --eval 'var TSPRegistry = ObjC.classes.TSPRegistry; var registry = TSPRegistry.sharedRegistry(); var description = registry.toString(); var lines = description.split("\n"); var results = {}; var inPrototypeMap = false; for (var i = 0; i < lines.length; i++) { var line = lines[i].trim(); if (line.includes("_messageTypeToPrototypeMap")) { inPrototypeMap = true; continue; } if (inPrototypeMap && line.includes("_")) { break; } if (inPrototypeMap && line.includes(" -> ") && !line.includes(" = {")) { var parts = line.split(" -> "); if (parts.length >= 2) { var typeNum = parseInt(parts[0]); var remainder = parts[1].trim(); var classNameMatch = remainder.match(/[A-Z][A-Za-z0-9_.]+/); if (!isNaN(typeNum) && classNameMatch) { results[typeNum] = classNameMatch[0]; }}}} console.log(JSON.stringify(results, null, 2));' | jq '.' > "$OUTPUT_FILE"

echo "Done! Saved to $OUTPUT_FILE"