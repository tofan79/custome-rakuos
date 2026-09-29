# Masked units and disabled units

These are symlinks to /dev/null, shipped as files (Containerfile does
`COPY system_files /`). They are byte-identical to what `systemctl mask`
would have produced, so the reason each one is masked is recorded here
instead of next to the command in build.sh.

## /etc/systemd/system/

- **dkms.service** — NVIDIA modules are pre-baked into the image for its
  exact kernel, so boot-time autoinstall always fails ("already installed,
  need --force"). Kernel updates ship freshly compiled modules from the image
  CI, so runtime dkms is never needed.
  Devices without an NVIDIA dGPU are unaffected.

- **grub-boot-success.{service,timer}** — also ships a user-scope unit that
  fires 2 min after login and fails (grub2-set-bootflag needs root),
  spamming a failed service notification every session. Masked in both system
  and user scope.

- **fwupd.service, fwupd-refresh.{service,timer}** — the daemon hangs in
  D-state on this AMD+NVIDIA hybrid ASUS laptop, stalling boot ~3 min and
  ending in a failed unit. Firmware updates stay manual (menu/EFI).
  Do NOT disable on other hardware; fwupd works normally elsewhere.

- **mcelog.service** — mcelog userspace daemon does not support AMD (Zen)
  CPUs and aborts every boot ("mcelog: ERROR: AMD Processor family 23: mcelog
  does not support this processor"), leaving a spurious failed unit. AMD MCE
  decoding is handled in-kernel (edac_mce_amd) already, so this is cosmetic.
  Relevant here: AMD Ryzen 7 4800H (Zen 2, ACPI family 17h reported as 23).
  AMD-only device; Intel machines should keep mcelog enabled.

- **tuned.service, tuned-ppd.service** — tuned (a plain tuner from the base
  image) is left in place, but tuned-ppd — the layer that claimed the Power
  Profiles API — is replaced by power-profiles-daemon. Masking the base's
  tuned.service + tuned-ppd.service keeps a single power manager owning CPU
  tuning and the PPD D-Bus interface. Without the mask, tuned's default
  "balanced" profile (governor + energy_performance_preference +
  platform_profile) fights power-profiles-daemon over the same sysfs knobs.
  tuned.service is auto-enabled by the tuned package preset at install time,
  so it must be masked explicitly.

## /etc/systemd/user/

- **grub-boot-success.{service,timer}** — user-scope counterpart of the
  system-scope mask above; same reasoning.

## /etc/tmpfiles.d/

- **home.conf, root.conf** — quiet cosmetic systemd-tmpfiles noise on this
  immutable system. home.conf: /home and /srv are symlinks into /var here, so
  the Q/q rules log "already exists and is not a directory" every boot.
  root.conf: its `z / 555` rule tries to chmod /, which is a read-only
  composefs mount -> "fchmod() of / failed: Read-only file system".

- **provision.conf** — a trimmed copy of the base
  /usr/lib/tmpfiles.d/provision.conf. The `d- /root` line is dropped because
  /root is a symlink to /var/roothome on this system (would log "already
  exists and is not a directory"). The credential-based provisioning rules
  are kept.

## dconf system default

- **/etc/dconf/db/local.d/00-nautilus-open-any-terminal** — points
  nautilus-open-any-terminal at kitty, the terminal this image ships. The
  extension hardcodes "gnome-terminal" and crashes on images without it. It
  lives in the dconf system database (not /etc/skel) because GLib's default
  backend is dconf, which ignores a keyfile under .config/glib-2.0/settings.
  build.sh runs `dconf update` to compile it.
