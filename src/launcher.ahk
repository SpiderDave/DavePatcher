#NoTrayIcon
#SingleInstance ignore
SetWorkingDir %A_ScriptDir%

/*
    To Do:
        * Better error handling for files/folders that no longer exist.
        * Customize file filter
        * Custom "New Patch" dialog
        * Improve/custom file filters
        * Edit config.txt
        * Improve recent file list
          + Better handling of duplicates
          + Better handling of empty or small list
          + Configurable size of list
        * Customize/override programs used for test button
        * Customize/override programs used for edit patch button
        * About dialog: Donate button icon
*/


global patchFile
global testFile

Gui, +Resize
Gui, Show , w800 h500, DavePatcher Launcher

; here you have a text, button and edit
;Gui, Add, Text, x10 y10 w90 Center,text here
;Gui, Add, Edit, w90 h19 x10 y30 vFIRSTEDIT Center, input here

Gui, Add, Text, x134 y18 w300 vpatchFileLabel,
Gui, Add, Text, x134 y+18 w400 vRunStatus,

;Gui, Font, underline
;Gui, Add, Link, x12 y8,<a href="https://spiderdave.me">spiderdave.me</a>
;Gui, Add, Link, x+8,<a href="https://spiderdave.me/davepatcher/ref.php">davepatcher docs</a>
;Gui, Add, Link, x+8,<a href="https://github.com/SpiderDave/DavePatcher">github</a>
;Gui, Font, norm

Gui, Add, Button, x10 y10 w120 h30 vBUTTON1 gOpenPatch, Open patch file...
Gui, Add, Button, x10 y+2 w120 h30 vBUTTON2 gRunPatch, Run patch file (F5)
Gui, Add, Button, x10 y+2 w120 h30 vBUTTON3 gEditPatch, Edit patch file
;Gui, Add, ddl, x+4 w120 vBUTTON6 gEditConfig, patch.txt|config.txt
Gui, Add, Button, x+4 w80 h30 vEDITCONFIG gEditConfig, config.txt
Gui, Add, Button, x+4 w80 h30 vEDITTILEMAPS gEditTilemaps, tilemaps.txt
Gui, Add, Button, x10 y+2 w120 h30 vBUTTON4 gOpenPatchFolder, Open patch folder
Gui, Add, Button, x10 y+2 w120 h30 vBUTTON5 gTestRom, Test

Gui, Font, s10, Lucida Console
Gui, Color,, 102030
Gui, Add, Edit, w780 h285 x10 y+8 cEEEEEE HScroll vLog, 
;Gui, Color,, 000000

;Gui, Font, norm
;Gui, Add, Text, x10 y+4 w700 vRunStatus,test


GuiControl, Disable, BUTTON2
GuiControl, Disable, BUTTON3
GuiControl, Disable, BUTTON4

GuiControl, hide, Log
GuiControl, hide, BUTTON5
GuiControl, hide, EDITCONFIG
GuiControl, hide, EDITTILEMAPS
GuiControl, hide, RunStatus



;Menu, MySubmenu, Add, Log
;Menu, Tray, Add, This menu item is a submenu, :MySubmenu

Menu, FileMenu, Add, &Open`tCtrl+O, OpenPatch
Menu, FileMenu, Add, Create New Patch, NewPatch
Menu, ConfigMenu, Add, Auto Load Last Patch, ConfigMenuHandler
Menu, ConfigMenu, Add, Auto Load Last Log, ConfigMenuHandler
Menu, ConfigMenu, Add, Abridged Output, ConfigMenuHandler


Menu, ExtrasMenu, Add, NES Opcodes, ExtrasMenuHandler

;Menu, PatchMenu, Add, dummy, dummy
Menu, HelpMenu, Add, DavePatcher Help, HelpMenuHandler
Menu, HelpMenu, Add, About, HelpMenuHandler

;RegRead, Recent1, HKEY_CURRENT_USER\Software\DavePatcher, last
;RegRead, Recent1, HKEY_CURRENT_USER\Software\DavePatcher, recent1

RegRead, Recent1, HKEY_CURRENT_USER\Software\DavePatcher, recent1
RegRead, Recent2, HKEY_CURRENT_USER\Software\DavePatcher, recent2
RegRead, Recent3, HKEY_CURRENT_USER\Software\DavePatcher, recent3
RegRead, Recent4, HKEY_CURRENT_USER\Software\DavePatcher, recent4
RegRead, Recent5, HKEY_CURRENT_USER\Software\DavePatcher, recent5
RegRead, Recent6, HKEY_CURRENT_USER\Software\DavePatcher, recent6
RegRead, Recent7, HKEY_CURRENT_USER\Software\DavePatcher, recent7
RegRead, Recent8, HKEY_CURRENT_USER\Software\DavePatcher, recent8
RegRead, Recent9, HKEY_CURRENT_USER\Software\DavePatcher, recent9
RegRead, Recent10, HKEY_CURRENT_USER\Software\DavePatcher, recent10

Menu, Recent, Add, %Recent1%, RecentMenuHandler
Menu, Recent, Add, %Recent2%, RecentMenuHandler
Menu, Recent, Add, %Recent3%, RecentMenuHandler
Menu, Recent, Add, %Recent4%, RecentMenuHandler
Menu, Recent, Add, %Recent5%, RecentMenuHandler
Menu, Recent, Add, %Recent6%, RecentMenuHandler
Menu, Recent, Add, %Recent7%, RecentMenuHandler
Menu, Recent, Add, %Recent8%, RecentMenuHandler
Menu, Recent, Add, %Recent9%, RecentMenuHandler
Menu, Recent, Add, %Recent10%, RecentMenuHandler
Menu, FileMenu, Add, &Recent, :Recent




Menu, FileMenu, Add, E&xit, GuiClose

;Menu, ConfigMenu, Check, Auto Load Last Patch

Menu, MyMenuBar, Add, &File, :FileMenu
Menu, MyMenuBar, Add, &Config, :ConfigMenu
Menu, MyMenuBar, Add, &Extras, :ExtrasMenu
;Menu, MyMenuBar, Add, &Patch, :PatchMenu
Menu, MyMenuBar, Add, &Help, :HelpMenu


RegRead, Check, HKEY_CURRENT_USER\Software\DavePatcher, Auto Load Last Patch
if Check
    Menu, ConfigMenu, Check, Auto Load Last Patch
RegRead, Check, HKEY_CURRENT_USER\Software\DavePatcher, Auto Load Last Log
if Check
    Menu, ConfigMenu, Check, Auto Load Last Log
RegRead, Check, HKEY_CURRENT_USER\Software\DavePatcher, Abridged Output
if Check {
    Menu, ConfigMenu, Check, Abridged Output
}

Gui, Menu, MyMenuBar
Gui, Show

if GetOption("Auto Load Last Patch") {
    SelectedFile = %Recent1%
    Open(Recent1)
}
if GetOption("Auto Load Last Log") {
    RefreshLog(false)
}

return

ShowAbout:
Gui, 2: Font, s28
Gui, 2: Add, Text, x60 y100, DavePatcher
Gui, 2: Font, s12

Gui, 2: Add, Text, y+1, 2018 SpiderDave

Gui, 2: Font, s10
Gui, 2: Add, Link, x20 y+32, DavePatcher uses <a href="https://love2d.org/">LÖVE</a> and 
Gui, 2: Add, Link, x+2, <a href="http://www.dynaset.org/dogusanh/luacairo.html">LuaCario</a>.
Gui, 2: Add, Link, x20 y+2, DavePatcher Launcher made with <a href="https://autohotkey.com/">AutoHotKey</a>.
gui, 2: Add, Link, x20 y+32, <a href="bitcoin:1EZWWNGMsCrTciXLS6EvSjwq3cZBTG1qQk">Donate Bitcoin</a>

Gui, 2: Font, s12
Gui, 2: Add, Link, x12 y370,<a href="https://spiderdave.me">spiderdave.me</a>
Gui, 2: Add, Link, x+12,<a href="https://spiderdave.me/davepatcher/ref.php">davepatcher docs</a>
Gui, 2: Add, Link, x+12,<a href="https://github.com/SpiderDave/DavePatcher">github</a>


Gui, 2: Show, w340 h400, About DavePatcher

return

ExtrasMenuHandler:
i:=A_ThisMenuItem
if i=NES Opcodes
    run http://www.thealmightyguru.com/Games/Hacking/Wiki/index.php/6502_Opcodes
return

HelpMenuHandler:
i:=A_ThisMenuItem
if i=DavePatcher Help
    run http://spiderdave.me/davepatcher/ref.php
if i=About
    goto ShowAbout
    ;MsgBox, DavePatcher`nby SpiderDave`n`nLatest version available on github https://github.com/SpiderDave/DavePatcher
return

ConfigMenuHandler:
; Toggle the item
Menu, ConfigMenu, ToggleCheck, %A_ThisMenuItem%

; Read the value from registry, toggle it, write new value
RegRead, Check, HKEY_CURRENT_USER\Software\DavePatcher, %A_ThisMenuItem%
Check := !Check
RegWrite, REG_DWORD, HKEY_CURRENT_USER\Software\DavePatcher, %A_ThisMenuItem%, %Check%

;MsgBox, %A_ThisMenuItem% = %Check%

foo=Abridged Output
if A_ThisMenuItem=Abridged%A_Space%Output
    RefreshLog()
return

;Recent1:
RecentMenuHandler:
;SelectedFile = %Recent1%
SelectedFile = %A_ThisMenuItem%
Open(SelectedFile)
RefreshRecentFiles(patchFile)
return

Dummy:
return

MenuFileOpen:
return

NewPatch:
{
    InputBox, UserInput, New Script, Please enter a folder name for the script., ,
    if UserInput =
        return
    folderName := UserInput
    folder = %A_ScriptDir%\%folderName%
    if FileExist(folder) {
        MsgBox, %folder% already exists
        return
    }
    try {
        FileCreateDir, %folder%
    } catch e {
        MsgBox, Error ErrorLevel=%ErrorLevel% A_LastError=%A_LastError%
    }
    
    MsgBox, 
    (LTrim
    Next, select the file to patch.  This will be the unmodified file, 
    such as "game.nes".  It should be located in the /backup folder, or 
    you'll have to do some modifications to the patch's config.txt to 
    make it work.
    )
    
    backupFolder=%A_ScriptDir%\backup
    if FileExist(backupFolder) {
        ;pass
    } else {
        backupFolder=%A_ScriptDir%
    }
    
    ;SetWorkingDir %A_ScriptDir%\backup
    FileSelectFile, SelectedFile, 3,%backupFolder%\ , Open a file, All Files (*.nes`;*.gb`;*.sms)
    if SelectedFile =
        return
    else
        ;MsgBox % SelectedFile
        ;pass
    
    SplitPath, SelectedFile, backupFile,,backupFileExt,backupFileNoExt
    
    
    patchFile = %folder%\patch.txt
    configFile = %folder%\config.txt
    if FileExist(configFile) {
        MsgBox, "%configFile%" already exists
        return
    } else {
        FileAppend, 
        ( LTrim
        oldFile = ../backup/%backupFile%
        newFile = %backupFileNoExt% New.%backupFileExt%
        )`n, %configFile%
    }
    
    if FileExist(patchFile) {
        MsgBox, "%patchFile%" already exists
        return
    } else {
        FileAppend, 
        ( LTrim
        // patch for "%backupFile%"

        include config.txt
        load `%oldFile`%

        offset 10
        //include tilemaps.txt

        :end
        save `%newFile`%
        )`n, %patchFile%
    }
    
    open(patchFile)
    RefreshRecentFiles(patchFile)
return
}

OpenPatch:
{
global patchFile
SetWorkingDir %A_ScriptDir% 
FileSelectFile, SelectedFile, 3, %A_ScriptDir%\, Open a file, Text Documents (patch.txt;)
if SelectedFile =
    ;MsgBox, The user didn't select anything.
    return
else
    GuiControl, hide, Log
    GuiControl, hide, BUTTON5
    GuiControl, hide, EDITCONFIG
    GuiControl, hide, EDITTILEMAPS
    GuiControl, hide, RunStatus
    ;MsgBox, The user selected the following:`n%SelectedFile%
    
    patchFile = %SelectedFile%
    guicontrol, ,patchFileLabel, %SelectedFile%
    
    SplitPath, patchFile,file, dir
    SetWorkingDir, %dir%
    
    
    RefreshRecentFiles(SelectedFile)
    
    GuiControl, Enable, BUTTON2
    GuiControl, Enable, BUTTON3
    GuiControl, Enable, BUTTON4
return
}


#IfWinActive, DavePatcher Launcher ahk_class AutoHotkeyGUI
f5::
RunPatch:
{
    global patchFile
    if patchFile =
        return
    else
        ;We blank RunStatus here so it looks like it's doing something if nothing changes.
        Guicontrol, ,RunStatus, 
        
        SplitPath, patchFile,file, dir
        SetWorkingDir, %dir%

        RunWait, %A_ScriptDir%\davepatcher.exe -launcher %file%,,hide
        RefreshLog()
    return
}
#IfWinActive
RefreshLog(ShowSuccess=true)
{
    FileRead, Contents, %A_ScriptDir%\autolog.txt
    
    FoundPos := RegExMatch(Contents, "(Patching complete\.)  Output to file ""(.*?\..*?)""", m, StartingPosition := 1)
    ;RegExMatch(Contents, "msO)#launcher\.(.*?)=(.*?)$" , launcherData, StartingPosition := 1)
    
    ;MsgBox % getLauncherDirective(Contents, "config")
    ;MsgBox % getLauncherDirective(Contents, "outputfile")
    
    GuiControl, hide, EDITCONFIG
    GuiControl, hide, EDITTILEMAPS

    if getLauncherDirective(Contents, "config")
        GuiControl, show, EDITCONFIG
    if getLauncherDirective(Contents, "tilemaps")
        GuiControl, show, EDITTILEMAPS
    
    ; Strip all launcher directives, and new lines following them
    Contents := RegExReplace(Contents, "m)#launcher\..*?=.*?$[\r\n]+" , Replacement := "",,, StartingPosition := 1)
    
    if GetOption("Abridged Output")
        Contents := "Showing last 15 lines:`n...`n"+Tail(15, Contents)
    
    
    if InStr(Contents,"Patching complete.")
        success=true
    else
        success=false
    
    if m2 =
    {
        GuiControl, hide, BUTTON5
        GuiControl, hide, EDITCONFIG
        GuiControl, hide, EDITTILEMAPS
        testFile=
;            if m1 =
;                success=false
;            else
;                success=true
    }
    else
    {
        testFile=%m2%
        GuiControl, show, BUTTON5
        
;            success=true
    }
    
    GuiControl, show, RunStatus
    if ShowSuccess {
        if success=true
        {
            GuiControl, +c20C020, RunStatus
            Guicontrol, ,RunStatus, Success
        }
        else
        {
            GuiControl, +cC02020, RunStatus
            Guicontrol, ,RunStatus, Error
        }
    }
    
    guicontrol, ,Log, %Contents%
    GuiControl, show, Log
}
return

EditConfig:
{
global patchFile

SplitPath,patchFile,, dir
SetWorkingDir, %dir%

;target = notepad.exe config.txt
target = config.txt
RoA("config.txt", target)

return
}

EditTilemaps:
{
global patchFile

SplitPath,patchFile,, dir
SetWorkingDir, %dir%

target = tilemaps.txt
RoA("tilemaps.txt", target)

return
}

EditPatch:
{
global patchFile

SplitPath, patchFile,file, dir
SetWorkingDir, %dir%

;Run, notepad.exe %file%
;target = notepad.exe %file%
target = %file%
RoA(file, target)
;IfWinExist, %file%
;    WinActivate, %file%
;else
;    Run, notepad.exe %file%

return
}

TestRom:
{
global patchFile
global testFile

SplitPath, patchFile,file, dir
SetWorkingDir, %dir%

Run, "%testFile%"

;RegRead, FceuxCommand, HKEY_CURRENT_USER\Software\Classes\Applications\fceux.exe\shell\open\command
;FceuxCommand := RegExReplace(FceuxCommand, " ""\%1""", "")
;run, %FceuxCommand% -lua "J:\Games\Nes\luaScripts\SpiderDave_sprite_test.lua" "%testFile%"
;RegWrite, REG_SZ, HKEY_CURRENT_USER\Software\DavePatcher, MyValueName, Test Value

;sleep 1000
;WinMenuSelectItem, FCEUX 2.2.3: Upa New, , File, Lua, New Lua Script Window...

return
}

OpenPatchFolder:
{
global patchFile

SplitPath, patchFile,file, dir
SetWorkingDir, %dir%

Run, explore "%dir%"

return
}


Open(f)
{
    GuiControl, hide, Log
    GuiControl, hide, BUTTON5
    GuiControl, hide, EDITCONFIG
    GuiControl, hide, EDITTILEMAPS
    GuiControl, hide, RunStatus
    
    patchFile = %f%
    guicontrol, ,patchFileLabel, %f%
    
    SplitPath, patchFile,file, dir
    SetWorkingDir, %dir%
    
    RegWrite, REG_SZ, HKEY_CURRENT_USER\Software\DavePatcher, last, %f%
    
    GuiControl, Enable, BUTTON2
    GuiControl, Enable, BUTTON3
    GuiControl, Enable, BUTTON4

    return
}


RefreshRecentFiles(file)
{
    RegWrite, REG_SZ, HKEY_CURRENT_USER\Software\DavePatcher, last, %file%
    
    RegRead, Recent1, HKEY_CURRENT_USER\Software\DavePatcher, recent1
    RegRead, Recent2, HKEY_CURRENT_USER\Software\DavePatcher, recent2
    RegRead, Recent3, HKEY_CURRENT_USER\Software\DavePatcher, recent3
    RegRead, Recent4, HKEY_CURRENT_USER\Software\DavePatcher, recent4
    RegRead, Recent5, HKEY_CURRENT_USER\Software\DavePatcher, recent5
    RegRead, Recent6, HKEY_CURRENT_USER\Software\DavePatcher, recent6
    RegRead, Recent7, HKEY_CURRENT_USER\Software\DavePatcher, recent7
    RegRead, Recent8, HKEY_CURRENT_USER\Software\DavePatcher, recent8
    RegRead, Recent9, HKEY_CURRENT_USER\Software\DavePatcher, recent9
    
    RegWrite, REG_SZ, HKEY_CURRENT_USER\Software\DavePatcher, recent1, %file%
    RegWrite, REG_SZ, HKEY_CURRENT_USER\Software\DavePatcher, recent2, %Recent1%
    RegWrite, REG_SZ, HKEY_CURRENT_USER\Software\DavePatcher, recent3, %Recent2%
    RegWrite, REG_SZ, HKEY_CURRENT_USER\Software\DavePatcher, recent4, %Recent3%
    RegWrite, REG_SZ, HKEY_CURRENT_USER\Software\DavePatcher, recent5, %Recent4%
    RegWrite, REG_SZ, HKEY_CURRENT_USER\Software\DavePatcher, recent6, %Recent5%
    RegWrite, REG_SZ, HKEY_CURRENT_USER\Software\DavePatcher, recent7, %Recent6%
    RegWrite, REG_SZ, HKEY_CURRENT_USER\Software\DavePatcher, recent8, %Recent7%
    RegWrite, REG_SZ, HKEY_CURRENT_USER\Software\DavePatcher, recent9, %Recent8%
    
    Menu, Recent, DeleteAll
    Menu, Recent, Add, %file%, RecentMenuHandler
    Menu, Recent, Add, %Recent1%, RecentMenuHandler
    Menu, Recent, Add, %Recent2%, RecentMenuHandler
    Menu, Recent, Add, %Recent3%, RecentMenuHandler
    Menu, Recent, Add, %Recent4%, RecentMenuHandler
    Menu, Recent, Add, %Recent5%, RecentMenuHandler
    Menu, Recent, Add, %Recent6%, RecentMenuHandler
    Menu, Recent, Add, %Recent7%, RecentMenuHandler
    Menu, Recent, Add, %Recent8%, RecentMenuHandler
    Menu, Recent, Add, %Recent9%, RecentMenuHandler
    return
}

SetConfigOption()
{
    return
}

GetOption(o)
{
    RegRead, v, HKEY_CURRENT_USER\Software\DavePatcher, %o%
    return %v%
}

Tail(k,text)
{
   Loop Parse, text, `n
     lines++
   Loop Parse, text, `n
   {
      If (A_Index < lines - k)
         Continue
      L = %L%`n%A_Loopfield%
   }
   StringTrimLeft L, L, 1
   Return L
}

RoA(InTitle, Target)
{
    IfWinExist, %InTitle%
        WinActivate, %InTitle%
    else
        Run, "%Target%",,UseErrorLevel
    
    if ErrorLevel=ERROR
        MsgBox "%Target%" not found.
        
}

getLauncherDirective(s,n)
{
    RegExMatch(s, "ms)#launcher\." . n . "=(.*?)$" , m, StartingPosition := 1)
    return m1
}


RegExMatchLoop(Haystack, NeedleRegEx, StartingPos := 1) {
  match_array := []
  Loop
  {
    found_pos := RegExMatch(Haystack, NeedleRegEx, output_var, StartingPos)
    If (output_var) {
      match_array.Push(output_var)
      Haystack := SubStr(Haystack, found_pos + StrLen(output_var))
    } Else {
      Break
    }
  }
  Return match_array
}

GuiClose:
ExitApp