#!/bin/bash
# Detekcija Documents foldera (radi bez obzira na jezik sustava)
DOCUMENTS_DIR=$(xdg-user-dir DOCUMENTS)
TARGET_PATH="$DOCUMENTS_DIR/anaconda3"

if [ -d "$TARGET_PATH" ]; then
    echo "[!] Anaconda je već instalirana u $TARGET_PATH"
else
    echo "[+] Preuzimanje Anaconda instalacijske skripte..."
    wget https://repo.anaconda.com/archive/Anaconda3-2024.10-1-Linux-x86_64.sh -O /tmp/anaconda.sh
    
    echo "[+] Instalacija u $TARGET_PATH (ovo može potrajati)..."
    # -b = batch (automatski), -p = path (putanja)
    bash /tmp/anaconda.sh -b -p "$TARGET_PATH"
    
    echo "[+] Inicijalizacija conde..."
    "$TARGET_PATH/bin/conda" init bash
    "$TARGET_PATH/bin/conda" init zsh
    
    rm /tmp/anaconda.sh
    echo "[OK] Anaconda3 instalirana u Documents."
fi