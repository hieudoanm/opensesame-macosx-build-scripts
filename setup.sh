#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script: installs all prerequisites for building OpenSesame macOS
# packages. Idempotent — safe to re-run; each step is skipped if already done.
#
# What it installs:
#   1. Rosetta 2            (needed to build the x86_64 slice on Apple Silicon)
#   2. Xcode CLT            (provides lipo, codesign, clang)
#   3. libmagic             (needed by python-magic, via Homebrew)
#   4. Miniconda            (at ~/miniconda3, as the build scripts expect)
#   5. 'build' conda env    (dmgbuild, python-magic, biplist, six)
#
# After this completes, run:  ./build-all.sh

# --- 1. Rosetta 2 -------------------------------------------------------------
if [[ "$(uname -m)" == "arm64" ]] && ! arch -x86_64 /usr/bin/true 2>/dev/null; then
  echo "==> Installing Rosetta 2 (required for x86_64 builds)..."
  softwareupdate --install-rosetta --agree-to-license
else
  echo "==> Rosetta 2: already installed (or not needed)"
fi

# --- 2. Xcode command line tools ----------------------------------------------
if ! xcode-select -p >/dev/null 2>&1; then
  echo "==> Xcode command line tools not found."
  echo "    A system dialog will appear — please complete the installation,"
  echo "    then re-run this script."
  xcode-select --install
  exit 0
fi
echo "==> Xcode CLT: OK ($(xcode-select -p))"

# --- 3. libmagic ---------------------------------------------------------------
if command -v brew >/dev/null 2>&1; then
  if ! brew list libmagic >/dev/null 2>&1; then
    echo "==> Installing libmagic via Homebrew..."
    brew install libmagic
  else
    echo "==> libmagic: already installed"
  fi
else
  echo "WARNING: Homebrew not found; python-magic needs libmagic."
  echo "         Install Homebrew (https://brew.sh) or libmagic manually."
fi

# --- 4. Miniconda ---------------------------------------------------------------
if [[ ! -x "$HOME/miniconda3/bin/conda" ]]; then
  echo "==> Installing Miniconda..."
  case "$(uname -m)" in
    arm64)  MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh" ;;
    x86_64) MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh" ;;
  esac
  curl -fsSL -o /tmp/miniconda.sh "$MINICONDA_URL"
  bash /tmp/miniconda.sh -b -p "$HOME/miniconda3"
  rm -f /tmp/miniconda.sh
else
  echo "==> Miniconda: already installed"
fi

# shellcheck disable=SC1091
source "$HOME/miniconda3/etc/profile.d/conda.sh"

# --- 5. Accept conda channel Terms of Service -----------------------------------
# Recent conda versions refuse to use the defaults channels until accepted.
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main || true
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r || true

# --- 6. 'build' conda env with packaging dependencies ---------------------------
if ! conda env list | awk '{print $1}' | grep -qx build; then
  echo "==> Creating 'build' conda env (python=3.13)..."
  conda create -n build python=3.13 -y
fi

conda activate build
python -m pip install -U pip
pip install dmgbuild biplist six python-magic
conda deactivate

echo
echo "==> All prerequisites installed."
echo "    Optional: run 'conda init zsh' once so 'conda' works in new shells."
echo "    Then build with:  ./build-all.sh"
