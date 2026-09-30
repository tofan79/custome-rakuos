#!/bin/bash

# First-login populator: copy /etc/skel into $HOME once (mirrors the official
# RakuOS niri mechanism). The rakuos-installer creates users WITHOUT a full
# skeleton, so without this, Hyprland's modular config (hyprland.lua ->
# require("config.*")) never lands in the home and Hyprland falls back to its
# auto-generated default config.

FIRSTRUN="$HOME/.local/share/dotfiles-setup"

if [ -f "$FIRSTRUN" ]; then
    # Keep graphics in sync with /etc/skel on later image upgrades:
    # stock wallpapers ship in the base image, but the first-run copy above
    # (or the rakuos-installer) only populated $HOME once. Copy any wallpaper
    # the user doesn't have yet — never overwrite their own files.
    if [ -d /etc/skel/Pictures/Wallpaper ]; then
        mkdir -p "$HOME/Pictures/Wallpaper"
        cp -rn /etc/skel/Pictures/Wallpaper/. "$HOME/Pictures/Wallpaper/"
    fi
    exit 0
fi

cp -r "/etc/skel/." "$HOME"

touch "$FIRSTRUN"