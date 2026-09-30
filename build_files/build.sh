#!/bin/bash

set -ouex pipefail

# Enable COPR for Hyprland and Noctalia
dnf -y copr enable lionheartp/Hyprland
dnf -y copr enable mindset/Mindset-Apps

# Pin COPRs at priority=20: below RakuOS repos (v4=5, v3=10), above defaults.
# Matches RakuOS base's convention of editing repo files directly with sed.
# Remove any pre-existing priority line (e.g. baked in by copr enable) first.
for _copr_repo in "mindset:Mindset-Apps" "lionheartp:Hyprland"; do
    _copr_id="${_copr_repo%%:*}"            # mindset / lionheartp
    _copr_name="${_copr_repo#*:}"           # Mindset-Apps / Hyprland
    _copr_file="/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:${_copr_repo}.repo"
    sed -i '/^priority=/d' "$_copr_file"
    sed -i '/^\[copr:copr.fedorainfracloud.org:'"$_copr_id"':'"$_copr_name"'\]/a priority=20' "$_copr_file"
done

# NOTE: rakuos-release-hyprland package not available yet in repos
# When available, uncomment below:
# RAKUOS_RELEASE_PKG="rakuos-release-hyprland"
# if [ "${RAKUOS_STAGING:-0}" = "1" ]; then
#     RAKUOS_RELEASE_PKG="rakuos-release-hyprland-staging"
# fi

# Terra ships disabled by default (third-party repos are opt-in), so enable
# it here in case any packages below come from Terra. It stays enabled for the
# whole build stage — the overlay prebake in post-build-overlay.sh resolves
# packages.list too — and is disabled again at the end of that script.
rum config-manager --set-enabled terra

## Install packages
## nss-altfiles is NOT installed here on purpose. The base references the
## "altfiles" NSS service in /etc/nsswitch.conf and ships /usr/lib/group, but
## installing the module puts it in /usr, where initrd (before /usr is mounted)
## cannot see it, so the ~45 "Failed to resolve group" warnings per boot come
## back. post-build-overlay.sh instead bakes the groups straight into /etc/group
## and lists nss-altfiles in protected-packages.txt so the overlay never
## shadows it.
rum install -y --refresh \
  cpio \
  nss-altfiles \
  hyprland \
  hyprland-guiutils \
  gloview-git \
  noctalia-git \
  noctalia-greeter-git \
  ghostty \
  ghostty-nautilus \
  ghostty-kio \
  uwsm \
  pipewire \
  pipewire-alsa \
  pipewire-pulseaudio \
  wireplumber \
  xdg-desktop-portal \
  xdg-desktop-portal-hyprland \
  xdg-desktop-portal-gtk \
  xdg-user-dirs-gtk \
  xorg-x11-server-Xwayland \
  wl-clipboard \
  egl-wayland \
  grim \
  slurp \
  wtype \
  cava \
  tuned \
  tuned-ppd \
  fprintd-pam \
  adw-gtk3-theme \
  papirus-icon-theme \
  bibata-cursor-theme \
  jetbrainsmono-nerd-fonts \
  gvfs \
  gvfs-mtp \
  gvfs-nfs \
  gvfs-smb \
  pavucontrol \
  gnome-calculator \
  NetworkManager-adsl \
  NetworkManager-bluetooth \
  NetworkManager-ppp \
  NetworkManager-wwan \
  nm-connection-editor \
  libnotify \
  qt6-qtdeclarative \
  qt6-qt5compat \
  qt6-qtsvg \
  qt6ct \
  qt6-qtimageformats \
  systemd-oomd-defaults \
  swash \
  zsh-autosuggestions \
  zsh-syntax-highlighting \
  eza \
  fastfetch \
  starship \
  tesseract \
  tesseract-langpack-eng \
  tesseract-langpack-ind \
  zbar \
  hyprpicker \
  gnome-keyring \
  gnome-keyring-pam \
  cliphist \
  nautilus \
  cups-pk-helper \
  nomacs \
  bat \
  fzf \
  zoxide \
  rakuos-welcome-qt \
  rakuos-system-qt \
  rakuos-software-qt



## Remove superseded packages
rum remove -y wofi kitty kitty-kitten kitty-shell-integration kitty-terminfo 2>/dev/null || true


glib-compile-schemas /usr/share/glib-2.0/schemas || true
update-desktop-database -q >/dev/null 2>&1 || true
update-mime-database /usr/share/mime >/dev/null 2>&1 || true
for d in /usr/share/icons/*/; do [ -f "${d}index.theme" ] && gtk-update-icon-cache -q -f -t "${d%/}" || true; done
dconf update 2>/dev/null || true


## Enable NTP: chrony keeps clock synced across reboots.
## RTC is UTC (Windows already configured with RealTimeIsUniversal=1 in registry),
## so no need for timedatectl set-local-rtc — both OS agree on UTC.
rum install -y chrony
systemctl enable chronyd


## Unlock keyring on login
## Kept verbatim from rakuos-niri/build_files/build.sh. It is currently a no-op:
## the base no longer ships a commented-out pam_gnome_keyring line in
## /etc/pam.d/greetd (only pam_kwallet is commented there), so the pattern
## matches nothing. Kept anyway for parity with the official image and in case a
## future base re-comments it — sed exits 0 either way, so it cannot break the
## build.
sed -i -E 's/^-([a-z]+[[:space:]]+.*pam_gnome_keyring\.so)/\1/' /etc/pam.d/greetd

## Noctalia greeter (greetd)
## system_files/etc/greetd/config.toml holds the greetd config and is already in
## place: the Containerfile COPYs system_files before this script runs. What
## cannot be a file is done here by the setup script the package ships:
##   - inserts `session required pam_systemd.so` into /etc/pam.d/greetd, without
##     which logind never creates a session/seat for the greeter's nested wlroots
##     compositor and the login screen misbehaves;
##   - creates /var/lib/noctalia-greeter (0750, owned by greeter) for the
##     wallpaper/palette sync;
##   - installs greeter.toml plus the polkit action for the appearance tool.
## The package ships no tmpfiles.d drop-in, so the portable ensure_greeter_paths
## path inside the script is what actually creates the state dir.
/usr/share/noctalia-greeter/setup_greeter_system.sh

## The script keeps a timestamped copy of the PAM file. Drop it so the backup
## does not ship inside the image.
rm -f /etc/pam.d/greetd.bak.noctalia.*

## Enable Services
## tuned/tuned-ppd are not enabled explicitly: /usr/lib/systemd/system-preset/
## 90-default.preset enables both, same as on the niri image.
systemctl enable greetd
systemctl enable --global dotfiles-setup
