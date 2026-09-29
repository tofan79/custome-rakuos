#!/bin/bash

# First-login populator: copy /etc/skel into $HOME once (mirrors the official
# RakuOS niri mechanism). The rakuos-installer creates users WITHOUT a full
# skeleton, so without this, Hyprland's modular config (hyprland.lua ->
# require("config.*")) never lands in the home and Hyprland falls back to its
# auto-generated default config.

FIRSTRUN="$HOME/.local/share/dotfiles-setup"

# Official RakuOS wallpaper set, copied straight out of the read-only image
# rather than through /etc/skel. Populating the skeleton at build time would
# mean a rebuild every time the base image ships new wallpapers, and it would
# put several MB into every /etc/skel in the image. Reading them here also
# means a wallpaper added by a later base image update reaches existing users
# on their next login, with no image rebuild.
#
# Noctalia's wallpaper picker reads ~/Pictures/Wallpaper, so that is where they
# need to land. -n never overwrites a file the user already has.
populate_wallpapers() {
    mkdir -p "$HOME/Pictures/Wallpaper"
    for _wpdir in /usr/share/wallpapers/RakuOS-*/; do
        [ -d "$_wpdir" ] || continue
        _wpimg=$(find "$_wpdir" -path '*/contents/images/*.png' | head -n1)
        if [ -n "$_wpimg" ]; then
            cp -n "$_wpimg" "$HOME/Pictures/Wallpaper/$(basename "$_wpdir").png"
        fi
    done
    [ -f /usr/share/wallpapers/default.jpg ] && \
        cp -n /usr/share/wallpapers/default.jpg "$HOME/Pictures/Wallpaper/default.jpg"
    unset _wpdir _wpimg
}

if [ -f "$FIRSTRUN" ]; then
    # Keep graphics in sync on later logins: copy any wallpaper the user does
    # not have yet. Safe to run every time, cp -n is a no-op on existing files.
    populate_wallpapers
    exit 0
fi

cp -r "/etc/skel/." "$HOME"

populate_wallpapers

# $HOME/.local/share is not part of the skeleton, and a user created by
# rakuos-installer may not have it yet. Without this the touch below fails
# silently and the whole first-run block re-runs on every login, re-copying
# /etc/skel over the user's home each time.
mkdir -p "$(dirname "$FIRSTRUN")"
touch "$FIRSTRUN"
