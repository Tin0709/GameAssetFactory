#!/bin/zsh
TASK_DIR="${0:A:h}"
exec python3 "$TASK_DIR/../../../../scripts/open_blender_viewer.py" mobs
