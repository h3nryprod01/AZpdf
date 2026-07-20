# AZpdf - bootstrap QA cho Windows.
#
# Chay 1 dong duy nhat trong PowerShell (khong can Admin):
#
#   iwr -useb https://raw.githubusercontent.com/h3nryprod01/AZpdf/main/script/qa_windows_bootstrap.ps1 | iex
#
# Script tu: kiem tra toolchain -> clone repo -> chay qa_windows_smoke.ps1 -> in tong ket.
# Chi ghi vao %TEMP%\azpdf-qa. Khong sua he thong, khong cai gi ngam.
#
# THUC TE: target "AZpdf" (app GUI macOS) bi chan boi #if os(macOS), nen tren Windows
# chi build duoc AZpdfCore + azpdf-engine (CLI). Neu thieu Swift, script bao ro va dung.

$ErrorActionPreference = "Continue"
$Work = Join-Path $env:TEMP "azpdf-qa"
New-Item -ItemType Directory -Force -Path $Work | Out-Null

function Line($t) { Write-Host ("-" * 60); Write-Host $t -ForegroundColor Cyan; Write-Host ("-" * 60) }

Line "1. Kiem tra toolchain"
$missing = @()
foreach ($t in @("git","swift")) {
    $c = Get-Command $t -ErrorAction SilentlyContinue
    if ($c) { Write-Host "  OK   $t -> $($c.Source)" -ForegroundColor Green }
    else    { Write-Host "  THIEU $t" -ForegroundColor Red; $missing += $t }
}

if ($missing -contains "git") {
    Write-Host "`nCan git: winget install --id Git.Git -e" -ForegroundColor Yellow
    return
}
if ($missing -contains "swift") {
    Write-Host @"

Can Swift for Windows. Cai bang mot trong hai cach:
  winget install --id Swift.Toolchain -e
  hoac tai tai https://www.swift.org/install/windows/

Luu y: Swift tren Windows con can Visual Studio Build Tools (C++ workload).
Sau khi cai xong, MO LAI PowerShell roi chay lai dong lenh bootstrap.
"@ -ForegroundColor Yellow
    Write-Host "Ket qua hop le can bao lai: 'Windows chua co Swift toolchain'." -ForegroundColor Yellow
    return
}

Line "2. Clone repo (nhanh main)"
$Repo = Join-Path $Work "AZpdf"
if (Test-Path $Repo) { Remove-Item -Recurse -Force $Repo }
git clone --depth 1 https://github.com/h3nryprod01/AZpdf.git $Repo 2>&1 | Select-Object -Last 3
if (-not (Test-Path (Join-Path $Repo "Package.swift"))) {
    Write-Host "Clone that bai." -ForegroundColor Red; return
}
Write-Host "  commit: $(git -C $Repo log --oneline -1)" -ForegroundColor Green

Line "3. PDF mau"
# Windows khong co mutool, nen dung fixture nguon co san trong repo neu can.
$Fx = Join-Path $Repo "Tests\Fixtures\generated"
New-Item -ItemType Directory -Force -Path $Fx | Out-Null
if (-not (Get-ChildItem $Fx -Filter *.pdf -ErrorAction SilentlyContinue)) {
    Write-Host "  Chua co PDF mau. Kit se bao thieu fixture va dung o buoc do." -ForegroundColor Yellow
    Write-Host "  Cach nhanh: chep thu muc Tests\Fixtures\generated tu may mac sang $Fx" -ForegroundColor Yellow
}

Line "4. Chay kit QA"
$Kit = Join-Path $Repo "script\qa_windows_smoke.ps1"
if (-not (Test-Path $Kit)) { Write-Host "Khong thay $Kit" -ForegroundColor Red; return }
& powershell -ExecutionPolicy Bypass -File $Kit

Line "XONG"
Write-Host "Copy toan bo phan 'TONG KET' o tren gui lai de phan tich." -ForegroundColor Cyan
