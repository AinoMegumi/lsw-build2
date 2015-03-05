Dim WshShell
Dim WshFS
Dim WshProcEnv
Dim system_architecture
Dim process_architecture
Dim script_folder
Dim url
Dim cmd1
Dim home_path

time_i= Now() 'benchmark timer

Set WshShell =  CreateObject("WScript.Shell")
Set WshProcEnv = WshShell.Environment("Process")
Set WshFS = CreateObject("Scripting.FileSystemObject")

'Check OS bitness
process_architecture= WshProcEnv("PROCESSOR_ARCHITECTURE") 

If process_architecture = "x86" Then    
    system_architecture= WshProcEnv("PROCESSOR_ARCHITEW6432")

    If system_architecture = ""  Then    
        system_architecture = "i686"
    End if    
Else    
    system_architecture = "x86_64"
End If

'Get script folder and set Current Dir
script_folder = WshFS.GetParentFolderName(WScript.ScriptFullName) 'No trailing slash
WshShell.CurrentDirectory = script_folder

'Fetch SourForge DL page
sf_base = "http://sourceforge.net/projects/msys2/files/Base/"
url = sf_base & system_architecture & "/"
cmd1 = """" & WshShell.CurrentDirectory & "\wget.vbs" & """" &" "& url & "  dlpage.html"
Call WshShell.Run(cmd1, 1, True)

'DL wget
If (Not WshFS.FileExists("wget.exe")) Then
wget_fetch="http://eternallybored.org/misc/wget/wget.exe wget.exe"
cmd1 = """" & WshShell.CurrentDirectory & "\wget.vbs" & """" &" "& wget_fetch
Call WshShell.Run(cmd1, 1, True)
End if

'Extract Link
Set myregex = New RegExp
myregex.IgnoreCase = True
myregex.Global = True
myregex.Pattern = "href=""(.*tar.xz/download)"
'WScript.Echo(myregex.Pattern)
html= WshFS.OpenTextFile("dlpage.html").ReadAll
Set rMatches = myregex.Execute(html)
url = rMatches.Item(0).Submatches(0)
'Download MSYS2
If (Not WshFS.FileExists("msys2.tar.xz")) Then
cmd1 = """" & WshShell.CurrentDirectory & "\wget.exe" & """" &" " & "" & url & "" & " -O msys2.tar.xz" 
'WScript.Echo(cmd1)
Call WshShell.Run(cmd1, 1, True)
End if

'DL 7-zip CLI
If (Not WshFS.FileExists("7za.exe")) Then
url = "http://downloads.sourceforge.net/sevenzip/7za920.zip"
cmd1 = """" & WshShell.CurrentDirectory & "\wget.exe" & """" &" " & "" & url & "" & " -O 7za920.zip"
'WScript.Echo(cmd1)
Call WshShell.Run(cmd1, 1, True)
End if
'Set oExec = WshShell.Exec(cmd1)
'WScript.Echo(oExec.ExitCode)

'Unzip
If (Not WshFS.FileExists("7za.exe")) Then
Set appShell = CreateObject("Shell.Application")
appShell.NameSpace(WshFS.GetAbsolutePathName(WshShell.CurrentDirectory)).CopyHere appShell.NameSpace(WshFS.GetAbsolutePathName("7za920.zip")).Items
Set appShell = Nothing
End if

'decompress tar.xz
cmd1 = "7za.exe x msys2.tar.xz -so | 7za.exe x -si -ttar -y"
Call WshShell.Run("%comspec% /c " & cmd1, 1, True)

'Set Env Vars in prep for MSYS
Set WshSysEnv= WshShell.Environment("PROCESS")
WshSysEnv("MSYSTEM") = "MSYS"
WshSysEnv("WD") = WshShell.CurrentDirectory & "\msys64\usr\bin\"
mintty_path= WshShell.CurrentDirectory & "\msys64\usr\bin\mintty.exe"
WshSysEnv("MSYSCON") = "mintty.exe"

Rem ************** Ready to Launch Mintty ***************************************
cmd1 = "" & mintty_path & "" & " --hold error -i /msys2.ico /usr/bin/bash --login"
WScript.Echo("Please close the MSYS2 Window when it becomes idle (Press OK to Proceed...)")
Call WshShell.Run(cmd1, 1, True) 'First-time launch
'Wait for MSYS to close
Set oWMISvc = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
boolRunning = False
Do While boolRunning
  Set colProc = oWMISvc.ExecQuery("SELECT * FROM Win32_Process WHERE Name='" & "mintty.exe" & "'")
  boolRunning = False
  For Each oProc In colProc
    boolRunning = True
  Next
  Set colProc = Nothing
  WScript.Sleep 500
Loop
'Set User MSYS home path
home_path = script_folder & "\msys64\home\" & WshSysEnv("USERNAME")
'Copy shell scripts to home
cmd1 = "copy /Y /B " & "" & script_folder & "\*.sh" & "" & " " & "" & home_path & "\" & ""
'WScript.Echo(cmd1)
Call WshShell.Run("%comspec% /c " & cmd1, 1, True)
'core update
cmd1 = "" & mintty_path & "" & " -i /msys2.ico /usr/bin/bash --login " & "" & home_path & "\coreupdate.sh" & ""
Call WshShell.Run(cmd1, 1, True) 'Do update
boolRunning = False 'wait
Do While boolRunning
  Set colProc = oWMISvc.ExecQuery("SELECT * FROM Win32_Process WHERE Name='" & "mintty.exe" & "'")
  boolRunning = False
  For Each oProc In colProc
    boolRunning = True
  Next
  Set colProc = Nothing
  WScript.Sleep 500
Loop
'install toolchain
cmd1 = "" & mintty_path & "" & " -i /msys2.ico /usr/bin/bash --login " & "" & home_path & "\inst_base.sh" & "" 
Call WshShell.Run(cmd1, 1, True) 'Do update
boolRunning = False 'wait
Do While boolRunning
  Set colProc = oWMISvc.ExecQuery("SELECT * FROM Win32_Process WHERE Name='" & "mintty.exe" & "'")
  boolRunning = False
  For Each oProc In colProc
    boolRunning = True
  Next
  Set colProc = Nothing
  WScript.Sleep 500
Loop

'Starts building
cmd1 = "" & mintty_path & "" & " --hold error -i /msys2.ico /usr/bin/bash --login " & "" & home_path & "\buildmypkg.sh" & ""
WshSysEnv("MSYSTEM") = "MINGW32" 'Use Mingw32 toolchain
Call WshShell.Run(cmd1, 1, True) 'RUN!
boolRunning = False 'hold
Do While boolRunning
  Set colProc = oWMISvc.ExecQuery("SELECT * FROM Win32_Process WHERE Name='" & "mintty.exe" & "'")
  boolRunning = False
  For Each oProc In colProc
    boolRunning = True
  Next
  Set colProc = Nothing
  WScript.Sleep 500
Loop
hasVS2013_64 = WshFS.FileExists("C:/Program Files (x86)/Microsoft Visual Studio 12.0/Common7/Tools/vsvars32.bat")
hasVS2013_32 = WshFS.FileExists("C:/Program Files/Microsoft Visual Studio 12.0/Common7/Tools/vsvars32.bat")
hasVS2012_64 = WshFS.FileExists("C:/Program Files (x86)/Microsoft Visual Studio 11.0/Common7/Tools/vsvars32.bat")
hasVS2012_32 = WshFS.FileExists("C:/Program Files/Microsoft Visual Studio 11.0/Common7/Tools/vsvars32.bat")
If (hasVS2013_64 Or hasVS2013_32 Or hasVS2012_64 Or hasVS2012_32) Then
cmd1 = "" & mintty_path & "" & " -i /msys2.ico /usr/bin/bash --login " & "" & home_path & "\bld_lsw_avs.sh" & ""
WshSysEnv("MSYSTEM") = "MINGW32" 'Use Mingw32 toolchain
Call WshShell.Run(cmd1, 1, True) 'Try to build LSW for AviSynth
boolRunning = False 'hold
Do While boolRunning
  Set colProc = oWMISvc.ExecQuery("SELECT * FROM Win32_Process WHERE Name='" & "mintty.exe" & "'")
  boolRunning = False
  For Each oProc In colProc
    boolRunning = True
  Next
  Set colProc = Nothing
  WScript.Sleep 500
Loop
End if
Rem ***************** Clean up *************************
Set oWMISvc = Nothing
Set WshSysEnv = Nothing
Set appShell = Nothing
Set WshFS = Nothing
Set WshProcEnv = Nothing
Set WshShell = Nothing
Rem ***************** Finish **************************
time_f= Now() 'End benchmark
MsgBox "First-time build Finished in " & DateDiff("n", time_i, time_f) & " minutes."
'Exit Script
WScript.Quit