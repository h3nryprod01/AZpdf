# AZpdf - QA smoke test cho Windows 11.
#
# Chay trong PowerShell tai thu muc repo:   powershell -ExecutionPolicy Bypass -File script\qa_windows_smoke.ps1
#
# THUC TE TRUOC KHI CHAY - doc ky:
#   * App macOS (target "AZpdf") bi chan boi "#if os(macOS)" trong Package.swift
#     => TREN WINDOWS KHONG CO APP GUI NAO cua AZpdf de test.
#   * Tren Windows chi build duoc: AZpdfCore + azpdf-engine (CLI).
#     Phan GUI phai la Flutter shell o Shell\azpdf_desktop (co scaffolding windows\ nhung CHUA duoc kiem chung).
#   * Vi vay script nay test PHAN LOI (engine). Neu build fail thi do la ket qua hop le
#     va can bao lai - Windows dang o giai doan roadmap, chua tung build thanh cong.
#
# Script chi DOC repo va ghi file tam vao $Out. Khong sua source, khong commit.
# Cuoi cung se in bang tong ket - copy nguyen phan do gui lai.

$ErrorActionPreference = "Continue"
$Repo = if ($env:REPO) { $env:REPO } else { (Resolve-Path "$PSScriptRoot\..").Path }
$Out  = if ($env:OUT)  { $env:OUT }  else { Join-Path $env:TEMP "azpdf-qa-windows" }
$Fx   = Join-Path $Repo "Tests\Fixtures\generated"
New-Item -ItemType Directory -Force -Path $Out | Out-Null

$script:Pass = 0; $script:Fail = 0; $script:Skip = 0
$script:Results = @()
function Ok   ($m)      { $script:Results += "PASS  $m"; $script:Pass++ }
function Bad  ($m,$d="") { $script:Results += ("FAIL  $m" + $(if($d){"  -> $d"})); $script:Fail++ }
function Skip ($m,$d="") { $script:Results += ("SKIP  $m" + $(if($d){"  ($d)"})); $script:Skip++ }
function Section($t)    { Write-Host "`n== $t ==" -ForegroundColor Cyan }

# Chay 1 lenh engine, PASS neu exit 0 VA output chua "ok":true
function Engine($label, [string[]]$EngineArgs) {
    $o = & $script:EnginePath @EngineArgs 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -and $o -match '"ok":true') { Ok $label }
    else { Bad $label ("exit=$LASTEXITCODE " + $o.Substring(0, [Math]::Min(160, $o.Length))) }
}

Section "1. Prerequisites"
foreach ($t in @("swift","flutter")) {
    $c = Get-Command $t -ErrorAction SilentlyContinue
    if ($c) { Ok "co $t ($($c.Source))" } else {
        if ($t -eq "swift") { Bad "thieu swift" "cai Swift for Windows: https://swift.org/install/windows" }
        else { Skip "flutter" "chi can cho GUI shell" }
    }
}
if (-not (Get-Command swift -ErrorAction SilentlyContinue)) {
    Write-Host "`nKhong co swift - dung." -ForegroundColor Red; exit 2
}

Section "2. Build engine CLI (buoc de vo nhat tren Windows)"
$build = & swift build --package-path $Repo --product azpdf-engine 2>&1 | Out-String
Write-Host ($build.Substring(0, [Math]::Min(600, $build.Length)))
$script:EnginePath = $null
if ($LASTEXITCODE -eq 0) {
    $bin = (& swift build --package-path $Repo --show-bin-path 2>$null | Out-String).Trim()
    $cand = Join-Path $bin "azpdf-engine.exe"
    if (Test-Path $cand) { $script:EnginePath = $cand; Ok "build azpdf-engine.exe" }
    else { Bad "build azpdf-engine" "khong thay binary tai $cand" }
} else {
    Bad "build azpdf-engine" "swift build loi - CHEP TOAN BO LOI O TREN gui lai"
}
if (-not $script:EnginePath) {
    Write-Host "`nKhong build duoc engine tren Windows. Day la ket qua hop le can bao lai." -ForegroundColor Yellow
    Write-Host "PASS=$script:Pass FAIL=$script:Fail SKIP=$script:Skip"
    $script:Results | ForEach-Object { Write-Host $_ }
    exit 1
}

Section "3. PDF mau"
$doc = Join-Path $Fx "multipage.pdf"
if (-not (Test-Path $doc)) { $doc = Join-Path $Fx "basic.pdf" }
if (Test-Path $doc) { Ok "co PDF mau: $(Split-Path $doc -Leaf)" }
else {
    Bad "thieu PDF mau" "chep thu muc Tests\Fixtures\generated tu may mac sang, roi chay lai"
    Write-Host "`nThieu fixtures - dung." -ForegroundColor Yellow; exit 2
}

Section "4. Engine - luong doc"
Engine "health"        @("health")
Engine "info"          @("info","--document",$doc)
Engine "page (0)"      @("page","--document",$doc,"--page","0")
Engine "text (0)"      @("text","--document",$doc,"--page","0")
Engine "search"        @("search","--document",$doc,"--query","the")
Engine "annotations"   @("annotations","--document",$doc,"--page","0")
Engine "render -> PNG" @("render","--document",$doc,"--page","0","--scale","1","--output",(Join-Path $Out "render.png"))
if ((Test-Path (Join-Path $Out "render.png")) -and (Get-Item (Join-Path $Out "render.png")).Length -gt 0) {
    Ok "render tao file khong rong"
} else { Bad "render tao file" "file rong/khong co" }

Section "5. Engine - DocumentIR"
Engine "ir-baseline"    @("ir-baseline","--document",$doc,"--output",(Join-Path $Out "ir.json"))
Engine "ir-validate"    @("ir-validate","--input",(Join-Path $Out "ir.json"))
Engine "ir-export-text" @("ir-export-text","--input",(Join-Path $Out "ir.json"),"--output",(Join-Path $Out "ir.txt"))

Section "6. Engine - ghi"
Engine "save-as" @("save-as","--document",$doc,"--output",(Join-Path $Out "copy.pdf"))

Section "7. Xu ly loi (phai fail DUNG cach)"
$o = & $script:EnginePath 2>&1 | Out-String
if ($o -match '"ok":false') { Ok "khong tham so -> envelope loi" } else { Bad "khong tham so" $o.Substring(0,[Math]::Min(120,$o.Length)) }
$o = & $script:EnginePath "lenh-khong-ton-tai" "--document" $doc 2>&1 | Out-String
if ($o -match '"ok":false') { Ok "lenh sai -> envelope loi" } else { Bad "lenh sai" $o.Substring(0,[Math]::Min(120,$o.Length)) }

Section "8. Flutter Windows shell (GUI - chua tung kiem chung)"
if (Get-Command flutter -ErrorAction SilentlyContinue) {
    Push-Location (Join-Path $Repo "Shell\azpdf_desktop")
    $fb = & flutter build windows --debug 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) { Ok "flutter build windows" } else { Bad "flutter build windows" ("CHEP LOI: " + $fb.Substring(0,[Math]::Min(300,$fb.Length))) }
    Pop-Location
} else { Skip "flutter build windows" "chua cai flutter" }

Write-Host "`n===== TONG KET (copy phan nay gui lai) =====" -ForegroundColor Green
Write-Host ("AZpdf QA Windows - " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + " - " + [System.Environment]::OSVersion.VersionString)
Write-Host "repo=$Repo`n"
$script:Results | ForEach-Object { Write-Host $_ }
Write-Host "`nPASS=$script:Pass  FAIL=$script:Fail  SKIP=$script:Skip"
Write-Host "Artifacts: $Out"

Write-Host @"

===== CHECKLIST GUI (chi lam duoc NEU flutter build windows thanh cong) =====
 1. App co mo len khong? Co crash luc khoi dong khong?
 2. Mo PDF bang nut trong app -> duoc khong?
 3. Double-click PDF trong Explorer -> co mo bang AZpdf khong?   [macOS FAIL muc nay]
 4. O TIM KIEM co nhin thay khong? Ctrl+F co mo khong?           [macOS FAIL muc nay]
 5. Nut ZOOM +/- va "vua trang" co nhin thay khong?              [macOS FAIL muc nay]
 6. Dieu huong trang co dung so trang khong?
 7. Muc luc + thumbnail co hien khong?
 8. Mo encrypted.pdf (mat khau: secret) -> co hoi mat khau khong?
 9. Boi den text -> copy duoc khong?
10. Toolbar co bi tran/che mat nut nao khong?
"@
