#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./build-env.sh 3.13 arm64
#   ./build-env.sh 3.13 x86_64
#   ./build_env.sh py313
#   ./build_env.sh 313
#
# Derives:
#   - Python version (e.g., 3.13)
#   - Tag digits (e.g., 313)
#   - Architecture (arm64 or x86_64, default: native)
#   - Conda env name: opensesame-py{digits}-{arch} (e.g., opensesame-py313-arm64)
#
# Note: building x86_64 on Apple Silicon requires Rosetta 2
# (install with: softwareupdate --install-rosetta --agree-to-license)

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <python-version-or-tag> [arch]"
  echo "Examples: $0 3.13 arm64 | $0 3.13 x86_64 | $0 py313"
  exit 1
fi

ARG="$1"
ARCH="${2:-$(uname -m)}"

case "$ARCH" in
  arm64|x86_64) ;;
  *) echo "Error: arch must be arm64 or x86_64 (got: $ARCH)" >&2; exit 1 ;;
esac

digits=""
version=""

if [[ "$ARG" =~ ^[Pp][Yy]([0-9]{2,3})$ ]]; then
  # py313 or py310
  digits="${BASH_REMATCH[1]}"
  major="${digits:0:1}"
  minor="${digits:1}"
  version="${major}.${minor}"
elif [[ "$ARG" =~ ^([0-9]+)\.([0-9]+)$ ]]; then
  # 3.13 or 3.10
  major="${BASH_REMATCH[1]}"
  minor="${BASH_REMATCH[2]}"
  version="${major}.${minor}"
  digits="${major}${minor}"
elif [[ "$ARG" =~ ^([0-9]{2,3})$ ]]; then
  # 313 or 310
  digits="${BASH_REMATCH[1]}"
  major="${digits:0:1}"
  minor="${digits:1}"
  version="${major}.${minor}"
else
  echo "Error: argument must look like 3.13, py313, or 313" >&2
  exit 1
fi

ENV_NAME="opensesame-py${digits}-${ARCH}"

echo "Config:"
echo "  Python version: ${version}"
echo "  Tag digits:     ${digits}"
echo "  Architecture:   ${ARCH}"
echo "  Conda env name: ${ENV_NAME}"
echo

if [[ "$ARCH" == "x86_64" ]]; then
  if ! arch -x86_64 /usr/bin/true 2>/dev/null; then
    echo "Error: building x86_64 packages requires Rosetta 2." >&2
    echo "Install it with: softwareupdate --install-rosetta --agree-to-license" >&2
    exit 1
  fi
fi

# Source conda initialization
if [[ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]]; then
  # shellcheck disable=SC1091
  source "$HOME/miniconda3/etc/profile.d/conda.sh"
else
  echo "Could not find conda.sh at \$HOME/miniconda3/etc/profile.d/conda.sh" >&2
  echo "Make sure Miniconda is installed there or update the path in this script." >&2
  exit 1
fi

# Remove existing env if present (ignore error if it doesn't exist)
conda env remove -n "${ENV_NAME}" -y || true

# Create and populate environment.
# CONDA_SUBDIR forces conda to fetch packages for the requested architecture,
# even when running on a different host architecture.
case "$ARCH" in
  arm64)   CONDA_SUBDIR_VAL="osx-arm64" ;;
  x86_64)  CONDA_SUBDIR_VAL="osx-64" ;;
esac
export CONDA_SUBDIR="$CONDA_SUBDIR_VAL"

conda create -n "${ENV_NAME}" "python=${version}" -y
conda activate "${ENV_NAME}"

# Source builds under Rosetta can produce arm64 objects; force the target arch.
if [[ "$ARCH" == "x86_64" ]]; then
  export ARCHFLAGS="-arch x86_64"
fi

python -m pip install -r requirements.txt
python -m pip install psychopy --ignore-requires-python --no-deps

conda deactivate
