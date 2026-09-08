#!/usr/bin/env bash
# Helper script to create a Python virtualenv, install packages and register an ipykernel
# Usage: add_kernel.sh -n NAME [-p /path/to/python] [-d "Display Name"] [-r "pkg1 pkg2,..."] [-P /prefix]

set -euo pipefail

show_help(){
  cat <<EOF
add_kernel.sh - create a Python virtualenv, install ipykernel and register a Jupyter kernel

Usage:
  add_kernel.sh -n NAME [-p PYTHON] [-d "Display Name"] [-r "pkg1 pkg2,..."] [-P PREFIX]

Options:
  -n NAME         Kernel/environment name (required). Also used for venv directory name.
  -p PYTHON       Path to python executable to use (default: python3 from PATH).
  -d DISPLAY      Human-friendly display name for the kernel (default: "Python (NAME)").
  -r PACKAGES     Space or comma-separated list of pip packages to install in the venv (optional).
  -P PREFIX       If provided, installs the kernelspec with --prefix=PREFIX instead of --sys-prefix
  -h              Show this help and exit

Examples:
  # Create venv at /opt/venvs/mlenv using system python, install ipykernel and register kernel
  add_kernel.sh -n mlenv -r "numpy pandas scikit-learn" -d "Python (mlenv)"

  # Use specific python interpreter
  add_kernel.sh -n py312 -p /opt/pyenv/versions/3.12.2/bin/python -r "ipykernel" -d "Python (3.12)"

Notes:
  - By default the script creates venvs under /opt/venvs/<NAME>. Adjust VENV_BASE variable below if desired.
  - To make the kernel visible to all JupyterHub users, run this script as root inside the container and allow --sys-prefix (default) or use --prefix=/usr/local when appropriate.
EOF
}

VENV_BASE=/opt/venvs
NAME=""
PYTHON=""
DISPLAY=""
PKGS=""
PREFIX=""

while getopts ":n:p:d:r:P:h" opt; do
  case ${opt} in
    n) NAME="$OPTARG" ;;
    p) PYTHON="$OPTARG" ;;
    d) DISPLAY="$OPTARG" ;;
    r) PKGS="$OPTARG" ;;
    P) PREFIX="$OPTARG" ;;
    h) show_help; exit 0 ;;
    \?) echo "Invalid option: -$OPTARG" >&2 ; show_help; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument." >&2 ; show_help; exit 1 ;;
  esac
done

if [ -z "$NAME" ]; then
  echo "ERROR: -n NAME is required" >&2
  show_help
  exit 1
fi

if [ -z "$DISPLAY" ]; then
  DISPLAY="Python ($NAME)"
fi

if [ -z "$PYTHON" ]; then
  PYTHON=$(command -v python3 || true) || true
  if [ -z "$PYTHON" ]; then
    echo "ERROR: python3 not found in PATH and no -p provided" >&2
    exit 1
  fi
fi

VENV_DIR="$VENV_BASE/$NAME"
mkdir -p "${VENV_DIR%/*}"

echo "Creating virtualenv at: $VENV_DIR using python: $PYTHON"
"$PYTHON" -m venv "$VENV_DIR"

# Activate the venv in a subshell to install packages
set +u
. "$VENV_DIR/bin/activate"
set -u

echo "Upgrading pip/wheel and installing ipykernel"
python -m pip install --upgrade pip wheel
python -m pip install ipykernel

if [ -n "$PKGS" ]; then
  # support comma or space separated lists
  PKGS_CLEAN=$(echo "$PKGS" | tr ',' ' ')
  echo "Installing extra pip packages: $PKGS_CLEAN"
  python -m pip install $PKGS_CLEAN
fi

# Register the kernel
if [ -n "$PREFIX" ]; then
  echo "Installing kernelspec with --prefix=$PREFIX"
  python -m ipykernel install --prefix="$PREFIX" --name "$NAME" --display-name "$DISPLAY"
else
  echo "Installing kernelspec with --sys-prefix"
  python -m ipykernel install --sys-prefix --name "$NAME" --display-name "$DISPLAY"
fi

# Show result
echo "Kernel installed. Listing kernelspecs:"
jupyter kernelspec list

echo "Done. Virtualenv located at: $VENV_DIR"

# End
