#!/bin/bash
set -e

echo "[SETUP] mulai setup kiosk Debian Live"

# ================= CONFIG =================
APP_URL="https://download1335.mediafire.com/rtvd1lujooogXmi-ahhTgPK_7FoKpzeorfaJ8w5-qHFUUEhiQShJQ2BX1czkfaKujtgQGwLwffsERtd0VBs_ESWNUYLDvQn7wY74gGgPP0dsM5NhWoE69XIicEmLeK6DhevBxD0OSOBtqdhqr98tyY0yBMOr4Xhx5AsbdA6_g2UWQNY/5b6pdlwwd8a6caq/FlashyBoot-1.0.0.AppImage"
APP_NAME="FlashyBoot.AppImage"
KIOSK_DIR="$HOME/kiosk"
XINITRC="$HOME/.xinitrc"
BASH_PROFILE="$HOME/.bash_profile"
# ==========================================

# ================= CHECK =================
echo "[CHECK] cek UEFI"
if [ ! -d /sys/firmware/efi ]; then
  echo "[ERROR] sistem tidak boot via UEFI"
  exit 1
fi

echo "[CHECK] environment OK"

# ================= UPDATE & TOOLS =================
echo "[APT] update & install tool penting"
sudo apt update
sudo apt install -y \
  xorg \
  xinit \
  openbox \
  efibootmgr \
  curl \
  wget \
  ca-certificates

# ================= KIOSK DIR =================
echo "[DIR] buat folder kiosk"
mkdir -p "$KIOSK_DIR"

# ================= DOWNLOAD APPIMAGE =================
APP_PATH="$KIOSK_DIR/$APP_NAME"

if [ ! -f "$APP_PATH" ]; then
  echo "[DOWNLOAD] ambil AppImage"
  wget -O "$APP_PATH" "$APP_URL"
else
  echo "[SKIP] AppImage sudah ada"
fi

chmod +x "$APP_PATH"

# ================= BASH AUTO START X =================
echo "[CONFIG] setup auto start X"

if ! grep -q "startx" "$BASH_PROFILE" 2>/dev/null; then
cat >> "$BASH_PROFILE" <<'EOF'

# auto start X untuk kiosk
if [[ -z "$DISPLAY" && "$(tty)" == "/dev/tty1" ]]; then
  startx
fi
EOF
fi

# ================= XINITRC =================
echo "[CONFIG] setup .xinitrc"

cat > "$XINITRC" <<EOF
#!/bin/sh

# disable screen blank
xset -dpms
xset s off
xset s noblank

# copy app ke RAM
cp "$APP_PATH" /dev/shm/kiosk.AppImage
chmod +x /dev/shm/kiosk.AppImage

# jalankan app
exec /dev/shm/kiosk.AppImage
EOF

chmod +x "$XINITRC"

# ================= DISABLE XFCE UI =================
echo "[CLEANUP] hapus panel dan desktop XFCE"
sudo apt purge -y xfce4-panel xfdesktop4 || true

# ================= DONE =================
echo ""
echo "[DONE] setup selesai"
echo ""
echo "langkah selanjutnya"
echo "1 reboot"
echo "2 saat boot pilih Debian Live"
echo "3 tekan e lalu tambahkan toram"
echo "4 Ctrl+X"
echo ""
echo "kalau boot berhasil, sistem langsung masuk kiosk"
