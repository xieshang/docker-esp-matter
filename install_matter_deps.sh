#!/bin/bash
# Install Matter Python deps into the ESP-IDF venv, skipping any packages
# already present (to avoid version conflicts with ESP-IDF's own packages
# like kconfiglib, pyparsing, etc.).
#
# This reads from ConnectedHomeIP's own requirements files, so it stays
# up-to-date automatically when upgrading connectedhomeip.
set -e

source /opt/esp-idf/export.sh

# Collect installed package names (normalized: lowercase, underscores → hyphens)
pip freeze | sed 's/[>=<].*//' | tr '[:upper:]' '[:lower:]' | sed 's/_/-/g' \
    | sort -u > /tmp/installed-pkgs.txt

# requirements.build.txt has no version pins, safe to install with constraints
pip freeze > /tmp/idf-constraints.txt
pip install --no-cache-dir \
    -c /tmp/idf-constraints.txt \
    -r /opt/connectedhomeip/scripts/setup/requirements.build.txt

# requirements.esp32.txt has strict pins that conflict with ESP-IDF (e.g.
# pyparsing<3.1, esp-idf-kconfig==1.5.0).  Only install packages that are
# NOT already in the venv — awk compares each requirement's package name
# against the installed list and drops matches.
awk -F'[>=<;[ ]' '
    NR==FNR { installed[$1]=1; next }
    /^[[:space:]]*#/ || /^[[:space:]]*$/ || /^-/ { next }
    {
        pkg = tolower($1)
        gsub(/_/, "-", pkg)
        gsub(/[[:space:]]/, "", pkg)
        if (!(pkg in installed)) print
    }
' /tmp/installed-pkgs.txt /opt/connectedhomeip/scripts/setup/requirements.esp32.txt \
    > /tmp/filtered-esp32-reqs.txt

if [ -s /tmp/filtered-esp32-reqs.txt ]; then
    echo "Installing new ESP32 Matter deps:"
    cat /tmp/filtered-esp32-reqs.txt
    pip install --no-cache-dir -r /tmp/filtered-esp32-reqs.txt
else
    echo "All ESP32 Matter deps already satisfied"
fi
