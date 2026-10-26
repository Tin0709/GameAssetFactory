#!/usr/bin/env python3
"""Open the desktop app, paused unless --auto-commit is explicitly requested."""
import argparse
from checkpoint_manager.desktop import main

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--auto-commit', action='store_true',
                        help='Enable local checkpoints after the initial scan; never Push.')
    args = parser.parse_args()
    main(auto_commit=args.auto_commit)
