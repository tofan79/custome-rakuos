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
## nss-altfiles IS installed here. The base references the "altfiles" NSS service
## in /etc/nsswitch.conf and ships /usr/lib/group, but the base image has no
## libnss_altfiles.so to back that source, so the reference is dead until this
## module is present. With it, /usr/lib/group is merged into group lookups and
## the groups that live only there resolve.
##
## The module lives in /usr, which is not mounted yet during initrd, so it cannot
## help the early boot phase. post-build-overlay.sh covers that separately by
## baking the same groups into BOTH /etc/group and /usr/lib/group, and it lists
## nss-altfiles in protected-packages.txt so the overlay never shadows it.
rum install -y --refresh \
  cpio \
  nss-altfiles \
  hyprland \
  hyprland-guiutils \
  uwsm \
  xorg-x11-server-Xwayland \
  egl-wayland \
  hyprpicker \
  grim \
  slurp \
  wtype \
  wl-clipboard \
  noctalia-git \
  noctalia-greeter-git \
  xdg-desktop-portal \
  xdg-desktop-portal-hyprland \
  xdg-desktop-portal-gtk \
  xdg-user-dirs-gtk \
  ghostty \
  ghostty-nautilus \
  ghostty-kio \
  jetbrainsmono-nerd-fonts \
  zsh-autosuggestions \
  zsh-syntax-highlighting \
  eza \
  bat \
  fzf \
  zoxide \
  fastfetch \
  starship \
  swash \
  cliphist \
  cava \
  pavucontrol \
  pipewire \
  pipewire-alsa \
  pipewire-pulseaudio \
  wireplumber \
  NetworkManager-adsl \
  NetworkManager-bluetooth \
  NetworkManager-ppp \
  NetworkManager-wwan \
  nm-connection-editor \
  tuned \
  tuned-ppd \
  gnome-keyring \
  gnome-keyring-pam \
  fprintd-pam \
  adw-gtk3-theme \
  bibata-cursor-theme \
  gvfs \
  gvfs-mtp \
  gvfs-nfs \
  gvfs-smb \
  qt6-qtdeclarative \
  qt6-qt5compat \
  qt6-qtsvg \
  qt6ct \
  qt6-qtimageformats \
  libnotify \
  systemd-oomd-defaults \
  gnome-calculator \
  nautilus \
  nomacs \
  cups-pk-helper \
  tesseract \
  tesseract-langpack-eng \
  tesseract-langpack-ind \
  zbar \
  rakuos-welcome-qt \
  rakuos-system-qt \
  rakuos-software-qt



## Kitty is replaced by ghostty, and wofi is used by neither Noctalia nor the
## Noctalia Greeter. kitty-terminfo goes with it: skel exports TERM=xterm-ghostty,
## so leaving it behind only ships a terminal type nothing references.
rum remove -y wofi kitty kitty-kitten kitty-shell-integration kitty-terminfo 2>/dev/null || true


## Rebuild derived caches. /usr/lib/rpm/file-triggers is absent in this image, so
## no trigger ever fires and nothing else builds these. Without gschemas.compiled
## Nautilus aborts at startup (commit 98be7cb); || true throughout so a cache miss
## degrades the image but never fails the build.
glib-compile-schemas /usr/share/glib-2.0/schemas || true
update-desktop-database -q >/dev/null 2>&1 || true
update-mime-database /usr/share/mime >/dev/null 2>&1 || true
for d in /usr/share/icons/*/; do [ -f "${d}index.theme" ] && gtk-update-icon-cache -q -f -t "${d%/}" || true; done
dconf update 2>/dev/null || true


## NTP so the clock stays synced across reboots. RTC is UTC on both sides already
## (Windows has RealTimeIsUniversal=1), so no timedatectl set-local-rtc needed.
rum install -y chrony
systemctl enable chronyd


## Uncomment pam_gnome_keyring in greetd's PAM stack. Currently a no-op: the base only
## ships pam_kwallet commented there, so the pattern matches nothing and sed exits 0.
## Kept for parity with the official image in case a future base re-comments it.
sed -i -E 's/^-([a-z]+[[:space:]]+.*pam_gnome_keyring\.so)/\1/' /etc/pam.d/greetd

## Noctalia Greeter setup. The greeter account must exist first or
## noctalia-greeter-apply-appearance --setup-system aborts the whole RUN step.
## uid/gid are left to useradd so they cannot collide with the base's range, and
## -m is omitted because setup_greeter_system.sh creates and owns /var/lib/greeter.
if ! getent passwd greeter >/dev/null; then
    useradd \
        --system \
        --home-dir /var/lib/greeter \
        --shell /bin/bash \
        --comment "System Greeter" \
        greeter
fi
## system_files/etc/greetd/config.toml is already in place (Containerfile COPYs
## system_files first). What the shipped script adds: pam_systemd.so in
## /etc/pam.d/greetd, else logind never makes a session/seat for the greeter's
## nested wlroots compositor; /var/lib/noctalia-greeter (0750, greeter:greeter);
/usr/share/noctalia-greeter/setup_greeter_system.sh

## The script keeps a timestamped copy of the PAM file. Drop it so the backup
## does not ship inside the image.
rm -f /etc/pam.d/greetd.bak.noctalia.*

## tuned/tuned-ppd need no explicit enable: 90-default.preset already enables both,
## same as on the niri image.
systemctl enable greetd
systemctl enable --global dotfiles-setup
