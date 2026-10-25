@echo off
color 0a
cd ../..
echo BUILDING GAME
haxelib run lime build windows -release
echo.
echo done.
pause
pwd