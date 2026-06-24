$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$sdkPath = "C:\Users\girid\AppData\Local\Android\Sdk"
$cmdlineToolsDir = "$sdkPath\cmdline-tools"
$zipPath = "$sdkPath\cmdline-tools.zip"

Write-Host "Creating cmdline-tools directory..."
if (-not (Test-Path $cmdlineToolsDir)) {
    New-Item -ItemType Directory -Force -Path $cmdlineToolsDir
}

Write-Host "Downloading cmdline-tools..."
Invoke-WebRequest -Uri "https://dl.google.com/android/repository/commandlinetools-win-14742923_latest.zip" -OutFile $zipPath

Write-Host "Extracting cmdline-tools..."
Expand-Archive -Path $zipPath -DestinationPath $cmdlineToolsDir -Force

Write-Host "Renaming folder to 'latest'..."
if (Test-Path "$cmdlineToolsDir\cmdline-tools") {
    Rename-Item -Path "$cmdlineToolsDir\cmdline-tools" -NewName "latest" -Force
}

Write-Host "Accepting licenses and installing NDK..."
$sdkmanager = "$cmdlineToolsDir\latest\bin\sdkmanager.bat"
echo y | & $sdkmanager --sdk_root=$sdkPath --licenses
& $sdkmanager --sdk_root=$sdkPath "ndk;25.1.8937393"

Write-Host "Done!"
