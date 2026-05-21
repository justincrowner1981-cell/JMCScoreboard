#!/bin/bash
#======================================================
#  JMC Pi Scoreboard - One-Click Setup
#  Raspberry Pi + Adafruit RGB Matrix Bonnet/HAT
#  Usage: sudo bash setup.sh
#======================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

STEPS=7; STEP=0; ERRORS=()

step() { STEP=$((STEP+1)); echo ""; echo -e "${CYAN}${BOLD}[${STEP}/${STEPS}] $1${NC}"; }
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; ERRORS+=("$1"); }

echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║  🏒  JMC Pi NHL Scoreboard — Setup       ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"

[ "$(id -u)" -ne 0 ] && { echo -e "${RED}Run as root: sudo bash setup.sh${NC}"; exit 1; }

PI_MODEL=$(grep "Model" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs)
[ -n "$PI_MODEL" ] && echo -e "  Pi: ${BOLD}$PI_MODEL${NC}"

step "Updating packages"
apt-get update -qq && ok "Updated" || fail "apt-get update failed"
apt-get install -y -qq python3 python3-pip python3-dev git build-essential \
  libgraphicsmagick++-dev libwebp-dev && ok "Dependencies installed" || fail "Install failed"

step "Setting up rpi-rgb-led-matrix library"
HOME_DIR="/home/${SUDO_USER:-pi}"
LIB_DIR="${HOME_DIR}/rpi-rgb-led-matrix"
if [ -d "$LIB_DIR" ]; then
  warn "Already exists — updating..."
  git -C "$LIB_DIR" pull --quiet && ok "Updated"
else
  git clone --quiet https://github.com/hzeller/rpi-rgb-led-matrix.git "$LIB_DIR" \
    && ok "Cloned to $LIB_DIR" || { fail "Clone failed"; exit 1; }
fi

step "Building C library"
make -C "$LIB_DIR/lib" -j$(nproc) --silent && ok "Built" || { fail "Build failed"; exit 1; }

step "Building Python bindings"
cd "$LIB_DIR/bindings/python"
make build-python PYTHON=$(which python3) --silent && ok "Built" || { fail "Build failed"; exit 1; }
make install-python PYTHON=$(which python3) --silent && ok "Installed" || { fail "Install failed"; exit 1; }

step "Configuring boot settings"
BOOT_CFG="/boot/config.txt"
[ -f "/boot/firmware/config.txt" ] && BOOT_CFG="/boot/firmware/config.txt"
if grep -q "dtparam=audio=on" "$BOOT_CFG" 2>/dev/null; then
  sed -i 's/dtparam=audio=on/dtparam=audio=off/' "$BOOT_CFG" && ok "Audio disabled"
elif ! grep -q "dtparam=audio=off" "$BOOT_CFG" 2>/dev/null; then
  echo "dtparam=audio=off" >> "$BOOT_CFG" && ok "Audio disabled"
else
  ok "Audio already disabled"
fi
BLACKLIST="/etc/modprobe.d/blacklist-rgb-matrix.conf"
if ! grep -q "snd_bcm2835" "$BLACKLIST" 2>/dev/null; then
  echo "blacklist snd_bcm2835" >> "$BLACKLIST" && ok "Audio module blacklisted"
fi

step "Setting up scoreboard directory"
SCORE_DIR="${HOME_DIR}/scoreboard"
mkdir -p "$SCORE_DIR"
[ -f "${HOME_DIR}/scoreboard.py" ] && cp "${HOME_DIR}/scoreboard.py" "$SCORE_DIR/"
chown -R "${SUDO_USER:-pi}:${SUDO_USER:-pi}" "$SCORE_DIR" 2>/dev/null || true
ok "Ready: $SCORE_DIR"

step "Verifying installation"
python3 -c "import rgbmatrix; print('OK')" && ok "rgbmatrix importable" \
  || warn "Try rebooting first, then re-run"

echo ""
if [ ${#ERRORS[@]} -eq 0 ]; then
  echo -e "${GREEN}${BOLD}  ✅  Setup Complete!${NC}"
  echo ""
  echo -e "  1. Reboot:   ${CYAN}sudo reboot${NC}"
  echo -e "  2. Test:     ${CYAN}sudo python3 ~/scoreboard/scoreboard.py${NC}"
  echo -e "  3. Autoboot: ${CYAN}sudo bash autostart.sh${NC} (optional)"
else
  echo -e "${RED}${BOLD}  ⚠️  Completed with errors${NC}"
  for err in "${ERRORS[@]}"; do echo -e "    ${RED}✗${NC} $err"; done
fi
echo ""
