@echo off
setlocal
set _7z=C:\Program Files\7-Zip\7z.exe

rem create lua file for automatic versioning
set mydate=%date:~-4,4%.%date:~-10,2%.%date:~-7,2%
echo version={stage="%stage%", date="%mydate%", time="%time%"}>version.lua

rd/q/s package
md package
"%_7z%" u davepatcher.love "conf.lua" "main.lua" "version.lua" "davepatcher.lua" -tzip
copy /b love\love.exe+davepatcher.love package\davepatcher.exe
copy love\*.dll package
del davepatcher.love


goto theend

:error
echo.
echo Did NOT complete successfully.
echo.%errormessage%
echo.
echo.
echo                      No longer do the dance of joy Numfar.
echo.
echo.
rem pause
exit

:theend
echo.
echo Done.
echo.
echo.
echo                           Numfar, do the dance of joy!
echo.
echo.
rem pause