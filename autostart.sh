#!/bin/bash
#======================================================
#  Enable JMC Scoreboard Auto-Start on Boot
#======================================================

set -e
[ "$(id -u)" -ne 0 ] && { echo "Run as root: sudo bash autostart.sh"; exit 1; }

cp scoreboard.service /etc/systemd/system/scoreboard.service
systemctl daemon-reload
systemctl enable scoreboard.service
systemctl start scoreboard.service

echo ""
echo "✓ Scoreboard will auto-start on every boot!"
echo ""
echo "Commands:"
echo "  sudo systemctl status scoreboard"
echo "  sudo systemctl restart scoreboard"
echo "  sudo systemctl stop scoreboard"
echo "  sudo systemctl disable scoreboard"
echo "  sudo journalctl -u scoreboard -f"
echo ""
