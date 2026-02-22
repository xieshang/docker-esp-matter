# ESP-IDF + ConnectedHomeIP Docker Image

Docker image combining [ESP-IDF](https://github.com/espressif/esp-idf) v5.5.3 and
[ConnectedHomeIP](https://github.com/project-chip/connectedhomeip) v1.5.0.1 for
building ESP32 Matter firmware.

## Quick Start

```bash
# Build
docker build -t esp-matter .

# Run interactive shell
docker run --rm -it -v $(pwd)/my-project:/workspace esp-matter

# Inside the container
cd /workspace
idf.py set-target esp32c6
idf.py build
```

## How It Works

### The Python Environment Problem

Both ESP-IDF and ConnectedHomeIP create their own Python virtual environments:

| Component | Venv Location | Key Packages |
|-----------|--------------|--------------|
| ESP-IDF | `~/.espressif/python_env/idf5.5_py3.11_env/` | `kconfiglib`, `esptool`, `idf-component-manager` |
| ConnectedHomeIP (Pigweed) | `/opt/connectedhomeip/.environment/pigweed-venv/` | `kconfiglib` (different version), `python-path`, `lark` |

The two venvs contain **conflicting versions** of the same packages. Most critically,
the Pigweed venv's `kconfiglib` is incompatible with ESP-IDF v5.5.3's Kconfig files —
causing `AttributeError: 'MenuNode' object has no attribute 'help'` during
`idf.py set-target` / `idf.py build`.

### Solution: Follow the esp-matter Pattern

This image follows the same approach as Espressif's official
[esp-matter](https://github.com/espressif/esp-matter) Docker image:

1. **ESP-IDF's Python venv is active at runtime** — provides the correct `kconfiglib`,
   `kconfgen`, `esptool`, and all other ESP-IDF Python tools.
2. **Pigweed tool binaries are added to PATH** — provides `gn`, `zap-cli`, and other
   standalone tools needed for Matter builds.
3. **The Pigweed Python venv is NOT activated** — `scripts/activate.sh` is intentionally
   not sourced at runtime to avoid the `kconfiglib` version conflict.

This means `python3` resolves to the ESP-IDF venv's Python, while Pigweed's compiled
tools (from CIPD) are still available via PATH.

### Why Python 3.11?

The base image (Ubuntu 22.04) ships with Python 3.10, but ConnectedHomeIP v1.5 requires
Python >= 3.11 (specifically, `bluezoo>=1.0.2` needs it). The Dockerfile installs
Python 3.11 via `update-alternatives` and re-runs `esp-idf/install.sh` to create a
fresh venv with 3.11.

### Entrypoint

The entrypoint sources ESP-IDF's `export.sh` then manually adds Pigweed tool paths:

```bash
source /opt/esp-idf/export.sh

export PATH="/opt/connectedhomeip/.environment/cipd/packages/pigweed:${PATH}"
export PATH="/opt/connectedhomeip/.environment/cipd/packages/zap:${PATH}"
export ZAP_INSTALL_PATH=/opt/connectedhomeip/.environment/cipd/packages/zap
export _PW_ACTUAL_ENVIRONMENT_ROOT=/opt/connectedhomeip/.environment
```

This mirrors what `esp-matter/export.sh` does — adding only tool directories, not
activating the Pigweed Python venv.

### Python Package Installation Strategy

After ConnectedHomeIP bootstrap, Matter's Python dependencies (e.g. `lark`, `jinja2`,
`python-path`) must be installed into the ESP-IDF venv. The two projects share some
packages (`click`, `pyparsing`, `kconfiglib`, etc.) but pin **different versions** —
installing one over the other breaks things.

`install_matter_deps.sh` handles this automatically:

1. **Freeze ESP-IDF's installed packages** — captures exact versions as a baseline.
2. **Install `requirements.build.txt`** with freeze constraints — Matter codegen deps
   (`lark`, `jinja2`, `python-path`, etc.) that have no version conflicts.
3. **Filter `requirements.esp32.txt`** — uses `awk` to compare each requirement's
   package name against the installed set; only packages NOT already in the venv are
   installed. This skips conflicting pins like `pyparsing<3.1`, `esp-idf-kconfig==1.5.0`,
   etc. without hardcoding any package names.

When upgrading ConnectedHomeIP, the requirements files update automatically — no
manual package list to maintain.

## Versions

| Component | Version |
|-----------|---------|
| ESP-IDF | v5.5.3 |
| ConnectedHomeIP | v1.5.0.1 |
| Python | 3.11 |
| Base OS | Ubuntu 22.04 |

## Reference

- [esp-matter Docker image](https://github.com/espressif/esp-matter/tree/main/tools/docker/matter_builds) — official Espressif Docker setup this image is modeled after
- [ConnectedHomeIP Building Guide](https://project-chip.github.io/connectedhomeip-doc/guides/BUILDING.html) — documents Python 3.11 requirement
- [ESP-IDF Docker Image](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-guides/tools/idf-docker-image.html)
