@echo off
setlocal
py -3 "%~dp0scripts\dev.py" godot --scene combat --weapon sword %*
if errorlevel 1 (
  echo.
  echo Set GODOT_BIN to your Godot executable and install Python 3 if needed.
  pause
  exit /b 1
)
