@echo off
rem Makes export/clean: the built game without the base game's songs and weeks, for people making mods.
rem Double click it, or run it with the options: export_clean_build.bat [--zip] [--dry] [--force] [<game folder> <output folder>]
rem Only Haxe is needed (the same one that builds the game).
setlocal
cd /d "%~dp0.."
where haxe >nul 2>nul
if errorlevel 1 (
	echo Haxe was not found. Install it from https://haxe.org/download/ ^(the same one used to build the game^).
) else (
	haxe art/export_clean_build.hxml %*
)
set RESULT=%errorlevel%
rem (a window opened with a double click stays open to show what happened)
echo %cmdcmdline% | "%SystemRoot%\System32\find.exe" /i "%~nx0" >nul && pause
exit /b %RESULT%
