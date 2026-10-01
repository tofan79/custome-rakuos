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
  gnome-disk-utility \
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

## Drop gnome-keyring outright. Not merely unused: it is why every device logged
## a coredump. gnome-keyring 50.0 aborts during Secret Service session
## negotiation -- gkd_secret_service_get_pkcs11_session asserts on a NULL client in
## gkd-secret-session.c, then aes_negotiate dereferences a NULL GVariant and GLib
## traps. Any client that opens a session triggers it; Firefox was the first one
## here. Reported upstream as Ubuntu #2161749, end-4/dots-hyprland#2826 and
## openai/codex#34943, all on 50.0, with no Fedora fix shipped yet. Noctalia and
## Hyprland work without org.freedesktop.secrets, so nothing in this image loses a
## feature by dropping it.
##
## The base still ships both keyring packages even though they are no longer in the
## install list above, so the remove is required -- listing nothing is not enough.
##
## gnome-keyring-pam goes with it, and the base already wires that module into the
## greetd stack in two places, both uncommented. Dropping the package alone would
## leave greetd pointing at a .so that no longer exists, and gnome-keyring-pam
## ships no %postun to clean up after itself -- so the references go by hand. The
## pattern skips any line starting with '-', so an entry a future base comments out
## is left untouched.
rum remove -y gnome-keyring gnome-keyring-pam
sed -i -E '/^[[:space:]]*[^#-].*pam_gnome_keyring[.]so/d' /etc/pam.d/greetd /etc/pam.d/passwd
## Gate on ACTIVE references only, mirroring the sed's [^#-] above. A commented
## "#auth optional pam_gnome_keyring.so" loads nothing and must not fail the build:
## an older base shipped these entries commented and the previous revision of this
## script deliberately uncommented them, so a future base re-commenting them is a
## plausible, harmless change. Only a line that would actually be read as a stack
## entry is a real problem.
##
## grep piped into grep -v, then grep -q: checking both files in one pass is what
## catches a second reference, since grep -q alone exits 0 on the very first hit.
if grep -hvE '^[[:space:]]*#' /etc/pam.d/greetd /etc/pam.d/passwd \
        | grep -q pam_gnome_keyring; then
    echo "build.sh: active pam_gnome_keyring reference left after cleanup" >&2
    exit 1
fi

## rakuos-flatpak-watcher exits 1 on a fresh device with
##   Error: No such file or directory (os error 2)
## because nothing has ever created /var/lib/flatpak/exports/bin. Restart=always
## turns that into start-limit-hit, which leaves the whole system degraded on
## every boot. packages.list ships no flatpak and build.sh installs none, so there
## is never a directory for it to watch. Creating it up front is exactly what the
## first flatpak install would have done. ExecStartPre rather than RuntimeDirectory=
## because the watcher has to keep watching after it exits, and masking the unit
## instead would permanently break it for anyone who installs a flatpak later.
##
## Confirmed against the journal on the running machine: the unit reached restart
## counter 5 and then start-limit-hit, having logged "watching
## /var/lib/flatpak/exports/bin / Setting up watches. / Error: No such file or
## directory". The daemon is /usr/libexec/rakuos/flatpak-event-watcher, the unit
## has no Condition*, so this fires on every device that has the base installed.
mkdir -p /etc/systemd/system/rakuos-flatpak-watcher.service.d
cat > /etc/systemd/system/rakuos-flatpak-watcher.service.d/10-watchpath.conf << 'WATCHEOF'
[Service]
ExecStartPre=/usr/bin/mkdir -p /var/lib/flatpak/exports/bin
WATCHEOF
systemctl daemon-reload

## NTP so the clock stays synced across reboots. RTC is UTC on both sides already
## (Windows has RealTimeIsUniversal=1), so no timedatectl set-local-rtc needed.
rum install -y chrony
systemctl enable chronyd

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
