; PCPath Installer for Windows
; Build: makensis windows\PCPathInstall.nsi  (any working directory)

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "WordFunc.nsh"

;--------------------------------
; Semantic version — bump manually for releases.
!define PCPATH_VERSION "2.1"

; Build stamp — auto-updated every makensis run so you can verify which build
; is installed. Format: YYYY.MM.DD.HHMM
!define /date PCPATH_BUILD "%Y.%m.%d.%H%M"

;--------------------------------
; Metadata
Name "PCPath ${PCPATH_VERSION}"
OutFile "${__FILEDIR__}\PCPathInstall.exe"
RequestExecutionLevel user
SetCompressor /SOLID lzma
Unicode True
BrandingText "PCPath ${PCPATH_VERSION}  (build ${PCPATH_BUILD})"

VIProductVersion "2.0.0.0"
VIAddVersionKey  "ProductName"     "PCPath"
VIAddVersionKey  "ProductVersion"  "${PCPATH_VERSION} (${PCPATH_BUILD})"
VIAddVersionKey  "FileVersion"     "${PCPATH_VERSION} (${PCPATH_BUILD})"
VIAddVersionKey  "FileDescription" "PCPath Installer"
VIAddVersionKey  "CompanyName"     "CREATE"
VIAddVersionKey  "LegalCopyright"  "CREATE"

;--------------------------------
; State carried between .onInit and the Install section
Var PreviousVersion
Var IsUpdate

;--------------------------------
; MUI Settings
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_TITLE_3LINES
!define MUI_FINISHPAGE_TITLE "PCPath ${PCPATH_VERSION} Installed"
!define MUI_FINISHPAGE_TEXT "PCPath ${PCPATH_VERSION} (build ${PCPATH_BUILD}) is now active.$\r$\n$\r$\nContext menu actions (grouped at top of right-click menu):$\r$\n  - Copy as Mac Path  (file or folder)$\r$\n  - Copy as Path  (file or folder, Windows path)$\r$\n  - Copy Names  (file or folder)$\r$\n  - Convert to PC Path  (empty space or desktop)$\r$\n$\r$\nDrive mappings: $PROFILE\.pcpath_mappings$\r$\nInstall log: $PROFILE\.pcpath\install.log"

!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

;--------------------------------
; Detect previous install before any pages run
Function .onInit
    StrCpy $IsUpdate "0"
    StrCpy $PreviousVersion ""
    ReadRegStr $PreviousVersion HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath" "DisplayVersion"
    ${If} $PreviousVersion != ""
        StrCpy $IsUpdate "1"
    ${Else}
        ; Older builds may have an install marker without DisplayVersion
        ReadRegStr $0 HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath" "DisplayName"
        ${If} $0 != ""
            StrCpy $IsUpdate "1"
            StrCpy $PreviousVersion "(unknown earlier build)"
        ${EndIf}
    ${EndIf}
FunctionEnd

;--------------------------------
; Install
Section "Install"

    ${If} $IsUpdate == "1"
        DetailPrint "Updating PCPath: $PreviousVersion -> ${PCPATH_VERSION} (build ${PCPATH_BUILD})"
        ; Clean stale scripts so a leftover file from a previous build can't
        ; shadow renamed/removed scripts. Config and uninstall.exe are kept.
        Delete "$PROFILE\.pcpath\*.ps1"
    ${Else}
        DetailPrint "Installing PCPath ${PCPATH_VERSION} (build ${PCPATH_BUILD})"
    ${EndIf}

    ; Install directory and runtime scripts
    CreateDirectory "$PROFILE\.pcpath"
    SetOutPath "$PROFILE\.pcpath"
    File "${__FILEDIR__}\pcpath_common.ps1"
    File "${__FILEDIR__}\copy_mac_path.ps1"
    File "${__FILEDIR__}\convert_to_pc_path.ps1"
    File "${__FILEDIR__}\copy_names.ps1"
    File "${__FILEDIR__}\copy_path.ps1"
    File "${__FILEDIR__}\pcpath_launch.vbs"

    ; Write version stamp so users can confirm which build is installed
    FileOpen  $0 "$PROFILE\.pcpath\version.txt" w
    FileWrite $0 "PCPath ${PCPATH_VERSION}$\r$\nbuild ${PCPATH_BUILD}$\r$\n"
    FileClose $0

    ; Append a line to the install log
    FileOpen  $0 "$PROFILE\.pcpath\install.log" a
    FileSeek  $0 0 END
    ${If} $IsUpdate == "1"
        FileWrite $0 "${PCPATH_BUILD}  update from $PreviousVersion to ${PCPATH_VERSION} (build ${PCPATH_BUILD})$\r$\n"
    ${Else}
        FileWrite $0 "${PCPATH_BUILD}  install ${PCPATH_VERSION} (build ${PCPATH_BUILD})$\r$\n"
    ${EndIf}
    FileClose $0

    ; Default config — only write if not present (preserves user customizations on reinstall)
    ${IfNot} ${FileExists} "$PROFILE\.pcpath_mappings"
        SetOutPath "$PROFILE"
        File /oname=.pcpath_mappings "${__FILEDIR__}\..\pcpath_mappings.default"
        SetOutPath "$PROFILE\.pcpath"
    ${EndIf}

    ; Register uninstaller in Add/Remove Programs (HKCU works on Windows 8+)
    WriteUninstaller "$PROFILE\.pcpath\uninstall.exe"
    WriteRegStr  HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath" "DisplayName"     "PCPath ${PCPATH_VERSION}"
    WriteRegStr  HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath" "DisplayVersion"  "${PCPATH_VERSION} (${PCPATH_BUILD})"
    WriteRegStr  HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath" "UninstallString" '"$PROFILE\.pcpath\uninstall.exe"'
    WriteRegStr  HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath" "DisplayIcon"     "shell32.dll,134"
    WriteRegStr  HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath" "Publisher"       "CREATE"
    WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath" "NoModify"       1
    WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath" "NoRepair"       1

    ; All verbs go through pcpath_launch.vbs so the PowerShell console is
    ; fully hidden (no flash). File/folder verbs also set MultiSelectModel
    ; = Player so Windows invokes the verb once for the whole selection
    ; instead of once per file. Position = Top groups all PCPath verbs at
    ; the top of the legacy right-click menu.

    ; Context menu: Copy as Mac Path — files
    WriteRegStr HKCU "Software\Classes\*\shell\CopyAsMacPath"          ""                 "Copy as Mac Path"
    WriteRegStr HKCU "Software\Classes\*\shell\CopyAsMacPath"          "Icon"             "shell32.dll,134"
    WriteRegStr HKCU "Software\Classes\*\shell\CopyAsMacPath"          "MultiSelectModel" "Player"
    WriteRegStr HKCU "Software\Classes\*\shell\CopyAsMacPath"          "Position"         "Top"
    WriteRegStr HKCU "Software\Classes\*\shell\CopyAsMacPath\command"  ""                 \
        'wscript.exe "$PROFILE\.pcpath\pcpath_launch.vbs" "$PROFILE\.pcpath\copy_mac_path.ps1" "%1"'

    ; Context menu: Copy as Mac Path — directories
    WriteRegStr HKCU "Software\Classes\Directory\shell\CopyAsMacPath"          ""                 "Copy as Mac Path"
    WriteRegStr HKCU "Software\Classes\Directory\shell\CopyAsMacPath"          "Icon"             "shell32.dll,134"
    WriteRegStr HKCU "Software\Classes\Directory\shell\CopyAsMacPath"          "MultiSelectModel" "Player"
    WriteRegStr HKCU "Software\Classes\Directory\shell\CopyAsMacPath"          "Position"         "Top"
    WriteRegStr HKCU "Software\Classes\Directory\shell\CopyAsMacPath\command"  ""                 \
        'wscript.exe "$PROFILE\.pcpath\pcpath_launch.vbs" "$PROFILE\.pcpath\copy_mac_path.ps1" "%1"'

    ; Context menu: Copy as Mac Path — directory background
    WriteRegStr HKCU "Software\Classes\Directory\Background\shell\CopyAsMacPath"          ""         "Copy as Mac Path"
    WriteRegStr HKCU "Software\Classes\Directory\Background\shell\CopyAsMacPath"          "Icon"     "shell32.dll,134"
    WriteRegStr HKCU "Software\Classes\Directory\Background\shell\CopyAsMacPath"          "Position" "Top"
    WriteRegStr HKCU "Software\Classes\Directory\Background\shell\CopyAsMacPath\command"  ""         \
        'wscript.exe "$PROFILE\.pcpath\pcpath_launch.vbs" "$PROFILE\.pcpath\copy_mac_path.ps1" "%V"'

    ; Context menu: Convert to PC Path — directory background
    WriteRegStr HKCU "Software\Classes\Directory\Background\shell\ConvertToPCPath"          ""         "Convert to PC Path"
    WriteRegStr HKCU "Software\Classes\Directory\Background\shell\ConvertToPCPath"          "Icon"     "shell32.dll,134"
    WriteRegStr HKCU "Software\Classes\Directory\Background\shell\ConvertToPCPath"          "Position" "Top"
    WriteRegStr HKCU "Software\Classes\Directory\Background\shell\ConvertToPCPath\command"  ""         \
        'wscript.exe "$PROFILE\.pcpath\pcpath_launch.vbs" "$PROFILE\.pcpath\convert_to_pc_path.ps1"'

    ; Context menu: Convert to PC Path — desktop background
    WriteRegStr HKCU "Software\Classes\DesktopBackground\shell\ConvertToPCPath"          ""         "Convert to PC Path"
    WriteRegStr HKCU "Software\Classes\DesktopBackground\shell\ConvertToPCPath"          "Icon"     "shell32.dll,134"
    WriteRegStr HKCU "Software\Classes\DesktopBackground\shell\ConvertToPCPath"          "Position" "Top"
    WriteRegStr HKCU "Software\Classes\DesktopBackground\shell\ConvertToPCPath\command"  ""         \
        'wscript.exe "$PROFILE\.pcpath\pcpath_launch.vbs" "$PROFILE\.pcpath\convert_to_pc_path.ps1"'

    ; Context menu: Copy Names — files
    WriteRegStr HKCU "Software\Classes\*\shell\CopyNames"          ""                 "Copy Names"
    WriteRegStr HKCU "Software\Classes\*\shell\CopyNames"          "Icon"             "shell32.dll,134"
    WriteRegStr HKCU "Software\Classes\*\shell\CopyNames"          "MultiSelectModel" "Player"
    WriteRegStr HKCU "Software\Classes\*\shell\CopyNames"          "Position"         "Top"
    WriteRegStr HKCU "Software\Classes\*\shell\CopyNames\command"  ""                 \
        'wscript.exe "$PROFILE\.pcpath\pcpath_launch.vbs" "$PROFILE\.pcpath\copy_names.ps1" "%1"'

    ; Context menu: Copy Names — directories
    WriteRegStr HKCU "Software\Classes\Directory\shell\CopyNames"          ""                 "Copy Names"
    WriteRegStr HKCU "Software\Classes\Directory\shell\CopyNames"          "Icon"             "shell32.dll,134"
    WriteRegStr HKCU "Software\Classes\Directory\shell\CopyNames"          "MultiSelectModel" "Player"
    WriteRegStr HKCU "Software\Classes\Directory\shell\CopyNames"          "Position"         "Top"
    WriteRegStr HKCU "Software\Classes\Directory\shell\CopyNames\command"  ""                 \
        'wscript.exe "$PROFILE\.pcpath\pcpath_launch.vbs" "$PROFILE\.pcpath\copy_names.ps1" "%1"'

    ; Context menu: Copy as Path — files
    WriteRegStr HKCU "Software\Classes\*\shell\CopyAsPath"          ""                 "Copy as Path"
    WriteRegStr HKCU "Software\Classes\*\shell\CopyAsPath"          "Icon"             "shell32.dll,134"
    WriteRegStr HKCU "Software\Classes\*\shell\CopyAsPath"          "MultiSelectModel" "Player"
    WriteRegStr HKCU "Software\Classes\*\shell\CopyAsPath"          "Position"         "Top"
    WriteRegStr HKCU "Software\Classes\*\shell\CopyAsPath\command"  ""                 \
        'wscript.exe "$PROFILE\.pcpath\pcpath_launch.vbs" "$PROFILE\.pcpath\copy_path.ps1" "%1"'

    ; Context menu: Copy as Path — directories
    WriteRegStr HKCU "Software\Classes\Directory\shell\CopyAsPath"          ""                 "Copy as Path"
    WriteRegStr HKCU "Software\Classes\Directory\shell\CopyAsPath"          "Icon"             "shell32.dll,134"
    WriteRegStr HKCU "Software\Classes\Directory\shell\CopyAsPath"          "MultiSelectModel" "Player"
    WriteRegStr HKCU "Software\Classes\Directory\shell\CopyAsPath"          "Position"         "Top"
    WriteRegStr HKCU "Software\Classes\Directory\shell\CopyAsPath\command"  ""                 \
        'wscript.exe "$PROFILE\.pcpath\pcpath_launch.vbs" "$PROFILE\.pcpath\copy_path.ps1" "%1"'

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
    DeleteRegKey HKCU "Software\Classes\*\shell\CopyNames"
    DeleteRegKey HKCU "Software\Classes\Directory\shell\CopyNames"
    DeleteRegKey HKCU "Software\Classes\*\shell\CopyAsPath"
    DeleteRegKey HKCU "Software\Classes\Directory\shell\CopyAsPath"

    ; Remove install directory — preserves $PROFILE\.pcpath_mappings intentionally
    RMDir /r "$PROFILE\.pcpath"

    ; Remove Add/Remove Programs entry
    DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\PCPath"

SectionEnd
