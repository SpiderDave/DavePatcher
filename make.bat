@echo off

set foldername=
set tempfile=_temp.lua
set stage= beta

rem create lua file for automatic versioning
set mydate=%date:~-4,4%.%date:~-10,2%.%date:~-7,2%
echo local version={stage="%stage%", date="%mydate%", time="%time%"}>version.lua

rem concat the patch with the automatic version file
copy version.lua+davepatcher.lua /a %tempfile% /b

rem glue the file with srlua
echo building davepatcher.exe...
glue srlua.exe %tempfile% davepatcher.exe
rem glue srlua.exe mm1levelmaker.lua mm1levelmaker.exe
davepatcher -readme

del %tempfile%
echo build done.