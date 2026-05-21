#!/bin/bash
#======================================================
#  JMC Pi Scoreboard - Bootstrap Installer
#
#  One command on your Pi:
#    curl -fsSL https://raw.githubusercontent.com/justincrowner1981-cell/JMCScoreboard/main/install.sh | sudo bash
#======================================================

# NOTE: No set -e here — we handle errors manually with clear messages

REPO="https://raw.githubusercontent.com/justincrowner1981-cell/JMCScoreboard/main"
DEST="/home/${SUDO_USER:-pi}/scoreboard"
FILES="scoreboard.py setup.sh autostart.sh scoreboard.service"

RED=$(printf '\033[0;31m')
GREEN=$(printf '\033[0;32m')
CYAN=$(printf '\033[0;36m')
BOLD=$(printf '\033[1m')
NC=$(printf '\033[0m')

die() { echo ""; echo "${RED}ERROR: $1${NC}"; echo ""; exit 1; }
ok()  { echo "  ${GREEN}[OK]${NC}  $1"; }
info(){ echo "  ${CYAN}----${NC}  $1"; }

echo ""
echo "${CYAN}${BOLD}  ======================================"
echo "    JMC Pi Scoreboard - Auto Install"
echo "  ======================================${NC}"
echo ""

# Must run as root
if [ "$(id -u)" -ne 0 ]; then
  die "Run as root: curl ... | sudo bash"
fi

# ── Step 1: Update package lists ──────────────────────────────────────────────
info "Step 1/5: Updating apt package lists..."
apt-get update -y || die "apt-get update failed. Check your internet connection."
ok "Package lists updated"

# ── Step 2: Install curl and git ──────────────────────────────────────────────
info "Step 2/5: Installing curl and git..."
apt-get install -y curl git || die "Failed to install curl/git. Check internet and apt sources."
ok "curl and git ready"

# ── Step 3: Create destination directory ──────────────────────────────────────
info "Step 3/5: Creating $DEST ..."
mkdir -p "$DEST" || die "Could not create directory $DEST"
ok "Directory ready: $DEST"

# ── Step 4: Download scoreboard files ─────────────────────────────────────────
info "Step 4/5: Downloading scoreboard files from GitHub..."
for FILE in $FILES; do
  URL="${REPO}/${FILE}"
  echo "    Downloading ${FILE}..."
  curl -fsSL "$URL" -o "${DEST}/${FILE}"
  if [ $? -ne 0 ]; then
    die "Failed to download $FILE from $URL\nCheck internet and that the GitHub repo is public."
  fi
  ok "$FILE"
done

chmod +x "${DEST}/setup.sh" "${DEST}/autostart.sh"
ok "All files downloaded and permissions set"

# ── Step 5: Run setup.sh ──────────────────────────────────────────────────────
info "Step 5/5: Running setup.sh (this takes 5-10 minutes)..."
echo ""
cd "$DEST"
bash setup.sh
if [ $? -ne 0 ]; then
  die "setup.sh failed. Check the output above for the specific error."
fi

echo ""
echo "${GREEN}${BOLD}  ======================================"
echo "    Installation Complete!"
echo "  ======================================${NC}"
echo ""
echo "  Rebooting in 5 seconds..."
echo "  (Press Ctrl+C to cancel)"
echo ""
sleep 5
reboot
