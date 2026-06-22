#!/bin/bash

# Anna OS Setup Script
# Run this to prepare for development

set -e

echo "🚀 Anna OS Setup"
echo "================="
echo ""

# Check Xcode
if ! command -v xcode-select &> /dev/null; then
    echo "❌ Xcode not installed"
    echo "Install from App Store or developer.apple.com"
    exit 1
fi
echo "✓ Xcode installed"

# Check Swift
if ! command -v swift &> /dev/null; then
    echo "❌ Swift not installed"
    exit 1
fi
echo "✓ Swift installed"
swift --version

# Create Xcode project
echo ""
echo "Creating Xcode project..."

PROJECT_NAME="AnnaOS"
PROJECT_PATH="~/Desktop/anna-os-build/$PROJECT_NAME"

# Note: You'll need to create this in Xcode UI or via command line
echo "📝 Next steps:"
echo "1. Open Xcode: open -a Xcode"
echo "2. File → New → Project"
echo "3. Choose: iOS → App (or watchOS → App)"
echo "4. Product Name: $PROJECT_NAME"
echo "5. Interface: SwiftUI"
echo "6. Language: Swift"
echo "7. Drag all .swift files from ~/Desktop/anna-os-build into the project"
echo ""

# Environment
echo "Setting up environment..."

# Check if Claude API key is set
if [ -z "$CLAUDE_API_KEY" ]; then
    echo "⚠️  CLAUDE_API_KEY not set"
    echo ""
    echo "Get your Claude API key:"
    echo "1. Visit console.anthropic.com"
    echo "2. Create new API key"
    echo "3. Run: export CLAUDE_API_KEY='sk-ant-...'"
    echo "4. Add to ~/.zshrc or ~/.bashrc to persist"
    echo ""
else
    echo "✓ CLAUDE_API_KEY set (${#CLAUDE_API_KEY} chars)"
fi

echo ""
echo "✅ Setup complete"
echo ""
echo "Next: Open Xcode and add the Swift files to your project"
echo "Then: Tap ▶ to run the simulator"
