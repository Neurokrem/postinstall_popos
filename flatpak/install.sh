#!/bin/bash
set -euo pipefail

# Ensure flathub remote exists
if ! flatpak remotes | grep -q flathub; then
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

# Install apps
flatpak install -y flathub com.github.iwalton3.jellyfin-media-player
flatpak install -y flathub com.github.tchx84.Flatseal
flatpak install -y flathub com.protonvpn.www
flatpak install -y flathub com.unicornsonlsd.finamp
flatpak install -y flathub io.missioncenter.MissionCenter
flatpak install -y flathub md.obsidian.Obsidian
flatpak install -y flathub org.localsend.localsend_app
flatpak install -y flathub org.onlyoffice.desktopeditors
flatpak install -y flathub org.qbittorrent.qBittorrent
flatpak install -y flathub org.strawberrymusicplayer.strawberry
flatpak install -y flathub org.videolan.VLC

# kraj