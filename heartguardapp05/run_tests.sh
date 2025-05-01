#!/bin/bash

echo "===================================="
echo "HeartGuard Test Runner"
echo "===================================="

# Check dependencies
echo "Checking dependencies..."
flutter pub get

# Note: No need to generate mocks since we're using manual mocks

# Run tests
echo "Running tests..."
flutter test

echo "===================================="
echo "Tests completed!"
echo "====================================" 