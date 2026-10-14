#!/bin/zsh
script_dir="${0:A:h}"
exec /Applications/Blender.app/Contents/MacOS/Blender --factory-startup --disable-autoexec "${script_dir}/../../../showcase/Animation_Showcase.blend" --python "${script_dir}/open_research.py"
