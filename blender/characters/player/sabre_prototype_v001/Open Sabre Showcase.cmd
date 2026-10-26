@echo off
set "GAF_PRIVATE_RESEARCH=%USERPROFILE%\Desktop\MD2 Research"
if defined MD2_RESEARCH_ROOT set "GAF_PRIVATE_RESEARCH=%MD2_RESEARCH_ROOT%"
if exist "%GAF_PRIVATE_RESEARCH%\blender\prototype_sabre\MD2_Valorie_Sabre_Source_Showcase.blend" (
  "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" "%GAF_PRIVATE_RESEARCH%\blender\prototype_sabre\MD2_Valorie_Sabre_Source_Showcase.blend" --python "%GAF_PRIVATE_RESEARCH%\blender\prototype_sabre\source_preview_ui.py"
  exit /b
)
if exist "%GAF_PRIVATE_RESEARCH%\blender\prototype_sabre\MD2_Valorie_Sabre_Showcase.blend" (
  "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" "%GAF_PRIVATE_RESEARCH%\blender\prototype_sabre\MD2_Valorie_Sabre_Showcase.blend" --python "%GAF_PRIVATE_RESEARCH%\blender\prototype_sabre\preview_ui.py"
  exit /b
)
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" "%~dp0Sabre_Character_Showcase.blend" --python "%~dp0preview_ui.py"
