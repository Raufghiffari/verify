#!/bin/sh
set -e

echo "=== VERIFY KIOSK AUTO INSTALL ==="

# ================= REPO =================
sed -i 's/^#http/http/' /etc/apk/repositories
apk update

# ================= PACKAGES =================
apk add --no-cache \
  xorg-server \
  xf86-video-vesa \
  xf86-input-libinput \
  mesa \
  dbus \
  udev \
  nodejs \
  npm \
  electron \
  git \
  ttf-dejavu \
  efibootmgr

# ================= DBUS =================
rc-update add dbus default
service dbus start || true

# ================= AUTO LOGIN ROOT =================
sed -i 's|^tty1::respawn:.*|tty1::respawn:/bin/login -f root|' /etc/inittab

# ================= DISABLE EXTRA TTY =================
for t in tty2 tty3 tty4 tty5 tty6; do
  rc-update del getty $t 2>/dev/null || true
done

# ================= APP =================
mkdir -p /opt/kiosk
cd /opt/kiosk

if [ ! -d verify ]; then
  git clone https://github.com/Raufghiffari/verify.git
fi

cd verify
npm install --omit=dev

# ================= X INIT =================
cat > /root/.xinitrc << 'EOF'
#!/bin/sh
export ELECTRON_DISABLE_SECURITY_WARNINGS=true
cd /opt/kiosk/verify
exec electron .
EOF

chmod +x /root/.xinitrc

# ================= AUTOSTART =================
cat > /etc/local.d/kiosk.start << 'EOF'
#!/bin/sh
startx &
EOF

chmod +x /etc/local.d/kiosk.start
rc-update add local default

echo "=== INSTALL DONE ==="
echo "Reboot to start kiosk"
