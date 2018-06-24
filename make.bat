@echo off
cd src
call make.bat
copy/y package\*.* ..\

cd..

davepatcher -readme

echo build done.