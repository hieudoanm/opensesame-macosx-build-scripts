#!/usr/bin/env bash
set -euo pipefail
source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate build

# Python versions to build. Each produces a universal2 (arm64 + x86_64) DMG.
PYTHON_VERSIONS="${PYTHON_VERSIONS:-3.10 3.11 3.12 3.13}"

for pv in $PYTHON_VERSIONS; do
  echo "=== Building OpenSesame for Python $pv (universal2) ==="
  ./build-env.sh "$pv" arm64
  ./build-env.sh "$pv" x86_64
  export PYTHON_VERSION="$pv"
  conda activate build
  python conda_env_to_app.py settings.py --clear --build --dmg
done
