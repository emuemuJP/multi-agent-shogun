#!/bin/bash
# Wrapper script to start the Multi-Model Discussion System
# 複数AIモデル討論システム起動ラッパー

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/discussion/discussion_start.sh" "$@"
