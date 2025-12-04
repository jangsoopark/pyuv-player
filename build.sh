#!/usr/bin/env bash
#
# macOS build script for pyuv-player
# - Installs required Homebrew packages
# - Generates local wxWidgets m4 macros
# - Regenerates autotools files (aclocal/autoconf/autoheader/automake)
# - Runs ./configure with wx-config flags
# - Runs make -j
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo ">>> Starting build script"
echo ">>> Working directory: $SCRIPT_DIR"

# ----------------------------------------------------
# 1. Check Homebrew
# ----------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  echo "ERROR: Homebrew is not installed."
  echo "Please install it from https://brew.sh and re-run this script."
  exit 1
fi

# ----------------------------------------------------
# 2. Install required packages
# ----------------------------------------------------
echo ">>> Installing required Homebrew packages: autoconf, automake, libtool, pkg-config, wxwidgets"

BREW_PKGS=(
  autoconf
  automake
  libtool
  pkg-config
  wxwidgets
)

for pkg in "${BREW_PKGS[@]}"; do
  if brew list --formula | grep -q "^${pkg}\$"; then
    echo "  - $pkg already installed"
  else
    echo "  - Installing $pkg ..."
    brew install "$pkg"
  fi
done

echo ">>> Homebrew packages ready"

# ----------------------------------------------------
# 3. Check wx-config
# ----------------------------------------------------
if ! command -v wx-config >/dev/null 2>&1; then
  echo "ERROR: wx-config not found. wxwidgets installation failed."
  exit 1
fi

echo ">>> wxWidgets version: $(wx-config --version)"

# ----------------------------------------------------
# 4. Create local m4 macro for wxWidgets
# ----------------------------------------------------
echo ">>> Creating m4/local-wx.m4"

mkdir -p m4

cat > m4/local-wx.m4 << 'EOF'
dnl Minimal local definitions for legacy wxWidgets macros

AC_DEFUN([AM_OPTIONS_WXCONFIG], [
  AC_PATH_PROG([WX_CONFIG], [wx-config], [no])
  if test "x$WX_CONFIG" = "xno"; then
    AC_MSG_ERROR([wx-config not found])
  fi
])

AC_DEFUN([AM_PATH_WXCONFIG], [
  AC_PATH_PROG([WX_CONFIG], [wx-config], [no])
  if test "x$WX_CONFIG" = "xno"; then
    AC_MSG_ERROR([wx-config not found])
  fi

  WX_CXXFLAGS=`$WX_CONFIG --cxxflags`
  WX_LIBS=`$WX_CONFIG --libs`

  AC_SUBST([WX_CXXFLAGS])
  AC_SUBST([WX_LIBS])

  wxWin=1
])
EOF

# ----------------------------------------------------
# 5. Clean previous autotools outputs
# ----------------------------------------------------
echo ">>> Cleaning old autotools outputs"

rm -f aclocal.m4 configure config.log config.status || true
rm -rf autom4te.cache || true

# ----------------------------------------------------
# 6. Run autotools
# ----------------------------------------------------
echo ">>> Running aclocal"
aclocal -I m4

echo ">>> Running autoconf"
autoconf

echo ">>> Running autoheader"
autoheader

echo ">>> Running automake --add-missing"
automake --add-missing

# ----------------------------------------------------
# 7. Run configure
# ----------------------------------------------------
echo ">>> Running ./configure"

WX_CXXFLAGS="$(wx-config --cxxflags)"
WX_LIBS="$(wx-config --libs)"

echo "    WX_CXXFLAGS = $WX_CXXFLAGS"
echo "    WX_LIBS     = $WX_LIBS"

./configure CXXFLAGS="${WX_CXXFLAGS} -g -O2" LIBS="${WX_LIBS}"

# ----------------------------------------------------
# 8. Build with make
# ----------------------------------------------------
echo ">>> Starting make"

CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
make -j"${CPU_CORES}"

echo ">>> Build completed successfully"
echo ">>> Executables should appear in the src/ directory"
