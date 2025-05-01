Write-Host "====================================" -ForegroundColor Cyan
Write-Host "HeartGuard Test Runner" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

# Check dependencies
Write-Host "Checking dependencies..." -ForegroundColor Yellow
flutter pub get

# Note: No need to generate mocks since we're using manual mocks

# Run tests
Write-Host "Running tests..." -ForegroundColor Yellow
flutter test

Write-Host "====================================" -ForegroundColor Cyan
Write-Host "Tests completed!" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Cyan 