# OpenSesame build scripts for Mac OSX

These scripts package conda environments with OpenSesame installed into a
universal2 (arm64 + x86_64) `.app` bundle and `.dmg` disk image, targeting
macOS 14 and later. The app is ad-hoc signed, so users need to right-click
and select **Open** on first launch.

## Setup

On a fresh machine, install all prerequisites first:

```bash
./setup.sh
```

This installs Rosetta 2, Xcode CLT, libmagic, Miniconda, and the `build`
conda env. It is idempotent — safe to re-run.

## Dependencies

Already handled by `./setup.sh`:

- Miniconda installed at `~/miniconda3`
- A conda env named `build` containing: `dmgbuild`, `python-magic` (requires
  libmagic), `biplist`, `six`
- Xcode command line tools (provides `lipo`, `codesign`)
- Rosetta 2 (required to build the x86_64 slice on Apple Silicon):
  `softwareupdate --install-rosetta --agree-to-license`

## Usage

Build all Python versions (3.10–3.13 by default) as universal2 DMGs:

```bash
./build-all.sh
```

Or restrict to specific versions:

```bash
PYTHON_VERSIONS="3.13" ./build-all.sh
```

To build a single architecture instead, create the environment manually and
set `SECOND_CONDA_ENV_PATH = ""` in `settings.py`:

```bash
./build-env.sh 3.13 arm64
export PYTHON_VERSION="3.13"
python conda_env_to_app.py settings.py --clear --build --dmg
```

### Manual steps (what the scripts do)

1. `./build-env.sh <version> <arch>` creates `opensesame-py<ver>-<arch>`
   conda envs for both `arm64` and `x86_64` and pip-installs `requirements.txt`.
2. `conda_env_to_app.py settings.py --clear --build --dmg` copies the arm64
   env into `OpenSesame.app/Contents/Resources`, merges every Mach-O binary
   with its x86_64 counterpart via `lipo -create`, ad-hoc code signs the
   bundle, and builds the DMG.

The resulting DMG is named e.g. `opensesame_4.1.x-py313-macos-universal2-1.dmg`.
