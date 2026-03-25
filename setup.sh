#!/usr/bin/env bash
set -e

echo ""
echo "  ✏  Artisanal Todo — Dev Setup"
echo "  ─────────────────────────────"
echo ""

# Check for Homebrew
if ! command -v brew &>/dev/null; then
    echo "→ Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install XcodeGen if missing
if ! command -v xcodegen &>/dev/null; then
    echo "→ Installing XcodeGen..."
    brew install xcodegen
else
    echo "→ XcodeGen already installed ($(xcodegen --version))"
fi

# Generate Xcode project
echo "→ Generating TodoApp.xcodeproj..."
xcodegen generate

echo ""
echo "  ✓ Done! Run one of:"
echo "    open TodoApp.xcodeproj    (open in Xcode)"
echo "    make build                (build from terminal)"
echo ""
