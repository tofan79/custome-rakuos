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

## Ensure rpm scriptlets can find a /bin/sh interpreter in this baseless OCI image
# Some pulled packages (e.g. tk, kf6-kdoctools) run %prein/%post scriptlets via the
# absolute path /bin/sh; a merged-usr base without /bin fails with
# "failed to exec scriptlet interpreter /bin/sh: No such file or directory".
mkdir -p /bin
ln -sfn /usr/bin/sh /bin/sh
ln -sfn /usr/bin/bash /usr/bin/sh 2>/dev/null || true

## Install packages
## nss-altfiles: base already references the "altfiles" NSS service in
## /etc/nsswitch.conf (passwd/group) and ships /usr/lib/group + /usr/lib/passwd,
## but the module library is absent from the minimal image. Without it, initrd
## tmpfiles/udev cannot resolve system groups (audio, video, disk, tty, utmp,
## ...) and log ~45 "Failed to resolve group" warnings every boot. Installing
## the module completes the chain defined in nsswitch.conf and removes the noise.
rum install -y --refresh \
  cpio \
  nss-altfiles \
  hyprland \
  hyprland-guiutils \
  gloview-git \
  noctalia-git \
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
  NetworkManager-adsl \
  NetworkManager-bluetooth \
  NetworkManager-ppp \
  NetworkManager-wwan \
  nm-connection-editor \
  power-profiles-daemon \
  libnotify \
  sddm \
  sddm-x11 \
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
  tesseract-langpack-jpn \
  tesseract-langpack-jpn_vert \
  tesseract-langpack-kor \
  tesseract-langpack-kor_vert \
  tesseract-langpack-chi_sim \
  tesseract-langpack-chi_sim_vert \
  tesseract-langpack-chi_tra \
  tesseract-langpack-chi_tra_vert \
  zbar \
  hyprpicker \
  cliphist \
  brightnessctl \
  playerctl \
  nautilus \
  nautilus-open-any-terminal-git \
  nomacs \
  unzip \
  zip \
  7zip \
  unar \
  bat \
  fzf \
  zoxide \
  rakuos-welcome-qt \
  rakuos-system-qt \
  rakuos-software-qt

## NVIDIA X.Org driver for the SDDM X11 greeter
## RPM Fusion 615 ships the X.Org driver only in a package variant whose files
## collide with the full nvidia-driver stack already baked into the base image
## (firmware blobs, /usr/lib/nvidia/alternate-install-present, the nvidia-powerd
## unit and the wine nvngx libs). Its "xorg-libs" subpackage hard-Requires that
## conflicting parent, so no installable package set can provide nvidia_drv.so
## next to the full stack. The X11 greeter only needs the two Xorg module files,
## so extract them from the RPM that owns them and leave the full stack alone.
## These files end up unowned by rpm, which is fine: dnf never touches unowned
## files, and they live in the immutable /usr of the image, not the live overlay.
nvidia_xorg_files=(
  /usr/lib64/xorg/modules/drivers/nvidia_drv.so
  /usr/lib64/xorg/modules/extensions/libglxserver_nvidia.so
)
# Pin to the same version as the pre-baked nvidia-driver stack, otherwise the
# X.Org module and the userspace libraries disagree and the greeter goes black.
nvidia_version=$(rpm -q --qf '%{VERSION}' nvidia-driver-libs)
nvidia_xorg_pkg="xorg-x11-drv-nvidia-xorg-libs"
nvidia_xorg_rpm=$(rum repoquery --location "$nvidia_xorg_pkg" -q 2>/dev/null | grep -m1 -- "-${nvidia_version}-")
if [ -z "$nvidia_xorg_rpm" ]; then
  nvidia_xorg_rpm=$(dnf repoquery --location "$nvidia_xorg_pkg" -q 2>/dev/null | grep -m1 -- "-${nvidia_version}-")
fi
if [ -z "$nvidia_xorg_rpm" ]; then
  echo "ERROR: no ${nvidia_version} download URL found for ${nvidia_xorg_pkg}" >&2
  exit 1
fi
echo "Extracting the X.Org NVIDIA driver from ${nvidia_xorg_rpm}"
curl -fsSL --retry 3 -o /tmp/nvidia-xorg.rpm "$nvidia_xorg_rpm"
nvidia_xorg_relpaths=()
for nvidia_xorg_file in "${nvidia_xorg_files[@]}"; do
  nvidia_xorg_relpaths+=(".${nvidia_xorg_file}")
done
(cd / && rpm2cpio /tmp/nvidia-xorg.rpm | cpio -idm --quiet "${nvidia_xorg_relpaths[@]}")
rm -f /tmp/nvidia-xorg.rpm
for nvidia_xorg_file in "${nvidia_xorg_files[@]}"; do
  if [ ! -f "$nvidia_xorg_file" ]; then
    echo "ERROR: ${nvidia_xorg_file} missing after extracting ${nvidia_xorg_pkg}" >&2
    exit 1
  fi
  echo "  ok ${nvidia_xorg_file}"
done

## Mask nvidia-powerd and nvidia-persistenced: the pre-baked driver stack ships
## these units, but without a loaded NVIDIA driver they time out and stall boot.
systemctl mask nvidia-powerd.service 2>/dev/null || true
systemctl mask nvidia-persistenced.service 2>/dev/null || true

## Remove superseded packages
rum remove -y wofi 2>/dev/null || true

## Rebuild desktop caches.
##
## This image ships no RPM file triggers: /usr/lib/rpm/file-triggers/ does
## not exist, so package %post/%posttrans never run and these caches are
## never refreshed after install.
##
## Observed, not theoretical. The base image's gschemas.compiled is older
## than nautilus-50.3, so nautilus aborts on startup with:
##   GLib-GIO-ERROR: Settings schema 'org.gnome.nautilus.preferences' is
##   not installed
##
## Built once here, after all packages are in. Icon caches are per-theme, so
## every installed theme needs its own.
glib-compile-schemas /usr/share/glib-2.0/schemas || true
update-desktop-database -q >/dev/null 2>&1 || true
update-mime-database /usr/share/mime >/dev/null 2>&1 || true
for _theme in /usr/share/icons/hicolor /usr/share/icons/Adwaita; do
    [ -f "$_theme/index.theme" ] && gtk-update-icon-cache -q -f -t "$_theme" >/dev/null 2>&1 || true
done
for _theme_dir in /usr/share/icons/*/; do
    [ -f "${_theme_dir}index.theme" ] || continue
    case "$_theme_dir" in */hicolor/*|*/Adwaita/*) continue ;; esac
    gtk-update-icon-cache -q -f -t "${_theme_dir%/}" >/dev/null 2>&1 || true
done
unset _theme _theme_dir

## Point nautilus-open-any-terminal at the terminal we actually ship.
##
## The extension hardcodes terminal = "gnome-terminal" (nautilus_open_any_
## terminal.py:153) and never probes whether that binary exists, so its
## "Open in Terminal" entry dies with
##   FileNotFoundError: [Errno 2] No such file or directory: 'gnome-terminal'
## on any image without GNOME Terminal. This image ships kitty instead.
##
## Set in the dconf system database rather than /etc/skel: GLib's default
## settings backend is dconf, which does not read a keyfile at
## .config/glib-2.0/settings. A system default also covers existing users,
## while a skeleton file would only reach accounts created afterwards.
## Placed after glib-compile-schemas above, since the value is only readable
## once the extension's schema is compiled.
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/00-nautilus-open-any-terminal << 'EOF'
[com/github/stunkymonkey/nautilus-open-any-terminal]
terminal='kitty'
EOF
dconf update 2>/dev/null || true

## Enable NTP: chrony keeps clock synced across reboots.
## RTC is UTC (Windows already configured with RealTimeIsUniversal=1 in registry),
## so no need for timedatectl set-local-rtc — both OS agree on UTC.
rum install -y chrony
systemctl enable chronyd

## Enable Services
systemctl enable sddm
systemctl enable --global dotfiles-setup

## [NVIDIA dGPU pre-baked image] Mask dkms:
## nvidia modules are pre-baked into the image for its exact kernel, so the
## boot-time autoinstall always fails ("already installed, need --force").
## Kernel updates come bundled with freshly compiled modules from the image CI,
## so runtime dkms is never needed.
## ► Devices without an NVIDIA dGPU may skip this block (safe to ignore).
systemctl mask dkms.service 2>/dev/null || true

## Disable grub-boot-success: it also ships a user-scope unit that fires 2min
## after login and fails (grub2-set-bootflag needs root), spamming a failed
## service notification every session. Mask system AND user scope.
systemctl mask grub-boot-success.service grub-boot-success.timer 2>/dev/null || true
mkdir -p /etc/systemd/user
ln -sfn /dev/null /etc/systemd/user/grub-boot-success.service
ln -sfn /dev/null /etc/systemd/user/grub-boot-success.timer

## [This device — AMD+NVIDIA hybrid ASUS laptop] Disable fwupd:
## the daemon hangs in D-state on this hardware, stalling boot ~3min and
## ending in a failed unit. Firmware updates stay manual (menu/EFI).
## ► Other devices: do NOT disable — fwupd works normally on other hardware.
ln -sfn /dev/null /etc/systemd/system/fwupd.service
ln -sfn /dev/null /etc/systemd/system/fwupd-refresh.service
ln -sfn /dev/null /etc/systemd/system/fwupd-refresh.timer

## Mask mcelog: mcelog userspace daemon does not support AMD (Zen) CPUs and
## aborts at every boot ("mcelog: ERROR: AMD Processor family 23: mcelog does
## not support this processor"), leaving a spurious failed unit. AMD MCE
## decoding is handled in-kernel (edac_mce_amd) already, so this is cosmetic.
## Relevant here: AMD Ryzen 7 4800H (Zen 2, ACPI family 17h reported as 23).
## ► AMD-only device; Intel machines should keep mcelog enabled.
systemctl mask mcelog.service 2>/dev/null || true

## Power management: tuned (a plain tuner from the base image) is left in
## place, but tuned-ppd — the layer that claimed the Power Profiles API — is
## replaced by power-profiles-daemon above. Mask the base's tuned.service +
## tuned-ppd.service so only one power manager owns CPU tuning and the PPD
## D-Bus interface. Without the mask, tuned's default "balanced" profile
## (governor + energy_performance_preference + platform_profile) would fight
## power-profiles-daemon over the same sysfs knobs. tuned.service itself is
## auto-enabled by the tuned package preset at install time, so it must be
## masked here explicitly.
systemctl mask tuned.service tuned-ppd.service 2>/dev/null || true

## Quiet cosmetic systemd-tmpfiles noise on immutable systems:
## - home.conf: /home and /srv are symlinks into /var here, so the Q/q rules
##   log "/home already exists and is not a directory" every boot.
## - root.conf: its `z / 555` rule tries to chmod /, which is a read-only
##   composefs mount -> "fchmod() of / failed: Read-only file system".
## - provision.conf: instead of masking it entirely, ship a trimmed copy that
##   keeps the (credential-based) provisioning behavior but drops the `d- /root`
##   line, which hits the /root -> /var/roothome symlink and logs "/root already
##   exists and is not a directory" every boot.
mkdir -p /etc/tmpfiles.d
ln -sfn /dev/null /etc/tmpfiles.d/home.conf
ln -sfn /dev/null /etc/tmpfiles.d/root.conf
cat > /etc/tmpfiles.d/provision.conf << 'EOF'
# Trimmed copy of /usr/lib/tmpfiles.d/provision.conf:
# the `d- /root` line is dropped because /root is a symlink to /var/roothome
# on this immutable system (would log "already exists and is not a directory").

# Provision additional login messages from credentials, if they are set. Note
# that these lines are NOPs if the credentials are not set or if the files
# already exist.
f^ /etc/motd.d/50-provision.conf - - - - login.motd
f^ /etc/issue.d/50-provision.conf - - - - login.issue

# Provision a /etc/hosts file from credentials.
f^ /etc/hosts - - - - network.hosts

# Provision SSH key for root
d- /root/.ssh :0700 root :root -
f^ /root/.ssh/authorized_keys :0600 root :root - ssh.authorized_keys.root
EOF

## [NVIDIA dGPU] Remove autostart entries that are noisy/failing at login:
## - nvidia-settings-load: --load-config-only (X11-only) intermittently
## ► AMD-only devices: this file does not exist, rm -f is a no-op (safe).
rm -f /etc/xdg/autostart/nvidia-settings-load.desktop 2>/dev/null || true

## Create flatpak exports dir (fix rakuos-flatpak-watcher)
mkdir -p /var/lib/flatpak/exports/bin
