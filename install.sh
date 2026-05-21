#!/bin/bash
#======================================================
#  JMC Pi Scoreboard - Bootstrap Installer
#  Optimised for low-bandwidth / slow connections
#
#  One command on your Pi:
#    curl -fsSL https://raw.githubusercontent.com/justincrowner1981-cell/JMCScoreboard/main/install.sh | sudo bash
#======================================================

REPO="https://raw.githubusercontent.com/justincrowner1981-cell/JMCScoreboard/main"
DEST="/home/${SUDO_USER:-pi}/scoreboard"
FILES="scoreboard.py setup.sh autostart.sh scoreboard.service"

# Prevent apt from hanging waiting for user input
export DEBIAN_FRONTEND=noninteractive

RED=$(printf '\033[0;31m')
GREEN=$(printf '\033[0;32m')
CYAN=$(printf '\033[0;36m')
BOLD=$(printf '\033[1m')
NC=$(printf '\033[0m')

die()  { echo ""; echo "${RED}ERROR: $1${NC}"; echo ""; exit 1; }
ok()   { echo "  ${GREEN}[OK]${NC}  $1"; }
info() { echo "  ${CYAN}----${NC}  $1"; }

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
echo "    JMC Pi Scoreboard - Auto Install"
echo "  ======================================${NC}"
echo ""

[ "$(id -u)" -ne 0 ] && die "Run as root: curl ... | sudo bash"

# ── Step 1: Update package lists ──────────────────────────────────────────────
info "Step 1/5: Updating apt package lists..."
apt-get update
if [ $? -ne 0 ]; then
  echo "  Retrying in 10s..."
  sleep 10
  apt-get update || die "apt-get update failed. Check your internet connection."
fi
ok "Package lists updated"

# ── Step 2: Install curl and git ──────────────────────────────────────────────
info "Step 2/5: Installing curl and git..."
apt-get install -y --no-install-recommends curl git
if [ $? -ne 0 ]; then
  echo "  Retrying in 10s..."
  sleep 10
  apt-get install -y --no-install-recommends curl git     || die "Failed to install curl/git. Check your internet connection."
fi
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
  # curl handles its own retries; no wrapper needed
  curl -fsSL --connect-timeout 30 --max-time 60 --retry 3 --retry-delay 5     "$URL" -o "${DEST}/${FILE}"     || die "Failed to download $FILE. Check internet and that the repo is public: $URL"
  ok "$FILE"
done

chmod +x "${DEST}/setup.sh" "${DEST}/autostart.sh"
ok "All files downloaded and permissions set"

# ── Step 5: Run setup.sh ──────────────────────────────────────────────────────
info "Step 5/5: Running setup.sh (takes 5-15 minutes on slow connections)..."
echo ""
cd "$DEST"
bash setup.sh
[ $? -ne 0 ] && die "setup.sh failed. See output above for details."

echo ""
echo "${GREEN}${BOLD}  ======================================"
echo "    Installation Complete!"
echo "  ======================================${NC}"
echo ""
echo "  Rebooting in 5 seconds... (Ctrl+C to cancel)"
echo ""
sleep 5
reboot
