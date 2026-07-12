# Dynamo Chess Web Build Script
$ErrorActionPreference = "Stop"

# Disable JIT optimization to prevent Dart VM compiler crash
$env:DART_VM_OPTIONS = "--optimization-counter-threshold=100000"

Write-Host "🚀 Starting Dynamo Chess Web Build Process..." -ForegroundColor Cyan

# 1. Build Flutter game
Write-Host "`n🎮 Building Flutter Web Client..." -ForegroundColor Green
cmd.exe /c "c:\Users\girid\Downloads\Moneygrow-main\flutter_sdk\bin\flutter.bat build web --release --no-wasm-dry-run --base-href /"

Write-Host "`n✅ Build Successful!" -ForegroundColor Cyan
