#!/bin/zsh
TASK_DIR="${0:A:h}"
exec python3 "$TASK_DIR/../../../../scripts/dev.py" blender --viewer mobs
