; PCPath Installer for Windows
; Build: makensis windows\PCPathInstall.nsi  (any working directory)

!include "MUI2.nsh"
!include "LogicLib.nsh"

;--------------------------------
; Metadata
Name "PCPath"
OutFile "${__FILEDIR__}\PCPathInstall.exe"
RequestExecutionLevel user
SetCompressor /SOLID lzma
Unicode True

;--------------------------------
; MUI Settings
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_TITLE "PCPath Installed"
!define MUI_FINISHPAGE_TEXT "PCPath is now active.$\r$\n$\r$\nRight-click any file or folder: Copy as Mac Path$\r$\nRight-click empty space or desktop: Convert to PC Path$\r$\n$\r$\nDrive mappings: $PROFILE\.pcpath_mappings"

!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

;--------------------------------
; Install
Section "Install"

    ; Install directory and runtime scripts
    CreateDirectory "$PROFILE\.pcpath"
    SetOutPath "$PROFILE\.pcpath"
    File "${__FILEDIR__}\pcpath_common.ps1"
    File "${__FILEDIR__}\copy_mac_path.ps1"
    File "${__FILEDIR__}\convert_to_pc_path.ps1"

    ; Default config — only write if not present (preserves user customizations on reinstall)
    ${IfNot} ${FileExists} "$PROFILE\.pcpath_mappings"
        SetOutPath "$PROFILE"
        File /oname=.pcpath_mappings "${__FILEDIR__}\..\pcpath_mappings.default"
        SetOutPath "$PROFILE\.pcpath"
    ${EndIf}

    ; Register uninstaller in Add/Remove Programs (HKCU works on Windows 8+)
    WriteUninstaller "$PROFILE\.pcpath\uninstall.exe"
    WriteRegStr  HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath" "DisplayName"     "PCPath"
    WriteRegStr  HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath" "UninstallString" '"$PROFILE\.pcpath\uninstall.exe"'
    WriteRegStr  HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath" "DisplayIcon"     "shell32.dll,134"
    WriteRegStr  HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath" "Publisher"       "CREATE"
    WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath" "NoModify"       1
    WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath" "NoRepair"       1

    ; Context menu: Copy as Mac Path — files
    WriteRegStr HKCU "Software\Classes\*\shell\CopyAsMacPath"          ""     "Copy as Mac Path"
    WriteRegStr HKCU "Software\Classes\*\shell\CopyAsMacPath"          "Icon" "shell32.dll,134"
    WriteRegStr HKCU "Software\Classes\*\shell\CopyAsMacPath\command"  ""     \
        'powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "$PROFILE\.pcpath\copy_mac_path.ps1" "%1"'

    ; Context menu: Copy as Mac Path — directories
    WriteRegStr HKCU "Software\Classes\Directory\shell\CopyAsMacPath"          ""     "Copy as Mac Path"
    WriteRegStr HKCU "Software\Classes\Directory\shell\CopyAsMacPath"          "Icon" "shell32.dll,134"
    WriteRegStr HKCU "Software\Classes\Directory\shell\CopyAsMacPath\command"  ""     \
        'powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "$PROFILE\.pcpath\copy_mac_path.ps1" "%V"'

    ; Context menu: Copy as Mac Path — directory background
    WriteRegStr HKCU "Software\Classes\Directory\Background\shell\CopyAsMacPath"          ""     "Copy as Mac Path"
    WriteRegStr HKCU "Software\Classes\Directory\Background\shell\CopyAsMacPath"          "Icon" "shell32.dll,134"
    WriteRegStr HKCU "Software\Classes\Directory\Background\shell\CopyAsMacPath\command"  ""     \
        'powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "$PROFILE\.pcpath\copy_mac_path.ps1" "%V"'

    ; Context menu: Convert to PC Path — directory background
    WriteRegStr HKCU "Software\Classes\Directory\Background\shell\ConvertToPCPath"          ""     "Convert to PC Path"
    WriteRegStr HKCU "Software\Classes\Directory\Background\shell\ConvertToPCPath"          "Icon" "shell32.dll,134"
    WriteRegStr HKCU "Software\Classes\Directory\Background\shell\ConvertToPCPath\command"  ""     \
        'powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "$PROFILE\.pcpath\convert_to_pc_path.ps1"'

    ; Context menu: Convert to PC Path — desktop background
    WriteRegStr HKCU "Software\Classes\DesktopBackground\shell\ConvertToPCPath"          ""     "Convert to PC Path"
    WriteRegStr HKCU "Software\Classes\DesktopBackground\shell\ConvertToPCPath"          "Icon" "shell32.dll,134"
    WriteRegStr HKCU "Software\Classes\DesktopBackground\shell\ConvertToPCPath\command"  ""     \
        'powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "$PROFILE\.pcpath\convert_to_pc_path.ps1"'

SectionEnd

;--------------------------------
; Uninstall
Section "Uninstall"

    ; Remove context menu registry keys
    DeleteRegKey HKCU "Software\Classes\*\shell\CopyAsMacPath"
    DeleteRegKey HKCU "Software\Classes\Directory\shell\CopyAsMacPath"
    DeleteRegKey HKCU "Software\Classes\Directory\Background\shell\CopyAsMacPath"
    DeleteRegKey HKCU "Software\Classes\Directory\Background\shell\ConvertToPCPath"
    DeleteRegKey HKCU "Software\Classes\DesktopBackground\shell\ConvertToPCPath"

    ; Remove install directory — preserves $PROFILE\.pcpath_mappings intentionally
    RMDir /r "$PROFILE\.pcpath"

    ; Remove Add/Remove Programs entry
    DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath"

SectionEnd
