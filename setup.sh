#!/bin/bash
#======================================================
#  JMC Pi Scoreboard - One-Click Setup
#  Raspberry Pi + Adafruit RGB Matrix Bonnet/HAT
#  Usage: sudo bash setup.sh
#======================================================

# No set -e — we handle errors manually with clear messages

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
step "Installing dependencies"
apt-get install -y python3 python3-pip python3-dev git build-essential   libgraphicsmagick++-dev libwebp-dev   || die "Failed to install dependencies. Try running: apt-get update first."
ok "Dependencies installed"

# ── Step 2: Clone rpi-rgb-led-matrix ──────────────────────────────────────────
step "Setting up rpi-rgb-led-matrix library"
HOME_DIR="/home/${SUDO_USER:-pi}"
LIB_DIR="${HOME_DIR}/rpi-rgb-led-matrix"
if [ -d "$LIB_DIR" ]; then
  warn "Already exists — pulling updates..."
  git -C "$LIB_DIR" pull --quiet && ok "Library updated" || warn "Pull failed, using existing copy"
else
  git clone --depth=1 https://github.com/hzeller/rpi-rgb-led-matrix.git "$LIB_DIR"     && ok "Cloned to $LIB_DIR" || die "git clone failed. Check internet connection."
fi

# ── Step 3: Build C library ───────────────────────────────────────────────────
step "Building C library (takes ~1-2 minutes)"
make -C "$LIB_DIR/lib" -j$(nproc)   && ok "C library compiled" || die "C library build failed. Check gcc/make are installed."

# ── Step 4: Build and install Python bindings ─────────────────────────────────
step "Building Python bindings"
cd "$LIB_DIR/bindings/python"
make build-python PYTHON=$(which python3)   && ok "Python bindings built" || die "Python bindings build failed."
make install-python PYTHON=$(which python3)   && ok "Python bindings installed" || die "Python bindings install failed."

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
python3 -c "import rgbmatrix; print('rgbmatrix: OK')"   && ok "rgbmatrix module importable"   || warn "Import test failed — try rebooting first, then re-run this script"

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
