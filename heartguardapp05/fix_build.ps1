# Script to fix Flutter build issues

Write-Host "Starting build fixes..."

# Make a backup of the Gradle files
Write-Host "1. Backing up Gradle files..."
Copy-Item -Path "android/app/build.gradle" -Destination "android/app/build.gradle.bak" -Force
Copy-Item -Path "android/build.gradle" -Destination "android/build.gradle.bak" -Force
Copy-Item -Path "android/gradle.properties" -Destination "android/gradle.properties.bak" -Force

# Clean Flutter cache
Write-Host "2. Cleaning Flutter cache..."
flutter clean

# Clean Android build
Write-Host "3. Cleaning Android cache..."
Remove-Item -Path "android/.gradle" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "android/app/build" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".dart_tool" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".flutter-plugins" -Force -ErrorAction SilentlyContinue
Remove-Item -Path ".flutter-plugins-dependencies" -Force -ErrorAction SilentlyContinue

# Get dependencies
Write-Host "4. Getting Flutter dependencies..."
flutter pub get

# Fix Android Studio SDK
Write-Host "5. Updating and fixing Android SDK settings..."
flutter config --android-sdk="${env:LOCALAPPDATA}\Android\sdk"

Write-Host "Build fix complete. Now try running: flutter run" 