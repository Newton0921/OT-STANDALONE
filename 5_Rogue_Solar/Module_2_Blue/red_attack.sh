#!/bin/bash
# red_attack.sh - Shell wrapper for the Python attack script
# Connects to the misconfigured MQTT broker and injects a forged value.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
python3 "${SCRIPT_DIR}/red_attack.py" "$@"