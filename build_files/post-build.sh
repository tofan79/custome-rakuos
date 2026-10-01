#!/bin/bash

set -ouex pipefail

# Terra stays enabled here on purpose: the overlay prebake in
# post-build-overlay.sh still resolves packages.list, which pulls browser
# packages from Terra. It is disabled again at the end of that script.

# Write the DE identifier so rakuos-overlay-mount can detect a DE change at
# boot and trigger a soft reset to rebuild the overlay from packages.list.
echo "hyprland" > /usr/share/rakuos/de-name

# Manual Hyprland identity for custom images.
# Always "Staging": the base image consumed by this build is the RakuOS
# staging tree (rakuos-base-*:staging), so the branding must match it —
# silently labelling the deploy as stable would be misleading. The default
# `staging` base tag is what the workflow ships by default. If a real stable
# base is ever used, flip these values to the stable variant.
mkdir -p /etc/os-release.d
cat > /etc/os-release.d/hyprland << 'EOF'
PRETTY_NAME="RakuOS Hyprland Staging"
NAME="RakuOS"
VERSION="44 (Staging)"
ID=rakuos
ID_LIKE="fedora"
VERSION_ID=44
ANSI_COLOR="0;38;2;120;40;160"
LOGO=rakuos-logo
CPE_NAME="cpe:/o:rakuos:rakuos-hyprland-staging:44"
HOME_URL="https://rakuos.org/"
DOCUMENTATION_URL="https://rakuos.org/docs"
SUPPORT_URL="https://rakuos.org/support"
BUG_REPORT_URL="https://rakuos.org/bugs"
PLATFORM_ID="platform:f44"
VARIANT="bootc"
VARIANT_ID=hyprland-staging
VARIANT_NAME="Hyprland Staging"
EOF

# Override the uwsm session entry AFTER rum install (the hyprland-uwsm RPM
# owns /usr/share/wayland-sessions/hyprland-uwsm.desktop and would clobber a
# plain COPY). /usr/local is a symlink to /var/usrlocal in the base image, so
# it cannot be used as a COPY destination either — rewriting here is the only
# reliable spot. UWSM_SILENT_START=2 stops uwsm start from printing its
# progress to stdout (the display manager forwards it to the VT, showing text
# between the greeter and Hyprland); real errors still surface via syslog/journal.
mkdir -p /usr/share/wayland-sessions
cat > /usr/share/wayland-sessions/hyprland-uwsm.desktop << 'EOF'
[Desktop Entry]
Name=Hyprland (uwsm-managed)
Comment=An intelligent dynamic tiling Wayland compositor
Exec=env UWSM_SILENT_START=2 uwsm start -e -D Hyprland hyprland.desktop
TryExec=uwsm
DesktopNames=Hyprland
Type=Application
EOF

## Harden the service defaults. Everything here is a per-device-neutral decision:
## none of it assumes a particular NIC, GPU model, or form factor, so the same
## image behaves identically on every machine it lands on.
##
## sshd is masked, not disabled. The base enables it and firewalld opens the ssh
## service, so a fresh device listens on port 22 before its first user login --
## a network-exposed daemon on a desktop image that has no use for one. Masking
## (a symlink to /dev/null in /etc/systemd/system) is stronger than disable:
## it also blocks a stray `systemctl start sshd` or a package pulling it back
## in, and it survives `systemctl set-default`/preset runs that would happily
## re-create the enable symlink.
## To turn it on when you actually want SSH on a specific machine:
##     sudo systemctl unmask sshd && sudo systemctl enable --now sshd
##     sudo firewall-cmd --permanent --add-service=ssh && sudo firewall-cmd --reload
systemctl mask sshd

## nvidia-persistenced pins the dGPU awake. Measured on the machine this was
## written on: the RTX 3050 sat at P0 / D0, ~1500 MHz, 0% utilisation, drawing
## 17-18 W continuously -- while the desktop was actually rendering on the AMD
## iGPU through PRIME. That is the entire cost and none of the benefit on a
## hybrid laptop. PRIME render-offload (/usr/bin/nvidiarun) loads the driver on
## demand per process, so games and CUDA do not need the daemon.
##
## This is disabled rather than masked, and the tradeoff is real, so read this
## before changing it:
##
##   Hybrid laptop (iGPU drives the session) -- this is the case above. Disabling
##   is clearly right and costs nothing.
##
##   NVIDIA-only desktop, or NVIDIA set as the primary display -- disabling is
##   NOT clearly right. Nothing breaks: the driver still initialises when the
##   compositor starts, and rendering is unaffected. What is lost is the warm
##   state, so the first app or the first resume after suspend has to reload the
##   driver, which on some laptops means a visible delay and, on a few setups, a
##   black screen that needs a hard reboot. Persistence mode itself is NOT off --
## the driver has defaulted it on for all GeForce parts since 555, and this image
## ships 615.71.09; only the daemon that proactively holds the GPU is gone.
##
##   No NVIDIA GPU at all -- this is where the base is actually broken. The unit
##   carries no ConditionPathExists, so it is enabled unconditionally and tries
##   to open /dev/nvidiactl on every machine regardless of what is in the PCI
##   slots. The guard below is what fixes that.
##
## So: disabled by default because hybrids are the common case and the saving is
## measured, plus the guard below so nobody gets a failed unit on a non-NVIDIA
## box. An NVIDIA-only user re-enables it with one command:
##     sudo systemctl enable --now nvidia-persistenced
## Make it the default for your own NVIDIA-only machine by running that once; it
## is per-machine state in /etc, not baked into the image.
##
## The guard is ConditionPathExists on /dev/nvidiactl, not on the nvidia module:
## /dev/nvidiactl is what the daemon actually opens, so it is the precise
## condition. Without it, enabling this on a machine with no NVIDIA GPU produces
## a failed unit in every boot log. This also means the enable above is safe to
## hand out as advice on any machine.
##
## NOTE: the README table claims this drop-in already exists as
## system_files/usr/lib/systemd/system/nvidia-persistenced.service.d/override.conf
## with a wait-for-node bootstrap. It does not exist -- neither in the repo nor in
## the base's /usr/lib. The README is stale on this row; this block is the real
## state.
mkdir -p /etc/systemd/system/nvidia-persistenced.service.d
cat > /etc/systemd/system/nvidia-persistenced.service.d/10-hardware-guard.conf << 'NVEOF'
[Unit]
ConditionPathExists=/dev/nvidiactl
NVEOF
systemctl daemon-reload
systemctl disable nvidia-persistenced

## updates-archive is a Fedora mirror holding *superseded* builds. Nothing here
## should ever resolve from it: a package that only exists in the archive is a
## package that has been withdrawn, and letting dnf pick it means metadata for
## every release accumulates (hundreds of MB of _metadata) and `dnf upgrade`
## re-reads it on every run. Disabling is safe because every package this image
## actually installs resolves from updates/testing/terra.
rum config-manager --set-disabled updates-archive

## Drop the nvidia-settings X11 autostart.
# /etc/xdg/autostart/nvidia-settings-load.desktop ships with the
# nvidia-settings RPM and runs:
#   sh -c "[ -e /dev/nvidia0 ] && exec /usr/bin/nvidia-settings --load-config-only"
# It has no OnlyShowIn/NotShowIn guard, so it fires on every login. Its only
# purpose is preloading ~/.nvidia-settings-rc for an X11 session, and this image
# has no X11 session (/usr/share/xsessions is empty — SDDM was replaced by
# greetd). On a hybrid laptop /dev/nvidia0 still exists, so the guard passes and
# nvidia-settings — an X11/GTK tool — then exits 1 under Wayland, leaving
# app-nvidia\x2dsettings\x2dload@autostart.service failed in `systemctl --user`
# on every single login. Pure noise with nothing reading its output.
# Reappears if the nvidia-settings RPM is upgraded or reinstalled.
rm -f /etc/xdg/autostart/nvidia-settings-load.desktop
