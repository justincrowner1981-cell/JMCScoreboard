#!/bin/bash
#======================================================
#  JMC Pi Scoreboard - One-Click Setup
#  Optimised for low-bandwidth / slow connections
#  Usage: sudo bash setup.sh
#======================================================

# Prevent apt from hanging waiting for user input
export DEBIAN_FRONTEND=noninteractive
# Kill git if it stalls (no data for 30s, or total transfer < 1KB/s for 60s)
export GIT_HTTP_LOW_SPEED_LIMIT=1024
export GIT_HTTP_LOW_SPEED_TIME=60

RED=$(printf '\033[0;31m')
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[1;33m')
CYAN=$(printf '\033[0;36m')
BOLD=$(printf '\033[1m')
NC=$(printf '\033[0m')

STEPS=6; STEP=0

step() { STEP=$((STEP+1)); echo ""; echo "${CYAN}${BOLD}[${STEP}/${STEPS}] $1${NC}"; }
ok()   { echo "  ${GREEN}[OK]${NC}  $1"; }
warn() { echo "  ${YELLOW}[!!]${NC}  $1"; }
die()  { echo ""; echo "${RED}FAILED: $1${NC}"; echo ""; exit 1; }

# Retry wrapper: retry_cmd <attempts> <delay_sec> <cmd...>
retry_cmd() {
  local attempts=$1; local delay=$2; shift 2
  local i=1
  while [ $i -le $attempts ]; do
    "$@" && return 0
    echo "  [!!] Attempt $i/$attempts failed. Retrying in ${delay}s..."
    sleep $delay
    i=$((i+1))
  done
  return 1
}

echo ""
echo "${CYAN}${BOLD}  ======================================"
echo "    JMC Pi NHL Scoreboard - Setup"
echo "  ======================================${NC}"
echo ""

[ "$(id -u)" -ne 0 ] && die "Run as root: sudo bash setup.sh"

PI_MODEL=$(grep "Model" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs)
[ -n "$PI_MODEL" ] && echo "  Pi: ${BOLD}$PI_MODEL${NC}"
echo ""

# ── Step 1: Install dependencies ──────────────────────────────────────────────
step "Installing dependencies (--no-install-recommends saves ~200MB)"
apt-get update -y || die "apt-get update failed. Check your internet connection."
apt-get install -y --no-install-recommends   python3 python3-dev cython3 git build-essential   libgraphicsmagick++-dev libwebp-dev
if [ $? -ne 0 ]; then
  echo "  First attempt failed. Retrying in 15s..."
  sleep 15
  apt-get install -y --no-install-recommends     python3 python3-dev cython3 git build-essential     libgraphicsmagick++-dev libwebp-dev     || die "Failed to install dependencies after 2 attempts. Check your internet connection."
fi
ok "Dependencies installed"

# ── Step 2: Clone rpi-rgb-led-matrix ──────────────────────────────────────────
step "Setting up rpi-rgb-led-matrix library"
HOME_DIR="/home/${SUDO_USER:-pi}"
LIB_DIR="${HOME_DIR}/rpi-rgb-led-matrix"
# A complete clone always has a Makefile at the root
if [ -f "$LIB_DIR/Makefile" ]; then
  ok "Library already fully cloned — skipping to Step 3"
elif [ -d "$LIB_DIR" ]; then
  warn "Partial/incomplete clone detected — removing and re-cloning..."
  rm -rf "$LIB_DIR"
  echo "  Cloning (shallow, minimal download ~5MB)..."
  timeout 300 git clone --depth=1 --single-branch --branch master     https://github.com/hzeller/rpi-rgb-led-matrix.git "$LIB_DIR"
  if [ $? -ne 0 ]; then
    echo "  First attempt failed. Retrying in 10s..."
    sleep 10
    timeout 300 git clone --depth=1 --single-branch --branch master       https://github.com/hzeller/rpi-rgb-led-matrix.git "$LIB_DIR"       || die "git clone failed after 2 attempts. Check internet connection."
  fi
  ok "Cloned to $LIB_DIR"
else
  echo "  Cloning (shallow, minimal download ~5MB)..."
  timeout 300 git clone --depth=1 --single-branch --branch master     https://github.com/hzeller/rpi-rgb-led-matrix.git "$LIB_DIR"
  if [ $? -ne 0 ]; then
    echo "  First attempt failed. Retrying in 10s..."
    sleep 10
    timeout 300 git clone --depth=1 --single-branch --branch master       https://github.com/hzeller/rpi-rgb-led-matrix.git "$LIB_DIR"       || die "git clone failed after 2 attempts. Check internet connection."
  fi
  ok "Cloned to $LIB_DIR"
fi

# ── Step 3: Build C library ───────────────────────────────────────────────────
step "Building C library (~1-3 minutes on Pi Zero)"
# Check if the .a library file already exists (proof of a successful build)
if [ -f "$LIB_DIR/lib/librgbmatrix.a" ]; then
  ok "C library already built — skipping"
else
  make -C "$LIB_DIR/lib" -j$(nproc)     && ok "C library compiled"     || die "C library build failed. Is build-essential installed? Run: apt-get install -y build-essential"
fi

# ── Step 4: Build and install Python bindings ─────────────────────────────────
step "Building Python bindings"
# Check if rgbmatrix is already importable (already installed)
if python3 -c "import rgbmatrix" 2>/dev/null; then
  ok "Python bindings already installed — skipping"
else
  # Verify cython3 is available before attempting the build
  python3 -c "import Cython" 2>/dev/null || die "cython3 not found — run: apt-get install -y cython3"
  python3-config --includes >/dev/null 2>&1 || die "python3-dev not found — run: apt-get install -y python3-dev"

  cd "$LIB_DIR/bindings/python"

  # Try Makefile approach first (preferred — zero PyPI downloads)
  if make build-python PYTHON=python3 2>&1; then
    ok "Python bindings compiled (make)"
    make install-python PYTHON=python3       && ok "Python bindings installed"       || die "make install-python failed"
  else
    # Fallback: build via setup.py directly (works on all distros)
    warn "make build-python failed — falling back to setup.py"
    python3 setup.py build       && ok "Python bindings compiled (setup.py)"       || die "setup.py build failed — check cython3 and python3-dev"
    python3 setup.py install       && ok "Python bindings installed (setup.py)"       || die "setup.py install failed"
  fi
fi

# ── Step 5: Configure boot settings ──────────────────────────────────────────
step "Configuring boot settings (disabling audio for matrix PWM)"
BOOT_CFG="/boot/config.txt"
[ -f "/boot/firmware/config.txt" ] && BOOT_CFG="/boot/firmware/config.txt"
if grep -q "dtparam=audio=on" "$BOOT_CFG" 2>/dev/null; then
  sed -i 's/dtparam=audio=on/dtparam=audio=off/' "$BOOT_CFG" && ok "Audio disabled in $BOOT_CFG"
elif ! grep -q "dtparam=audio=off" "$BOOT_CFG" 2>/dev/null; then
  echo "dtparam=audio=off" >> "$BOOT_CFG" && ok "Audio disabled in $BOOT_CFG"
else
  ok "Audio already disabled"
fi
BLACKLIST="/etc/modprobe.d/blacklist-rgb-matrix.conf"
if ! grep -q "snd_bcm2835" "$BLACKLIST" 2>/dev/null; then
  printf '# Disable audio to prevent LED matrix interference\nblacklist snd_bcm2835\n' > "$BLACKLIST"
  ok "Audio kernel module blacklisted"
else
  ok "Audio module already blacklisted"
fi

# ── Step 6: Verify ────────────────────────────────────────────────────────────
step "Verifying installation"
python3 -c "import rgbmatrix; print('rgbmatrix: OK')"   && ok "rgbmatrix module importable"   || warn "Import test failed — reboot first, then re-run if needed"

echo ""
echo "${GREEN}${BOLD}  ======================================"
echo "    Setup Complete!"
echo "  ======================================${NC}"
echo ""
echo "  Next steps:"
echo "  1. Reboot:     sudo reboot"
echo "  2. Test:       sudo python3 ~/scoreboard/scoreboard.py"
echo "  3. Auto-boot:  cd ~/scoreboard && sudo bash autostart.sh  (optional)"
echo ""
