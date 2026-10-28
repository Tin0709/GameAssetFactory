@echo off
set "GAF_BLENDER=C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
for %%I in ("%~dp0..\..\..\..\..") do set "GAF_ROOT=%%~fI"
if not exist "%GAF_BLENDER%" (
  echo Blender 5.2 executable was not found. Update GAF_BLENDER in this launcher.
  pause
  exit /b 1
)
start "" "%GAF_BLENDER%" --factory-startup --disable-autoexec "%GAF_ROOT%\blender\animation\showcase\Animation_Showcase.blend" --python "%~dp0open_review.py"
