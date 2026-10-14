#!/bin/zsh
TASK_DIR="${0:A:h}"
open -na "Blender" --args "$TASK_DIR/../Mobs_Animation_Library.blend" --python "$TASK_DIR/open_library.py"
