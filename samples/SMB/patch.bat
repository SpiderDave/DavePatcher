@echo off
rem ---- Configuration ----
set patch=patch.txt
rem -----------------------

if %1X==makeX goto make
if %1X==fixX goto theend
goto :patch

:make
pushd ..
call make
popd
echo make

:patch
..\..\davepatcher %patch%

:theend