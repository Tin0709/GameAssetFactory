@echo off
start "Player Animation Review" "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" "%~dp0player_animation_library_v1.blend" --python "%~dp0review_controls.py"
