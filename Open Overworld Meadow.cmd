@echo off
setlocal
if not defined MD2_OVERWORLD_BUNDLE set "MD2_OVERWORLD_BUNDLE=%USERPROFILE%\Desktop\MD2 Research\godot_lab\overworld_fidelity_v001\bundle.private.json"
if exist "%MD2_OVERWORLD_BUNDLE%\" (
  echo Private Overworld bundle must be a JSON file, not a folder:
  echo "%MD2_OVERWORLD_BUNDLE%"
  pause
  exit /b 1
)
if not exist "%MD2_OVERWORLD_BUNDLE%" (
  echo Private Overworld bundle not found:
  echo "%MD2_OVERWORLD_BUNDLE%"
  echo Restore the private Research workspace or set MD2_OVERWORLD_BUNDLE to its bundle.private.json.
  pause
  exit /b 1
)
py -3 "%~dp0scripts\dev.py" godot --scene overworld %*
if errorlevel 1 (
  echo.
  echo Set GODOT_BIN to your Godot executable and install Python 3 if needed.
  pause
  exit /b 1
)
