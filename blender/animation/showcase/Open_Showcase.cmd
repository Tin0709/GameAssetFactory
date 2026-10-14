@echo off
setlocal
if not defined GAF_PYTHON set "GAF_PYTHON=python"
"%GAF_PYTHON%" "%~dp0..\..\..\scripts\dev.py" blender --showcase animation
