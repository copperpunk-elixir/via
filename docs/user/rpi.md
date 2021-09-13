# Raspberry Pi Setup

1. Install [fwup](https://github.com/fwup-home/fwup).
2. Download Raspberry Pi firmware image (https://github.com/copperpunk-elixir/via/releases/download/v0.1.1-alpha/via.fw)
3. Burn to micro SD card:
   ```
   sudo fwup <path-to-fw-file>/via.fw
4. Put micro SD card in Pi. Attach Ethernet cable and display (preferably the official [Raspberry Pi 7" Touch Display](https://www.raspberrypi.org/products/raspberry-pi-touch-display/)).
5. Turn on the Pi.