#!/usr/bin/env bash
# post-build-overlay.sh
# Runs inside the container build (Containerfile RUN step / GitHub Actions).
#
# Does NOT install packages — that's impossible inside a container build
# because overlayfs on /usr requires CAP_SYS_ADMIN and a real kernel mount.
#
# Instead, this script seeds /usr/share/factory/var/lib/rakuos/ so the first
# deployed system gets a populated /var/lib/rakuos/ state:
#   - packages.list populated from /usr/share/rakuos/packages.list
#   - overlay upper/work dirs created and empty
#   - overlay.state intentionally absent
#
# On first boot, rakuos-overlay-sync.service sees the missing state file,
# treats it as a fresh/reset system, and performs a full install into the
# overlay automatically — no user interaction needed.
#
# Usage (from your Containerfile):
#   RUN /usr/libexec/rakuos/build/post-build-overlay.sh

set -euo pipefail

DEFAULT_PACKAGES_LIST="/usr/share/rakuos/packages.list"
FACTORY_VAR_ROOT="/usr/share/factory/var"
PACKAGES_LIST="$FACTORY_VAR_ROOT/lib/rakuos/packages.list"
UPPER_DIR="$FACTORY_VAR_ROOT/lib/rakuos/overlay/upper"
WORK_DIR="$FACTORY_VAR_ROOT/lib/rakuos/overlay/work"
STATE_FILE="$FACTORY_VAR_ROOT/lib/rakuos/overlay.state"
DIRTY_FILE="$FACTORY_VAR_ROOT/lib/rakuos/overlay.dirty"
FACTORY_RUM_RPMDB="$FACTORY_VAR_ROOT/lib/rakuos/rum-rpmdb"

echo "[rakuos] Seeding overlay state for first-boot install..."

prebake_overlay_from_installroot() {
    local installroot
    local -a prebake_packages=()

    mapfile -t prebake_packages < <(
        grep -v '^\s*#' "$PACKAGES_LIST" \
        | grep -v '^\s*$' \
        | sed 's/\s*#.*//' \
        | tr -s ' \t' '\n' \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
        | grep -v '^$'
    )

    if [[ ${#prebake_packages[@]} -eq 0 ]]; then
        echo "[rakuos] No overlay packages listed; skipping prebake."
        return 0
    fi

    installroot="$(mktemp -d /var/tmp/rakuos-overlay-installroot.XXXXXX)"
    trap 'rm -rf "$installroot"' RETURN

    echo "[rakuos] Prebaking overlay packages into installroot via rum..."
    # No base rpmdb snapshot exists yet inside a build container, so rum's
    # OverlayPaths::detect() picks Standalone and resolves "already
    # installed" against the build container's own default rpmdb — exactly
    # the base image content this layer is being built on top of. --installroot
    # still redirects package files under $installroot/usr and creates a
    # fresh, disposable overlay rpmdb at $installroot/var/lib/rakuos/rum-rpmdb,
    # applying --nodeps/tsflags=noscripts automatically.
    ## rum defaults to --best=false, so with no arch pinning it happily resolves
    ## packages.list to a source RPM (e.g. zen-browser-1.22.2b.src.rpm) when that
    ## ties on version with the binary build. A source RPM has no /usr payload,
    ## which then breaks the copy below. Pin both: newest version, host arch.
    rum install --installroot "$installroot" -y --refresh \
        --best --forcearch="$(rpm -E '%{_arch}')" "${prebake_packages[@]}"

    rm -f "$installroot/usr/share/icons/default/index.theme"

    ## Rebuild caches inside the installroot, before /usr is copied to the
    ## overlay. Must be explicit: prebake runs with --nodeps/tsflags=noscripts,
    ## so package scriptlets never run here at all.
    glib-compile-schemas "$installroot/usr/share/glib-2.0/schemas" 2>/dev/null || true
    update-desktop-database -q "$installroot/usr/share/applications" >/dev/null 2>&1 || true
    for _theme in "$installroot"/usr/share/icons/*/; do
        [ -f "${_theme}index.theme" ] || continue
        gtk-update-icon-cache -q -f -t "${_theme%/}" >/dev/null 2>&1 || true
    done
    unset _theme

    echo "[rakuos] Copying prebaked /usr payload into overlay upper..."
    if [[ ! -d "$installroot/usr" ]]; then
        echo "[rakuos] ERROR: prebake produced no /usr payload in $installroot" >&2
        find "$installroot" -maxdepth 2 -mindepth 1 >&2 || true
        exit 1
    fi
    rm -rf "$UPPER_DIR" "$WORK_DIR"
    mkdir -p "$UPPER_DIR" "$WORK_DIR"
    cp -a "$installroot/usr/." "$UPPER_DIR/"

    echo "[rakuos] Copying prebaked rum overlay rpmdb into factory seed..."
    rm -rf "$FACTORY_RUM_RPMDB"
    mkdir -p "$(dirname "$FACTORY_RUM_RPMDB")"
    cp -a "$installroot/var/lib/rakuos/rum-rpmdb" "$FACTORY_RUM_RPMDB"

    if [[ -d "$installroot/etc" ]] && [[ -n "$(ls -A "$installroot/etc" 2>/dev/null)" ]]; then
        echo "[rakuos] Copying prebaked /etc payload into image..."
        cp -a "$installroot/etc/." /etc/
    fi

    echo "prebaked-installroot" > "$STATE_FILE"
    rm -f "$DIRTY_FILE"

    echo "[rakuos] Overlay prebake complete."
}

# ── Create runtime dirs ───────────────────────────────────────────────────────
mkdir -p "$FACTORY_VAR_ROOT/lib/rakuos"
mkdir -p "$UPPER_DIR"
mkdir -p "$WORK_DIR"

# ── Seed packages.list ────────────────────────────────────────────────────────

if [[ -f "$DEFAULT_PACKAGES_LIST" ]]; then
    cp "$DEFAULT_PACKAGES_LIST" "$PACKAGES_LIST"
    mapfile -t _seeded < <(grep -v '^\s*#' "$PACKAGES_LIST" | grep -v '^\s*$')
PKG_COUNT="${#_seeded[@]}"
    echo "[rakuos] packages.list seeded with $PKG_COUNT packages."
else
    touch "$PACKAGES_LIST"
    echo "[rakuos] WARNING: No default packages.list - creating empty list."
fi

# ── Bake system groups into /etc/group ────────────────────────────────────────
# These groups live only in /usr/lib/group (the altfiles NSS database) on Fedora,
# which /etc/nsswitch.conf reads via the `altfiles` source:
#   group: files [SUCCESS=merge] altfiles [SUCCESS=merge] systemd
# That works once /usr is mounted, but during initrd it is not, so udev rules and
# systemd-tmpfiles cannot resolve them and the boot log fills with
#   "Failed to resolve group 'audio': Unknown group"
# The official rakuos-niri image still logs ~112 of these. Writing the same
# groups straight into /etc/group (canonical Fedora GIDs, all 12 verified against
# /usr/lib/group) makes them resolvable from the first boot phase, where /etc
# always is.
#
# This is a top-level step, not part of prebake_overlay_from_installroot, on
# purpose: prebake returns early when packages.list is empty, which would
# silently skip the group baking and bring all 112 warnings back.
#
# Ordering matters — this must run AFTER the prebake's "cp -a $installroot/etc/.
# /etc/" step, otherwise that copy overwrites whatever we appended. Calling it
# from the bottom of this script satisfies that.
bake_system_groups() {
    local group gid
    for group in audio video input disk tty kvm render lp clock kmem sgx utmp plugdev; do
        grep -q "^${group}:" /etc/group && continue
        case "$group" in
            audio) gid=63 ;;
            video) gid=39 ;;
            input) gid=104 ;;
            disk) gid=6 ;;
            tty) gid=5 ;;
            kvm) gid=36 ;;
            render) gid=105 ;;
            lp) gid=7 ;;
            clock) gid=103 ;;
            kmem) gid=9 ;;
            sgx) gid=106 ;;
            utmp) gid=22 ;;
            # plugdev is not shipped by Fedora at all, so there is no canonical
            # entry in /usr/lib/group to copy. 55 is free in this image and is
            # the long-standing plugdev GID; left to the fallback below it would
            # get an arbitrary system GID, which still works but makes udev
            # permission rules that reference plugdev (10-switch.rules,
            # 70-u2f.rules) unpredictable across rebuilds.
            plugdev) gid=55 ;;
            *) gid=$(getent group "$group" 2>/dev/null | awk -F: '{print $3}' || true) ;;
        esac
        if [ -n "$gid" ]; then
            echo "${group}:x:${gid}:" >> /etc/group
            echo "[rakuos] Baked group ${group} (gid ${gid}) into /etc/group."
        else
            groupadd -r "$group" 2>/dev/null || true
            echo "[rakuos] WARNING: no gid for ${group}; fell back to groupadd." >&2
        fi
    done
}

# ── Ensure stale state is cleared before prebake writes fresh state ───────────
rm -f "$STATE_FILE" "$DIRTY_FILE"
# Ensure packages.list ends with newline
sed -i -e '$a\' "$PACKAGES_LIST" 2>/dev/null || true

# Appending hyprland protected packages to protected-packages.txt...
# Every entry here must be a package that build.sh actually installs, plus the
# two base packages the overlay must never shadow (cpio, nss-altfiles — see the
# /etc/group baking above). Keeping this in sync with build.sh is what stops the
# first-boot overlay sync from treating an installed package as removable.
# Removed along with their build.sh entries: sddm, sddm-x11,
# power-profiles-daemon, brightnessctl, playerctl, unzip, zip, 7zip, unar,
# nautilus-open-any-terminal-git, and the tesseract CJK/Korean/Japanese
# langpacks.
cat >> /usr/share/rakuos/protected-packages.txt << 'PKGLIST'
hyprland
hyprland-guiutils
uwsm
noctalia-git
noctalia-greeter-git
gloview-git
rakuos-welcome-qt
rakuos-system-qt
rakuos-software-qt
ghostty
ghostty-nautilus
ghostty-kio
pipewire
pipewire-alsa
pipewire-pulseaudio
wireplumber
cava
xdg-desktop-portal
xdg-desktop-portal-hyprland
xdg-desktop-portal-gtk
xdg-user-dirs-gtk
xorg-x11-server-Xwayland
egl-wayland
wl-clipboard
grim
slurp
wtype
tuned
tuned-ppd
fprintd-pam
gnome-keyring
gnome-keyring-pam
adw-gtk3-theme
papirus-icon-theme
bibata-cursor-theme
jetbrainsmono-nerd-fonts
cpio
nss-altfiles
gvfs
gvfs-mtp
gvfs-nfs
gvfs-smb
nautilus
nomacs
cups-pk-helper
NetworkManager-adsl
NetworkManager-bluetooth
NetworkManager-ppp
NetworkManager-wwan
nm-connection-editor
libnotify
qt6-qtdeclarative
qt6-qt5compat
qt6-qtsvg
qt6-qtimageformats
qt6ct
systemd-oomd-defaults
chrony
swash
zsh-autosuggestions
zsh-syntax-highlighting
eza
bat
fzf
zoxide
fastfetch
starship
hyprpicker
cliphist
pavucontrol
gnome-calculator
tesseract
tesseract-langpack-eng
tesseract-langpack-ind
zbar
PKGLIST

rum remove -y 'selinux-policy*' 'policycoreutils-gui'
rum install -y libselinux

# selinux-policy is fully removed on RakuOS (MAC is handled by the base
# kernel); the
# baked-in rpm-ostree treefile still defaults "selinux": true. rpm-ostree reads
# that flag on every deploy-time layering operation and tries to load a policy
# from / that no longer exists, causing spurious sepolicy-mismatch failures.
if [ -f /usr/share/rpm-ostree/treefile.json ]; then
    sed -i 's/"selinux": *true/"selinux": false/' /usr/share/rpm-ostree/treefile.json
fi

echo "[rakuos] stale overlay state cleared — prebake will write fresh first-boot state."
echo "[rakuos] Post-build seed complete."

echo "Generating base file manifest..."
/usr/libexec/rakuos/generate-base-manifest

echo "Prebaking hyprland overlay payload..."
prebake_overlay_from_installroot

# Must come after the prebake: that function copies the installroot's /etc over
# this image's /etc, which would drop any group appended before it.
echo "Baking system groups into /etc/group..."
bake_system_groups

# Disable Terra again — build.sh only enabled it for the install steps above
# (main package set + overlay prebake); third-party repos ship disabled by
# default, so the finalized image must go back to that state.
rum config-manager --set-disabled terra
