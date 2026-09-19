#!/bin/bash
# Extract version from git tag and update MARKETING_VERSION in project.pbxproj.
# Usage: ./bump-version.sh <tag>
# Example: ./bump-version.sh v1.11.5-goldengate-test → MARKETING_VERSION = 1.11.5

set -euo pipefail

TAG="${1:?Usage: $0 <tag>}"

# Strip 'v' prefix and anything after '-' (e.g., v1.11.5-goldengate-test → 1.11.5)
VERSION=$(echo "$TAG" | sed 's/^v//;s/-.*//')

if [[ -z "$VERSION" ]]; then
  echo "Error: could not extract version from tag '$TAG'"
  exit 1
fi

echo "Tag:    $TAG"
echo "Version: $VERSION"

PROJECT_FILE="Hideout.xcodeproj/project.pbxproj"

if [[ ! -f "$PROJECT_FILE" ]]; then
  echo "Error: $PROJECT_FILE not found"
  exit 1
fi

# Update MARKETING_VERSION (may appear twice — Debug and Release configs)
sed -i.bak "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = $VERSION;/g" "$PROJECT_FILE"

# Reset CURRENT_PROJECT_VERSION to 1 for the new version
sed -i.bak "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = 1;/g" "$PROJECT_FILE"

rm -f "${PROJECT_FILE}.bak"

echo "Updated $PROJECT_FILE:"
grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION" "$PROJECT_FILE" | head -4
