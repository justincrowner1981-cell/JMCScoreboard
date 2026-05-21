#!/bin/bash
#======================================================
#  JMC Pi Scoreboard — Bootstrap Installer
#
#  Run this ONE command on your Pi (requires internet):
#
#    curl -fsSL https://raw.githubusercontent.com/justincrowner1981-cell/JMCScoreboard/main/install.sh | sudo bash
#
#  It will:
#    1. Download all scoreboard files from GitHub
#    2. Run setup.sh to install dependencies
#    3. Reboot the Pi
#======================================================

set -e

REPO="https://raw.githubusercontent.com/justincrowner1981-cell/JMCScoreboard/main"
DEST="/home/${SUDO_USER:-pi}/scoreboard"
FILES="scoreboard.py setup.sh autostart.sh scoreboard.service"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║  🏒  JMC Pi Scoreboard — Auto Install    ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"

[ "$(id -u)" -ne 0 ] && { echo -e "${RED}Run as root: curl ... | sudo bash${NC}"; exit 1; }

# Ensure curl and git are available
apt-get install -y -qq curl git 2>/dev/null || true

# Create destination directory
mkdir -p "$DEST"
echo -e "  Installing to: ${BOLD}$DEST${NC}"
echo ""

# Download each file from GitHub
for FILE in $FILES; do
  URL="${REPO}/${FILE}"
  echo -e "  Downloading ${CYAN}${FILE}${NC}..."
  curl -fsSL "$URL" -o "${DEST}/${FILE}" || { echo -e "  ${RED}✗ Failed to download $FILE${NC}"; exit 1; }
  echo -e "  ${GREEN}✓${NC} $FILE"
done

# Make scripts executable
chmod +x "${DEST}/setup.sh" "${DEST}/autostart.sh"
echo ""
echo -e "  ${GREEN}All files downloaded!${NC}"
echo ""

# Run setup
echo -e "  ${CYAN}${BOLD}Running setup.sh...${NC}"
echo ""
cd "$DEST"
bash setup.sh

echo ""
echo -e "  ${GREEN}${BOLD}✅  Installation complete!${NC}"
echo ""
echo -e "  Rebooting in 5 seconds to apply settings..."
echo -e "  (Press Ctrl+C to cancel reboot)"
echo ""
sleep 5
reboot
