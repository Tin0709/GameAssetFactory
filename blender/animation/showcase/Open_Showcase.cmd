@echo off
setlocal
set "GAF_BLENDER=C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
start "" "%GAF_BLENDER%" "%~dp0Animation_Showcase.blend"
