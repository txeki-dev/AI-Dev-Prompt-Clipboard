Set WshShell = CreateObject("WScript.Shell")
Set FSO = CreateObject("Scripting.FileSystemObject")
scriptDir = FSO.GetParentFolderName(WScript.ScriptFullName)

args = ""
For Each arg In WScript.Arguments
    cleanArg = Replace(arg, """", """""")
    args = args & " """ & cleanArg & """"
Next

cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File """ & scriptDir & "\app.ps1""" & args
WshShell.Run cmd, 0, False

