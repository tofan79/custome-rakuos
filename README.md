# RakuOS Hyprland Image

> **Languages:** [English](README.md) · [Bahasa Indonesia](README.id.md)

Custom **Hyprland** spin of [RakuOS](https://rakuos.org) — a hybrid atomic,
immutable Linux distro built on Fedora. This repository builds an OCI image
with Hyprland + uWSM, the SDDM X11 greeter, and a tuned toolchain for laptops
with an **NVIDIA dGPU + AMD iGPU** (e.g. ASUS ROG).

- **Registry:** `quay.io/mindset404/hyprland-nvidia-v3`
- **Base image:** `quay.io/rakuos/rakuos-base-nvidia-v3:staging`
- **Architecture:** `linux/amd64`
- **Tags:** `latest`, `<YYYYMMDD>` (date tag, 5 kept)
- **Rebuild:** every 3 days via GitHub Actions (`0 17 */3 * *` UTC, manual trigger supported)

## TL;DR

> **Just want to install it?** Nothing to change — `bootc switch` the image and go.
> The "compatibility" section below only matters if you **fork and rebuild** the
> image for your own device.

```bash
sudo bootc switch quay.io/mindset404/hyprland-nvidia-v3:latest
sudo reboot
```

For later updates:

```bash
sudo bootc upgrade
sudo reboot
```

---

## Compatibility: generic vs. this laptop

This image is **built, tested and daily-driven on one reference machine**:
**ASUS TUF Gaming A15 FA506ICB** (AMD Ryzen 7 4800H, Radeon iGPU + NVIDIA
dGPU, MediaTek MT7921 Wi-Fi). It works on other devices — a few parts are
specific to that hardware and should be **removed when you fork the build**.

| Part of this repo | What it is | On another device |
|---|---|---|
| `build_files/build.sh` — desktop stack, SDDM, dotfiles, tmpfiles quieting, GID baking, chrony | Core image | ✅ keep |
| `system_files/etc/sddm.conf.d/10-hyprland.conf` | SDDM X11 greeter; user login still starts the Hyprland Wayland/UWSM session | ✅ keep |
| `build_files/build.sh` — "Mask dkms" block | modules pre-baked; runtime dkms never needed | ✅ keep on NVIDIA images |
| `build_files/build.sh` — "Disable fwupd" block | fwupd hangs in D-state on this ASUS | ⚠️ remove — works fine elsewhere |
| `build_files/build.sh` — "Mask mcelog" block | AMD-only cosmetic unit | ⚠️ Intel machines: keep mcelog |
| `system_files/usr/lib/bootc/kargs.d/11-hyprland-tsc.toml` | `tsc=reliable` (TSC watchdog false alarm) | ⚠️ remove unless same symptom |
| `system_files/etc/udev/rules.d/99-thinkpad-thresholds-udev.rules` | masks a ThinkPad battery rule | ⚠️ remove on ThinkPad/non-ASUS |
| `system_files/var/usrlocal/bin/fwupdmgr` | shim; only needed because fwupd is masked | ⚠️ remove |
| `system_files/usr/lib/systemd/system/nvidia-persistenced.service.d/override.conf` | wait-for-node bootstrap | ✅ keep on NVIDIA; irrelevant otherwise |
| `system_files/usr/lib/systemd/system/nvidia-powerd.service.d/override.conf` | same wait-for-node bootstrap so dynamic boost actually runs | ✅ keep on NVIDIA; irrelevant otherwise |
| `system_files/etc/skel/.config/hypr/config/monitors.lua` | `eDP-1 1920x1080@144` layout | ⚠️ edit to your panel/resolution |
| `system_files/etc/skel/.config/hypr/config/lid.lua` | laptop lid → lock + suspend | ✅ keep (works on any laptop) |
| `asusctl` package (see "Not included") | ASUS ROG fan/light control | ⚠️ ASUS hardware only |

**To build this image for another machine:** fork the repo, remove the rows
marked ⚠️ (either `git rm` the files or delete the blocks in `build.sh`), and
adapt `monitors.lua`. Everything else is a standard Hyprland/RakuOS desktop.

---

## Included

- **Desktop:** Hyprland, uWSM, SDDM (X11 greeter), kitty
- **Portal/media:** xdg-desktop-portal(`-hyprland`/`-gtk`), pipewire + ALSA +
  PulseAudio emulation, wireplumber, egl-wayland, Xwayland, wl-clipboard,
  grim+slurp, pavucontrol, libnotify
- **Keyring/auth:** gnome-keyring intentionally **excluded** (Noctalia/Hyprland
  work fine without `org.freedesktop.secrets` and it previously caused
  dual-daemon crashes at login), fprintd-pam, libsecret client lib
- **Base duties:** NetworkManager suite, power-profiles-daemon (replaces
  tuned-ppd; base's tuned/tuned-ppd services are masked), gvfs(+mtp/nfs/smb),
  systemd-oomd-defaults, SDDM
- **Tools:** swash, tesseract (+10 langpacks), zbar, hyprpicker, cliphist,
  brightnessctl, playerctl, unzip/zip/7zip/unar, bat, fzf, zoxide
- **Theme/fonts:** colloid-theme (GTK + icons), papirus-icon-theme (fallback), jetbrains-mono-nerd-fonts
- **Terra** (vendor repo, enabled at build: `bibata-cursor-theme`,
  `jetbrainsmono-nerd-fonts`, plus base deps `dysk`/`fresh`/`surge`/`termflix`/`wlctl`)
- **Apps:** `rakuos-software-qt` (Software Center) + `rakuos-system-qt`
  (`org.rakuos.System` settings) + `rakuos-welcome-qt` — installed baked,
  autostart entries removed (open only via menu)
- **Browser (overlay):** `zen-browser` — prebaked via `packages.list` /
  `packages-live.list`, present on live and installed systems
- **NVIDIA dGPU:** inherited from the NVIDIA base image (driver + CUDA stack) —
  generic for any NVIDIA device; machines without NVIDIA simply don't use it
- **Time sync:** `chrony` for automatic NTP (RTC stays UTC — Windows already
  configured with `RealTimeIsUniversal=1`, so no local-time offset)

## Not included (optional)

Apps below are **not baked** — install them after first boot with:

```bash
sudo rum install <package>     # overlay (survives image upgrades)
sudo dnf5 install <package>    # base image layer (dev-only, not atomic)
```

Hyprland keybinds (`variables.lua`) already point at them:

- **editor** `zeditor`, **calculator** `gnome-calculator`, **video/audio
  player** `mpv`
- **asusctl** (ASUS ROG fan/light control) — **ASUS hardware only**; skip on
  other devices:
  ```bash
  sudo rum install asusctl
  ```

## Overlay & live split

- `packages.list` (overlay — live ISO **and** installed system): `zen-browser`
- `packages-live.list` (live ISO only, not carried into installs): `zen-browser`

---

## How it's built

`.github/workflows/build.yml` runs on GitHub Actions:

1. `docker buildx build --provenance=false` — single-manifest, so Quay shows
   the real image size.
2. Base = RakuOS `rakuos-base-nvidia-v3:staging` (COPR Hyprland +
   `mindset/Mindset-Apps`, Terra/RPM-Fusion repos tuned).
3. Bakes canonical system GIDs into `/etc/group` (audio/video/input/kvm/utmp
   etc. — the `bootc-minimal` base lacks the `altfiles` NSS module, so
   `getent` falls back to the file) and quiets noisy systemd tmpfiles
   (`home.conf`/`root.conf` → `/dev/null`, trimmed `provision.conf`) in
   `build.sh`.
4. Disables `rum-makecache.timer` — the periodic `rum makecache` repo-metadata
   refresh is unneeded on an immutable image; `rum` pulls metadata on demand
   during install.
4. Pushes `latest` + date tag to `quay.io/mindset404/hyprland-nvidia-v3`.
5. **Retention:** deletes date tags older than the 5 newest (keeps storage
   within Quay free tier).
6. Terra signing-key auto-recovery (refreshes `key.asc` from Fyralabs, falls
   back to disabling `gpgcheck` if the keys rotate again).
7. Enables NTP (`chrony`) — SELinux stays removed per base policy.

### Manual trigger

```bash
gh workflow run "Build RakuOS Hyprland Image" --repo tofan79/custome-rakuos --ref hyprland
```

Workflow inputs: `base_image_tag` (default `staging`) and `rakuos_staging`
(default `1`).

---

## Keeping the system up to date

New image tags are pushed to `quay.io/mindset404/hyprland-nvidia-v3:latest`;
pulling that reference is all `bootc upgrade` needs to detect a new build.
The `rakuos-updater.service`+`.timer` (daily at 03:00 UTC) also checks for new
image and overlay updates automatically.

> **Note:** the RakuOS Updates Noctalia panel plugin and its sudoers drop-in
> were removed — update-center duties run through `rakuos-updater` and the
> `rum`/`bootc` CLI.

## Update & troubleshooting

This image follows the RakuOS base on a **floating** tag, so each rebuild pulls
the latest `rakuos-base-nvidia-v3:staging`. Upstream ships 1–3 base updates per
day; this repo's builds run:

- **Automatically every 3 days** at 17:00 UTC (`0 17 */3 * *`)
- **Manually anytime** via `Actions → Run workflow`

### Base digest tracing

Every build records which exact base it was built from:

- Step **"Resolve base image digest"** prints the digest before building.
- The digested value is baked into the image label `org.rakuos.base-digest`.
- The run page shows a **Build info** summary (base digest + commit revision).

Use it to pin down regressions: compare the digest of a failing build against
the last known-good one.

### When to look / what to do

1. **After every update** — quick sanity check:
   ```bash
   sudo bootc upgrade && sudo reboot
   systemctl --failed            # expect empty
   ```
2. **Build fails** → read the failing step. Cause is usually one of:
   - Upstream **base staging change** (often kernel/`dkms-nvidia`/rakuos-core) —
     compare the failed digest with the last successful one, then retry.
   - **Our layer** (prebake/scriptlets, `post-build*.sh`, `system_files`) — fix
     in this repo and rebuild.
3. **Runtime issue after upgrading** → check the digest of the running image
   (`podman image inspect --format '{{.Labels}}' ...`). If it regressed from a
   base change, report upstream (`rakuos-base`); to rebuild against an older
   base, temporarily pin the digest in `Containerfile` and re-trigger.

## Known device quirks (ASUS TUF Gaming A15 FA506ICB)

The reference hardware this image is tuned for is **ASUS TUF Gaming A15
FA506ICB** — AMD **Ryzen 7 4800H** (Zen 2) + **Radeon iGPU** (Vega) + **NVIDIA
dGPU** (hooked through the NVIDIA v3 base). Everything below is **specific to
this machine's silicon** — other devices should drop the category **2**
workarounds (see the Compatibility section above).

### 1. Harmless boot/kernel "noise"

Log-only, no functional impact, safe on any device:

- ACPI `_TZ.THRM._SCP` / `AE_NOT_FOUND` — thermal ACPI method stub
- `NVRM PlatformRequestHandler` SBIOS assertions (get temp / power mode)
- `amdgpu DCN reg offset` — internal display register dump at init
- `bpf-restrict-fs` — BPF LSM object load failure on this kernel
- `mcelog` fails: **AMD CPUs are not supported by the mcelog userspace** daemon
  (`AMD Processor family 23`); AMD MCE decoding is in-kernel (`edac_mce_amd`)
  so the unit is `mask`ed in `build.sh`

### 2. Real hardware workarounds shipped in this image

Device-specific — remove when building for other hardware:

- **MT7921 Wi-Fi hang** (`14c3:7961`, MediaTek Filogic 330): driver can hang
  minutes after boot with `driver own failed` / `Timeout for driver own` /
  `chip reset failed` (known upstream bugs #215391, #220353). This is an
  **upstream driver/firmware bug**, still open. Workarounds that were shipped
  here (`mt7921e disable_aspm=1`, `wifi.powersave = 2`) did **not** prevent it,
  so they were removed — watch the base image for a kernel-level fix.
- **fwupd** stays **masked** on this hardware (daemon hangs in D-state); a
  `fwupdmgr --version` shim keeps firmware API consumers non-errored, but LVFS
  refresh/update is intentionally non-functional here.
- **TSC → HPET clocksource fallback:** the clocksource watchdog flags TSC
  `unstable due to frequency skew` vs HPET at boot and falls back to HPET
  (lower timekeeping performance). CPU here has an invariant TSC
  (`constant_tsc` + `nonstop_tsc`), so the TSC is reliable and the HPET is the
  drifting one. Fixed with karg `tsc=reliable`, baked via
  `system_files/usr/lib/bootc/kargs.d/11-hyprland-tsc.toml` (merged by bootc
  over the base's `10-rakuos.toml`, applied on next `bootc upgrade`).
- **`nvidia-powerd` silently dead:** base enables the service, but cond's stock
  `ConditionPathExistsGlob=/dev/nvidia*` is evaluated before the dGPU module
  creates the nodes (same boot race as `nvidia-persistenced`), so it was
  skipped forever. Fixed with a matching drop-in
  (`system_files/usr/lib/systemd/system/nvidia-powerd.service.d/override.conf`)
  that drops the condition and polls for `/dev/nvidia0` in `ExecStartPre` —
  dynamic boost now runs when the dGPU is active. Harmless dead weight on
  non-NVIDIA devices.

> **To remove these on another device** (each is also listed in the
> Compatibility section):
>
> - `system_files/usr/lib/bootc/kargs.d/11-hyprland-tsc.toml` — `tsc=reliable`
>   (keep only if your CPU shows the same `clocksource: unstable TSC` at boot)
> - `system_files/etc/udev/rules.d/99-thinkpad-thresholds-udev.rules` — masks a
>   ThinkPad rule (ASUS battery driver lacks those charge attrs)
> - `system_files/usr/lib/systemd/system/nvidia-powerd.service.d/override.conf`
>   (+ the persistenced one) — NVIDIA-only, remove on iGPU-only machines
> - `system_files/var/usrlocal/bin/fwupdmgr` + the "Disable fwupd" block in
>   `build_files/build.sh` — this ASUS D-state hang; other hardware usually has
>   working firmware updates
> - the "Mask mcelog" block in `build_files/build.sh` — AMD only (Intel keeps
>   mcelog)
> - `system_files/etc/skel/.config/hypr/config/monitors.lua` — replace the
>   `eDP-1 1920x1080@144` layout with your own panel/resolution

---

## License

Licensed under the [Apache License 2.0](LICENSE).

This project builds on **[RakuOS](https://rakuos.org)** — atomic image-based
Linux on Fedora. RakuOS projects are Apache 2.0 as well
(see [gitlab.com/rakuos](https://gitlab.com/rakuos), e.g. `rakuos-base`).
Hyprland is GPL-3.0; uWSM, Noctalia and included packages retain their own
licenses.

> **Disclaimer:** this is an **unofficial, community-built image**. It is not
> affiliated with, endorsed by, or a product of the RakuOS project. "RakuOS"
> and associated marks are property of their respective owners and are used
> only to describe the upstream base this image builds on.