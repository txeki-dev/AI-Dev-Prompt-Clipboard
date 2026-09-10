Set WshShell = CreateObject("WScript.Shell")
Set FSO = CreateObject("Scripting.FileSystemObject")
scriptDir = FSO.GetParentFolderName(WScript.ScriptFullName)

args = ""
For Each arg In WScript.Arguments
    If InStr(arg, " ") > 0 Then
        args = args & " """ & arg & """"
    Else
        args = args & " " & arg
    End If
Next

cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File """ & scriptDir & "\app.ps1""" & args
WshShell.Run cmd, 0, False
