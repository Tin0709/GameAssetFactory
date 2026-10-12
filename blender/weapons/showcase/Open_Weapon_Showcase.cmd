@echo off
setlocal
set "GAF_BLENDER=C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
start "Weapon Library" "%GAF_BLENDER%" "%~dp0Weapon_Showcase.blend" --python "%~dp0gaf_weapon_library.py"
