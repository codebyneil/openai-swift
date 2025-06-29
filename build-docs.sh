#!/bin/bash

# Build Swift-DocC documentation for OpenAISwift

echo "Building OpenAISwift documentation..."

# Build documentation
swift package --allow-writing-to-directory ./docs \
    generate-documentation \
    --target OpenAISwift \
    --output-path ./docs \
    --transform-for-static-hosting \
    --hosting-base-path OpenAISwift

echo "Documentation built successfully!"
echo "Open docs/index.html to view the documentation."