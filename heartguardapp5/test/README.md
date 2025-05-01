# HeartGuard App Test Suite

This directory contains the test suite for the HeartGuard application, which includes unit tests and integration tests for various components of the app.

## Test Structure

The test suite is organized into several key test files:

1. `heart_rate_monitoring_test.dart` - Tests for heart rate monitoring functionality
2. `sms_service_test.dart` - Tests for SMS notification service
3. `fcm_service_test.dart` - Tests for Firebase Cloud Messaging service

## Setup Instructions

1. Install required dependencies:
```bash
flutter pub add mockito --dev
flutter pub add build_runner --dev
```

2. Generate mock classes:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

3. Run tests:
```bash
flutter test
```

## Test Categories

### Unit Tests
- Test individual components in isolation
- Use mock objects to simulate dependencies
- Verify specific behaviors and edge cases

### Integration Tests
- Test interactions between multiple components
- Verify complete workflows
- Ensure proper data flow between services

## Mock Objects

The test suite uses mock objects for the following services:
- Firebase Firestore
- Firebase Auth
- Firebase Database
- Firebase Cloud Messaging
- SMS Service
- Logger Service
- Notification Service

## Test Coverage

The test suite covers:
1. Heart Rate Monitoring
   - Normal heart rate detection
   - Abnormal heart rate detection (high/low)
   - Data storage in Firestore
   - Notification triggering

2. SMS Service
   - Emergency contact retrieval
   - SMS message sending
   - Error handling

3. FCM Service
   - Token management
   - Notification sending
   - Error handling

## Adding New Tests

When adding new tests:
1. Create a new test file in this directory
2. Use the existing mock objects where possible
3. Follow the established pattern for test structure
4. Add appropriate comments and documentation
5. Update this README if necessary

## Troubleshooting

Common issues and solutions:

1. Mock Generation Errors
   - Run `flutter pub get` to ensure all dependencies are installed
   - Run `flutter pub run build_runner clean` before generating mocks
   - Check for any syntax errors in the test files

2. Test Failures
   - Verify mock object setup
   - Check for null safety issues
   - Ensure all dependencies are properly mocked

3. Build Issues
   - Clear the build cache: `flutter clean`
   - Reinstall dependencies: `flutter pub get`
   - Regenerate mocks: `flutter pub run build_runner build --delete-conflicting-outputs`

## Best Practices

1. Test Organization
   - Group related tests using `group()`
   - Use descriptive test names
   - Follow the Arrange-Act-Assert pattern

2. Mock Usage
   - Mock only necessary dependencies
   - Use appropriate matchers for verification
   - Set up mock behavior in `setUp()`

3. Error Handling
   - Test both success and failure cases
   - Verify error logging
   - Check for proper error propagation

4. Documentation
   - Add comments for complex test logic
   - Document mock setup
   - Explain test expectations

## Contributing

When contributing to the test suite:
1. Follow the established patterns
2. Add appropriate documentation
3. Ensure all tests pass
4. Update this README if necessary 