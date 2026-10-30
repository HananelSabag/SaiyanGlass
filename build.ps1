# Builds SaiyanGlass with the MSVC toolset and Windows SDK (no CMake needed).
#
#   .\build.ps1                 Release build into out\Release
#   .\build.ps1 -Config Debug
#   .\build.ps1 -Install        build, then install for the current user
#
# Requirements: Visual Studio 2022+ (or Build Tools) with
#   Microsoft.VisualStudio.Component.VC.Tools.x86.x64 and a Windows 11 SDK.
param(
    [ValidateSet('Release', 'Debug')][string]$Config = 'Release',
    [switch]$Install
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -latest -prerelease -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw 'MSVC x64 tools not found (install Microsoft.VisualStudio.Component.VC.Tools.x86.x64).' }
$env:PATH = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer;$env:PATH"  # vcvars calls vswhere
cmd /c "`"$vs\VC\Auxiliary\Build\vcvars64.bat`" >nul 2>nul && set" | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') { Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] }
}
$sdkInc = Join-Path $env:WindowsSdkDir "Include\$($env:WindowsSDKVersion.TrimEnd('\'))"

$out = Join-Path $root "out\$Config"
$obj = Join-Path $root "out\obj\$Config"
New-Item -ItemType Directory -Force $out, "$obj\host", "$obj\settings" | Out-Null

if (-not (Test-Path "$root\res\SaiyanGlass.ico")) { & "$root\tools\make-icon.ps1" | Out-Null }


$common = @('/nologo', '/std:c++20', '/EHsc', '/permissive-', '/utf-8', '/W3', '/Zi', '/MP',
    '/DUNICODE', '/D_UNICODE', '/DWIN32_LEAN_AND_MEAN', '/DNOMINMAX', '/D_WIN32_WINNT=0x0A00',
    "/I$sdkInc\cppwinrt")
$common += if ($Config -eq 'Release') { @('/O2', '/MT', '/DNDEBUG', '/Gw', '/Gy') } else { @('/Od', '/MTd', '/D_DEBUG') }
$linkCommon = @('/DEBUG', '/INCREMENTAL:NO')
if ($Config -eq 'Release') { $linkCommon += @('/OPT:REF', '/OPT:ICF') }

function Invoke-Tool([string]$exe, [string[]]$arguments) {
    $log = & $exe @arguments 2>&1 | ForEach-Object { "$_" }
    $log | Where-Object { $_ -match ': (fatal )?error|error LNK|warning C' } | Select-Object -First 40 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { throw "$exe failed ($LASTEXITCODE)" }
}

Write-Host "== resources"
Invoke-Tool rc.exe @('/nologo', '/fo', "$obj\app.res", "$root\res\app.rc")

Write-Host "== SaiyanGlass.exe"
$hostSrc = @('main', 'host', 'accent', 'translucenttb', 'install', 'ipc', 'util') | ForEach-Object { "$root\src\host\$_.cpp" }
Invoke-Tool cl.exe ($common + @("/Fo$obj\host\", "/Fd$obj\host\") + $hostSrc + @("$root\src\common\settings.cpp", "$obj\app.res", '/link') + $linkCommon +
    @('/SUBSYSTEM:WINDOWS', "/OUT:$out\SaiyanGlass.exe", "/PDB:$out\SaiyanGlass.pdb", '/MANIFEST:EMBED', "/MANIFESTINPUT:$root\res\app.manifest",
        'user32.lib', 'ole32.lib', 'shell32.lib', 'advapi32.lib', 'windowscodecs.lib', 'gdi32.lib'))

Write-Host "== SaiyanGlassSettings.exe"
Invoke-Tool cl.exe ($common + @("/Fo$obj\settings\", "/Fd$obj\settings\", "$root\src\settings\main.cpp", "$root\src\common\settings.cpp", "$obj\app.res", '/link') + $linkCommon +
    @('/SUBSYSTEM:WINDOWS', "/OUT:$out\SaiyanGlassSettings.exe", "/PDB:$out\SaiyanGlassSettings.pdb", '/MANIFEST:EMBED', "/MANIFESTINPUT:$root\res\app.manifest",
        'windowsapp.lib', 'user32.lib', 'ole32.lib', 'shell32.lib', 'dwmapi.lib', 'gdi32.lib'))

Get-ChildItem $out -Include *.exe, *.dll -Recurse | ForEach-Object { "{0,-26} {1,8:N0} KB" -f $_.Name, ($_.Length / 1KB) }
Write-Host "build ok -> $out"

if ($Install) {
    & "$out\SaiyanGlass.exe" --install | Out-String | Write-Host
}
