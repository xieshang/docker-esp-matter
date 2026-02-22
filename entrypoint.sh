#!/bin/bash
set -e

# Source ESP-IDF — sets IDF_PATH, activates ESP-IDF Python venv.
# This gives us the correct python3 with ESP-IDF's kconfiglib, kconfgen, etc.
source /opt/esp-idf/export.sh

# Add ConnectedHomeIP Pigweed TOOL binaries to PATH without activating
# the Pigweed Python venv.  This mirrors what esp-matter's export.sh does.
#
# Why not "source scripts/activate.sh"?
#   activate.sh activates the Pigweed Python venv, which contains its own
#   kconfiglib / kconfgen versions that are INCOMPATIBLE with ESP-IDF v5.5.
#   Keeping ESP-IDF's Python venv active avoids the version conflict.
export PATH="/opt/connectedhomeip/.environment/cipd/packages/pigweed:${PATH}"
export PATH="/opt/connectedhomeip/.environment/cipd/packages/zap:${PATH}"
export ZAP_INSTALL_PATH=/opt/connectedhomeip/.environment/cipd/packages/zap
export _PW_ACTUAL_ENVIRONMENT_ROOT=/opt/connectedhomeip/.environment

exec "$@"
