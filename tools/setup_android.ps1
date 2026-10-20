$ErrorActionPreference = 'Stop'

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$AndroidDir = Join-Path $ProjectRoot 'android'

Write-Host 'تحقق من Flutter...' -ForegroundColor Cyan
flutter --version | Out-Null

if (-not (Test-Path (Join-Path $AndroidDir 'app\src\main\AndroidManifest.xml'))) {
    $TempRoot = Join-Path $env:TEMP ('housing_mobile_scaffold_' + [Guid]::NewGuid().ToString('N'))
    $TempProject = Join-Path $TempRoot 'housing_mobile_scaffold'
    New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null
    try {
        Write-Host 'إنشاء ملفات Android من نسخة Flutter المثبتة...' -ForegroundColor Cyan
        flutter create --platforms=android --org ye.alghith --project-name housing_mobile $TempProject
        if ($LASTEXITCODE -ne 0) { throw 'فشل إنشاء هيكل Android بواسطة Flutter.' }
        Copy-Item -Path (Join-Path $TempProject 'android') -Destination $ProjectRoot -Recurse -Force
    }
    finally {
        if (Test-Path $TempRoot) { Remove-Item $TempRoot -Recurse -Force }
    }
}

$Manifest = Join-Path $AndroidDir 'app\src\main\AndroidManifest.xml'
if (Test-Path $Manifest) {
    $Content = Get-Content $Manifest -Raw
    if ($Content -notmatch 'android.permission.INTERNET') {
        $ManifestReplacement = '<manifest$1>' + "`r`n    <uses-permission android:name=`"android.permission.INTERNET`" />"
        $Content = $Content -replace '<manifest([^>]*)>', $ManifestReplacement
    }
    $Content = $Content -replace 'android:label="housing_mobile"', 'android:label="إدارة الشؤون - السكن"'
    Set-Content -Path $Manifest -Value $Content -Encoding UTF8
}

Push-Location $ProjectRoot
try {
    Write-Host 'تنزيل حزم Flutter...' -ForegroundColor Cyan
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'فشل flutter pub get.' }
    Write-Host 'اكتمل تجهيز المشروع. نفّذ flutter run لتشغيله على الهاتف أو المحاكي.' -ForegroundColor Green
}
finally {
    Pop-Location
}
