# HeartGuard Tests

This directory contains the test suite for the HeartGuard application.

## Structure

```
test/
├── services/           # Tests for service classes
├── controllers/        # Tests for controller classes
├── mocks/             # Mock implementations
└── test_helper.dart   # Test utilities and mock generators
```

## Running Tests

To run all tests:
```bash
flutter test
```

To run a specific test file:
```bash
flutter test test/path/to/test_file.dart
```

## Generating Mocks

Mocks are generated using the `mockito` package. To regenerate mocks:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Test Guidelines

1. Each test file should focus on testing a single class/component
2. Use meaningful test descriptions
3. Follow the Arrange-Act-Assert pattern
4. Mock external dependencies
5. Test both success and failure cases
6. Keep tests independent and isolated 