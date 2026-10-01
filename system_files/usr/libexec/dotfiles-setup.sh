#!/bin/bash

# First-login populator: copy /etc/skel into $HOME once (mirrors the official
# RakuOS niri mechanism). The rakuos-installer creates users WITHOUT a full
# skeleton, so without this, Hyprland's modular config (hyprland.lua ->
# require("config.*")) never lands in the home and Hyprland falls back to its
# auto-generated default config.

# Marker name matches the official RakuOS niri image (~/.local/share/config-setup)
# so both images behave identically for anyone moving between them.
FIRSTRUN="$HOME/.local/share/config-setup"
OLDRUN="$HOME/.local/share/dotfiles-setup"

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
        _wpimg=$(find "$wpdir" -path '*/contents/images/*.png' | head -n1)
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

# An older build used dotfiles-setup as the marker. Drop it and fall through to
# the skel copy so the appearance keys below get applied to those users too.
[ -f "$OLDRUN" ] && rm -f "$OLDRUN"

cp -r "/etc/skel/." "$HOME"

populate_wallpapers

## Apply the icon theme through GSettings, which is what actually decides icon
## lookup for GTK4 apps.
##
## This cannot be done from the skeleton. Verified on the skel itself: with
## gtk-icon-theme-name=Colloid-Dark in gtk-{3,4}.0/settings.ini,
## Gtk.Settings.get_default() reports gtk-theme-name=adw-gtk3-dark (so the file
## IS read) but still reports gtk-icon-theme-name=Adwaita, no matter what value
## is written -- including deliberately bogus ones. The key is not consulted for
## icon lookup on GTK4; org.gnome.desktop.interface.icon-theme is, and its
## compiled schema default is 'Adwaita'.
##
## The settings.ini keys are kept anyway: GTK3 apps and anything reading the
## file directly still honour them, so this is additive rather than a move.
##
## Noctalia's own GTK template (assets/templates/gtk/apply.sh) writes gtk-theme
## and color-scheme via gsettings but never icon-theme, so nothing else in the
## session sets this. Same approach as the official CachyOS skel and the RakuOS
## niri image.
##
## Needs a session bus; the unit is WantedBy=default.target so it starts with
## the graphical session. If gsettings is unavailable this is a no-op and the
## user can always set the icon theme from the Noctalia/gsettings UI.
if command -v gsettings > /dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface icon-theme "Colloid-Dark"
fi

# $HOME/.local/share is not part of the skeleton, and a user created by
# rakuos-installer may not have it yet. Without this the touch below fails
# silently and the whole first-run block re-runs on every login, re-copying
# /etc/skel over the user's home each time.
mkdir -p "$(dirname "$FIRSTRUN")"
touch "$FIRSTRUN"
