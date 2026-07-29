#!/bin/bash

# ======================================================
#  RIGOROUS ERROR HANDLING & ENVIRONMENT SETUP
# ======================================================
# set -e: Izlazak ako bilo koja naredba ne uspije
# set -u: Izlazak ako se koristi nedefinirana varijabla
# set -o pipefail: Neuspjeh ako ijedna naredba u pipe-u ne uspije
set -euo pipefail

# Definiranje direktorija skripte
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detekcija korisničkih foldera (radi bez obzira na jezik sustava)
PICTURES_DIR=$(xdg-user-dir PICTURES)
DOCUMENTS_DIR=$(xdg-user-dir DOCUMENTS)
echo "INFO: Pictures → $PICTURES_DIR"
echo "INFO: Documents → $DOCUMENTS_DIR"

echo "====================================================="
echo "     POSTINSTALL STARTED"
echo "====================================================="


# ======================================================
#  0) APT LOCK FIX
# ======================================================
# Ovaj blok je namjerno postavljen prije set -e/u,
# ali ga sada omotavamo u podshell da bi set -e bio na vrhu
(
    set +euo pipefail # Privremeno isključivanje stroge provjere za ovaj neuredni popravak
    echo "[fix] Forcing unlock of APT..."

    sudo killall packagekit 2>/dev/null || true
    sudo killall fwupd 2>/dev/null || true
    sudo killall pop-shop 2>/dev/null || true
    sudo killall apt.systemd.daily 2>/dev/null || true
    sudo killall unattended-upgrade 2>/dev/null || true

    sudo systemctl stop packagekit.service 2>/dev/null || true
    sudo systemctl stop fwupd.service 2>/dev/null || true
    sudo systemctl stop pop-shop.service 2>/dev/null || true
    sudo systemctl stop unattended-upgrades.service 2>/dev/null || true

    sudo rm -f /var/lib/apt/lists/lock || true
    sudo rm -f /var/cache/apt/archives/lock || true
    sudo rm -f /var/lib/dpkg/lock* || true
    sudo rm -f /var/lib/dpkg/lock-frontend || true

    sudo dpkg --configure -a || true

    echo "[fix] APT fully unlocked."
    echo
)


# -------------------------------------------------------
# 1) Ensure dependencies needed for PPAs
# -------------------------------------------------------
echo "[1] Installing base prerequisites..."
sudo apt update
# Dodan 'git' i 'build-essential'
sudo apt install -y software-properties-common ca-certificates curl wget gnupg lsb-release git build-essential

# -------------------------------------------------------
# 2) CLEAN DEFAULT JUNK (free space before heavy installs)
# -------------------------------------------------------
echo "[2] Removing unwanted preinstalled applications..."

sudo apt purge -y \
  libreoffice-base* libreoffice-calc* libreoffice-core* libreoffice-draw* \
  libreoffice-gnome* libreoffice-impress* libreoffice-math* libreoffice-writer* \
  libreoffice-common libreoffice-style* geary yakuake thunderbird \
  gnome-mahjongg gnome-mines gnome-sudoku || true

sudo apt autoremove -y
sudo apt autoclean -y

echo "[2] Cleanup completed."

# -------------------------------------------------------
# 3) FULL SYSTEM UPDATE BEFORE INSTALLATION
# -------------------------------------------------------
echo "[3] Updating system..."
sudo apt update
sudo apt upgrade -y

# -------------------------------------------------------
# 4) ADD CUSTOM REPOSITORIES (PPAs)
# -------------------------------------------------------
echo "[4] Adding custom repositories and third-party apps..."

## Kisak Mesa
if ! grep -Rq "kisak/kisak-mesa" /etc/apt/; then
    echo " → Kisak Mesa (PPA)"
    sudo add-apt-repository -y ppa:kisak/kisak-mesa
fi

## Funkcija za pouzdanu DEB instalaciju
install_deb() {
    local URL=$1
    local FILENAME=$2
    local TMP_DEB="/tmp/$FILENAME.deb"

    echo " → $FILENAME (.deb install)"
    (
        # Preuzimanje: ako ne uspije, izlazak iz podshell-a s greškom
        wget -O "$TMP_DEB" "$URL" || { echo "ERROR: Failed to download $FILENAME DEB." >&2; exit 1; }
        
        # Instalacija i automatsko rješavanje ovisnosti (apt -f install)
        sudo apt install -y "$TMP_DEB" || sudo apt -f install -y
        
        rm -f "$TMP_DEB"
    )
}

# Primjena funkcije:
install_deb "https://mega.nz/linux/repo/xUbuntu_24.04/amd64/megasync-xUbuntu_24.04_amd64.deb" "megasync"
install_deb "https://code-industry.net/public/master-pdf-editor-5.9.60-qt5.x86_64.deb" "masterpdf"

# --- VS Code Instalacija ---
echo "[+] Installing VS Code..."
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
rm -f packages.microsoft.gpg
sudo apt update && sudo apt install -y code

# --- Pokretanje Anaconda skripte ---
bash "$REPO_DIR/install_anaconda.sh"

echo "[4] Repositories added."

# -------------------------------------------------------
# 5) REFRESH APT AFTER REPOS
# -------------------------------------------------------
echo "[5] Refreshing APT after adding repositories..."
sudo apt update

# -------------------------------------------------------
# 6) RUN APT INSTALLER SCRIPT
# -------------------------------------------------------
echo "[6] Installing APT packages..."
bash "$REPO_DIR/apt/install.sh"

# -------------------------------------------------------
# 7) RUN FLATPAK INSTALLER SCRIPT
# -------------------------------------------------------
echo "[7] Installing Flatpak packages..."

# Guarantee flathub is added
if ! flatpak remotes | grep -q flathub; then
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
fi

flatpak uninstall --unused -y || true
bash "$REPO_DIR/flatpak/install.sh"


# ======================================================
# KONFIGURACIJE - PRIMJENJUJU SE PRIJE PROMJENE SHELLA!
# ======================================================

# -------------------------------------------------------
# 8) RESTORE DOTFILES
# -------------------------------------------------------
if [ -d "$REPO_DIR/dotfiles" ]; then
    echo "[8a] Restoring dotfiles..."
    # Korištenje -T za kopiranje Sadržaja izvora u odredište
    cp -rT "$REPO_DIR/dotfiles" "$HOME/"
fi

if [ -d "$REPO_DIR/wal" ]; then
    echo "[8b] Restoring pywal..."
    # Korištenje -T za kopiranje Sadržaja izvora u odredište
    cp -rT "$REPO_DIR/wal" "$HOME/.cache/wal/"
fi

# -------------------------------------------------------
# 9) RESTORE DESKTOP CONFIG (COSMIC / Kitty / ikone)
# -------------------------------------------------------
if [ -d "$REPO_DIR/cosmic" ]; then
    echo "[9] Restoring COSMIC settings..."
    mkdir -p "$HOME/.config/cosmic"
    cp -rT "$REPO_DIR/cosmic" "$HOME/.config/cosmic/"
fi

echo "[9b] Installing Kitty configuration..."
mkdir -p "$HOME/.config/kitty"
cp -rT "$REPO_DIR/kitty" "$HOME/.config/kitty/"

if [ -d "$REPO_DIR/icons" ]; then
    echo "[9c] Restoring icons..."
    mkdir -p "$HOME/.local/share/icons"
    cp -rT "$REPO_DIR/icons" "$HOME/.local/share/icons"
fi

# Postavi ikone direktno u COSMIC config
echo "[9d] Setting COSMIC icon theme..."
mkdir -p "$HOME/.config/cosmic/com.system76.CosmicTk/v1"
echo '"Colloid-teal-dark"' > "$HOME/.config/cosmic/com.system76.CosmicTk/v1/icon_theme"

# -------------------------------------------------------
# 10) WALLPAPER
# -------------------------------------------------------
echo "[10] Installing wallpapers..."

WALLPAPER_SOURCE_DIR="$REPO_DIR/wallpapers"
TARGET_DIR="$PICTURES_DIR/Wallpaper"
TARGET_FILE="$TARGET_DIR/jutro 4K.jpg"

if [ -d "$WALLPAPER_SOURCE_DIR" ]; then
    echo " → Copying ALL wallpapers from repo to $TARGET_DIR..."
    mkdir -p "$TARGET_DIR"
    cp -rT "$WALLPAPER_SOURCE_DIR" "$TARGET_DIR"

    if [ -f "$TARGET_FILE" ]; then
        echo " → Setting COSMIC wallpaper..."
        mkdir -p "$HOME/.config/cosmic/com.system76.CosmicBackground/v1"
        cat > "$HOME/.config/cosmic/com.system76.CosmicBackground/v1/all" << EOF
(
    output: "all",
    source: Path("$TARGET_FILE"),
    filter_by_theme: true,
    rotation_frequency: 300,
    filter_method: Lanczos,
    scaling_mode: Zoom,
    sampling_method: Alphanumeric,
)
EOF
        echo "INFO: COSMIC wallpaper config written."
    else
        echo "ERROR: Default wallpaper file ($TARGET_FILE) not found after copy."
    fi
else
    echo "WARNING: Wallpapers directory not found in repository. Skipping wallpaper setup."
fi
# -------------------------------------------------------
# 11) LANGUAGE/ENVIRONMENT INSTALLS (Go, rbenv, Conda)
# -------------------------------------------------------
echo "[11] Installing language environments (Go, Ruby, Conda)..."

echo " → Running install_go.sh"
bash "$REPO_DIR/languages/install_go.sh"

echo " → Running install_rbenv.sh"
bash "$REPO_DIR/languages/install_rbenv.sh"

# -------------------------------------------------------
# 12) CONFIGURE ZSH (conda + rbenv PATH)
# -------------------------------------------------------
echo "[12] Configuring zsh for conda and rbenv..."

ZSHRC="$HOME/.zshrc"

# rbenv
if ! grep -q 'rbenv' "$ZSHRC" 2>/dev/null; then
cat >> "$ZSHRC" << 'EOF'

# rbenv
export RBENV_ROOT="$HOME/.rbenv"
export PATH="$RBENV_ROOT/bin:$PATH"
eval "$(rbenv init -)"
EOF
fi

# conda
if [ -f "$DOCUMENTS_DIR/anaconda3/bin/conda" ] && ! grep -q 'anaconda3' "$ZSHRC" 2>/dev/null; then
    "$DOCUMENTS_DIR/anaconda3/bin/conda" init zsh
fi

# -------------------------------------------------------
# 13) FINAL CLEANUP
# -------------------------------------------------------
echo "[13] Final cleanup..."
sudo apt autoremove -y
sudo apt autoclean -y
flatpak uninstall --unused -y || true

echo "====================================================="
echo "     POSTINSTALL COMPLETE"
echo "====================================================="
echo "SUSTAV ĆE IZVESTI REBOOT SADA."
sleep 3
reboot