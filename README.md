# JMC Pi NHL Scoreboard

### 64×32 P5 LED Matrix + Adafruit RGB Matrix Bonnet/HAT

Real-time NHL scoreboard running on a Raspberry Pi, driving a 64×32 P5 LED matrix panel.
Supports live score polling, broadcast sync delay, and auto-start on boot.

---

## Hardware Required

| Part | Notes |
|------|-------|
| Raspberry Pi (Zero 2W / 3B+ / 4) | Any model |
| Adafruit RGB Matrix Bonnet | Solderless, recommended |
| 64×32 P5 LED Matrix Panel | P5 = 5mm pixel pitch |
| 5V 4A Barrel Jack PSU | Powers Pi + panel via Bonnet |
| 16-pin IDC ribbon cable | Usually included with panel |

---

## Quick Start — One Command Install

SSH into your Pi and run this single command. It downloads all files, installs dependencies, and reboots automatically.

```bash
# Step 1 — SSH into your Pi
ssh pi@raspberrypi.local

# Step 2 — Run the bootstrap installer (does everything)
curl -fsSL https://raw.githubusercontent.com/justincrowner1981-cell/JMCScoreboard/main/install.sh | sudo bash

# Step 3 — After reboot, test the scoreboard
sudo python3 ~/scoreboard/scoreboard.py

# Step 4 — (Optional) Enable auto-start on every boot
cd ~/scoreboard && sudo bash autostart.sh
```

---

## Broadcast Sync Delay

TV broadcasts are delayed relative to real-time:

| Delay | Use case |
|-------|----------|
| 0 s | In-arena / real-time |
| 10–30 s | Streaming (Hulu, ESPN+) |
| 30–90 s | Cable / satellite |

Edit `scoreboard.py`:
```python
BROADCAST_DELAY_SECONDS = 30  # adjust to your broadcast
```

The delay buffer holds each score update in a queue and only releases it to the display
after the configured seconds have elapsed — preventing spoilers.

---

## Configuration

Edit the constants at the top of `scoreboard.py`:

| Setting | Default | Description |
|---------|---------|-------------|
| `BROADCAST_DELAY_SECONDS` | 0 | Sync delay (seconds) |
| `GPIO_SLOWDOWN` | 2 | Increase to 3–4 if flickering |
| `BRIGHTNESS` | 80 | Display brightness 0–100 |
| `POLL_INTERVAL_SECONDS` | 30 | How often to check NHL scores |

---

## Wiring

1. Attach the **Bonnet** to the Pi GPIO header (all 40 pins)
2. Connect the **ribbon cable**: Bonnet → panel **INPUT** port
3. Connect **5V 4A PSU** to the Bonnet barrel jack

> ⚠️ Never disconnect the ribbon cable while powered on.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Nothing shows | Check ribbon is in INPUT port; check PSU |
| Flickering / ghosting | Increase `GPIO_SLOWDOWN` to 3 or 4 |
| Dim display | Increase `BRIGHTNESS` |
| Red/Blue swapped | Add `options.led_rgb_sequence = "RBG"` in `create_matrix()` |
| `rgbmatrix` not found | Run `sudo bash setup.sh` then reboot |

---

## File Reference

| File | Purpose |
|------|---------|
| `install.sh` | **Bootstrap** — one curl command installs everything |
| `scoreboard.py` | Main scoreboard (runs on Pi) |
| `setup.sh` | One-click dependency installer (called by install.sh) |
| `autostart.sh` | Enable auto-start on boot |
| `scoreboard.service` | systemd service definition |
| `README.md` | This file |
