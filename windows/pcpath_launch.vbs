' PCPath silent launcher
' Runs a PowerShell script with zero visible console window.
' Usage: wscript.exe pcpath_launch.vbs <script.ps1> [args...]

Option Explicit

If WScript.Arguments.Count = 0 Then
    WScript.Quit 1
End If

Dim sh, cmd, i
Set sh = CreateObject("WScript.Shell")

cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File"
For i = 0 To WScript.Arguments.Count - 1
    cmd = cmd & " """ & WScript.Arguments(i) & """"
Next

' 0 = hidden window, False = don't wait
sh.Run cmd, 0, False
