@echo off
setlocal
set "GAF_SABRE_GODOT=%GODOT_BIN%"
if not defined GAF_SABRE_GODOT set "GAF_SABRE_GODOT=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if not exist "%GAF_SABRE_GODOT%" (
  echo Set GODOT_BIN to your installed Godot executable.
  pause
  exit /b 1
)
start "" "%GAF_SABRE_GODOT%" --path "%~dp0." --rendering-method mobile --rendering-driver d3d12 --editor res://scenes/dev/ActionsStuffWalkRunTest.tscn
