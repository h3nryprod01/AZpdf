; Bộ cài Windows cho AZpdf — NSIS.
;
; Vì sao NSIS chứ không phải MSI (WiX), quyết định ghi tại chỗ theo lệ của repo:
;   1. Người dùng đích là CÁ NHÂN tải setup.exe từ GitHub — không phải IT triển khai GPO,
;      thứ duy nhất MSI hơn hẳn. Mục tiêu dự án là "cài đơn giản nhất có thể".
;   2. Toàn bộ payload là file chép vào một thư mục + shortcut + mục uninstall. Không service,
;      không COM, không policy — phần khó của MSI không mua được gì ở đây.
;   3. makensis có sẵn trên runner windows-2022 của GitHub; WiX phải cài qua dotnet tool.
; MSI mở lại khi có yêu cầu doanh nghiệp thật.
;
; Build:  makensis /DVERSION=x.y.z /DSTAGE=đường-dẫn-stage script\azpdf_installer.nsi
; Cài im lặng:  AZpdf-Setup-x.y.z.exe /S [/D=C:\đường-cài]   (CI dùng đúng đường này để kiểm)

!include "MUI2.nsh"

!ifndef VERSION
  !error "Thiếu /DVERSION — tránh sinh installer không rõ phiên bản"
!endif
!ifndef STAGE
  !error "Thiếu /DSTAGE — thư mục chứa payload đã ghép (AZpdf.exe, azpdf-engine.exe, mutool.exe, ...)"
!endif

Name "AZpdf ${VERSION}"
OutFile "AZpdf-Setup-${VERSION}.exe"
Unicode true
; Per-user, KHÔNG đòi admin: bớt một hộp thoại UAC — đúng nghĩa "cài đơn giản nhất".
; Đổi lại: cài vào LocalAppData\Programs (chuẩn per-user của Microsoft, VS Code làm y hệt).
RequestExecutionLevel user
InstallDir "$LOCALAPPDATA\Programs\AZpdf"

!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\AZpdf"

!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "AZpdf"
  SetOutPath "$INSTDIR"
  File /r "${STAGE}\*.*"

  ; Shortcut Start Menu — lý do chính để có bộ cài thay vì zip.
  CreateShortCut "$SMPROGRAMS\AZpdf.lnk" "$INSTDIR\AZpdf.exe"

  WriteUninstaller "$INSTDIR\Uninstall.exe"
  ; Mục Add/Remove Programs (HKCU vì per-user) — gỡ được như mọi app tử tế.
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayName" "AZpdf"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINST_KEY}" "Publisher" "AZpdf (AGPL-3.0)"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\AZpdf.exe"
  WriteRegStr HKCU "${UNINST_KEY}" "UninstallString" "$\"$INSTDIR\Uninstall.exe$\""
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoRepair" 1
SectionEnd

Section "Uninstall"
  Delete "$SMPROGRAMS\AZpdf.lnk"
  ; Chỉ xoá thư mục cài — KHÔNG đụng dữ liệu người dùng hay tài liệu đã mở.
  RMDir /r "$INSTDIR"
  DeleteRegKey HKCU "${UNINST_KEY}"
SectionEnd
