# Gambar Uji RakuOS KineticWE

> **Bahasa:** [English](README.md) · [Bahasa Indonesia](README.id.md)

Spin kustom **KineticWE** dari [RakuOS](https://rakuos.org) — distro Linux atomik
immutable hybrid berbasis Fedora. Repo ini membangun image OCI dengan
KineticWE + shell Noctalia miliknya, greeter X11 SDDM, dan perangkat (toolchain)
yang disetel untuk

laptop dengan **NVIDIA dGPU + AMD iGPU** (mis. ASUS ROG).

- **Registry:** `quay.io/mindset404/kineticwe-nvidia-v3`
- **Base image:** `quay.io/rakuos/rakuos-base-nvidia-v3:staging`
- **Arsitektur:** `linux/amd64`
- **Tag:** `latest`, `<YYYYMMDD>` (tag tanggal, 5 terbaru disimpan)
- **Rebuild:** tiap 3 hari via GitHub Actions (`0 17 */3 * *` UTC, bisa juga dipicu manual)

## Ringkasan singkat

> **Cuma mau instal?** Tidak perlu ubah apa-apa — `bootc switch` gambarnya lalu jalan.
> Bagian "kompatibilitas" di bawah hanya penting kalau kamu **fork dan rebuild**
> gimana kamu sendiri.

```bash
sudo bootc switch quay.io/mindset404/kineticwe-nvidia-v3:latest
sudo reboot
```

Untuk update berikutnya:

```bash
sudo bootc upgrade
sudo reboot
```

---

## Kompatibilitas: umum vs. laptop ini

Gambar ini **dibangun, diuji, dan dipakai setiap hari pada satu mesin
referensi**: **ASUS TUF Gaming A15 FA506ICB** (AMD Ryzen 7 4800H, Radeon iGPU
+ NVIDIA dGPU, Wi-Fi MediaTek MT7921). Gambar ini bekerja di perangkat lain —
beberapa bagian memang khusus untuk hardware itu dan sebaiknya **dihapus saat
kamu fork build-nya**.

| Bagian dari repo ini | Fungsinya | Di perangkat lain |
|---|---|---|
| `build_files/build.sh` — stack desktop, SDDM, dotfiles, peredam tmpfiles, penulisan GID, chrony | Inti gambar | ✅ biarkan |
| `system_files/etc/sddm.conf.d/10-kineticwe.conf` | greeter X11 SDDM; login pengguna memulai sesi Wayland KineticWE | ✅ biarkan |
| `build_files/build.sh` — blok "Mask dkms" | modul sudah ditanam di gambar; dkms runtime tidak pernah dibutuhkan | ✅ biarkan pada gambar NVIDIA |
| `build_files/build.sh` — blok "Disable fwupd" | fwupd menggantung (D-state) pada ASUS ini | ⚠️ hapus — normal di perangkat lain |
| `build_files/build.sh` — blok "Mask mcelog" | unit kosmetik khusus AMD | ⚠️ mesin Intel: biarkan mcelog aktif |
| `system_files/usr/lib/bootc/kargs.d/11-kineticwe-tsc.toml` | `tsc=reliable` (TSC salah deteksi oleh watchdog) | ⚠️ hapus kecuali gejala yang sama |
| `system_files/etc/udev/rules.d/99-thinkpad-thresholds-udev.rules` | mematikan aturan baterai ThinkPad | ⚠️ hapus di ThinkPad/non-ASUS |
| `system_files/var/usrlocal/bin/fwupdmgr` | shim; hanya butuh karena fwupd di-mask | ⚠️ hapus |
| `system_files/usr/lib/systemd/system/nvidia-persistenced.service.d/override.conf` | bootstrap tunggu-node | ✅ biarkan di NVIDIA; tidak relevan selain itu |
| `system_files/usr/lib/systemd/system/nvidia-powerd.service.d/override.conf` | bootstrap tunggu-node yang sama agar dynamic boost benar-benar jalan | ✅ biarkan di NVIDIA; tidak relevan selain itu |
| paket `asusctl` (lihat "Tidak disertakan") | kontrol kipas/lampu ASUS ROG | ⚠️ khusus hardware ASUS |

**Untuk membangun gambar ini di mesin lain:** fork repo, hapus baris bertanda ⚠️
(bisa `git rm` file-nya atau hapus bloknya di `build.sh`), lalu sesuaikan
Selebihnya adalah desktop KineticWE/RakuOS standar.

---

## Yang disertakan

- **Desktop:** KineticWE (default), shell Noctalia KWE, SDDM (greeter X11), kitty
- **Portal/media:** xdg-desktop-portal(`-kwe`/`-gtk`), pipewire + ALSA +
  emulasi PulseAudio, wireplumber, egl-wayland, Xwayland,
  pavucontrol, libnotify
- **Keyring/auth:** gnome-keyring sengaja **tidak disertakan** (Noctalia/KineticWE
  jalan normal tanpa `org.freedesktop.secrets`; dulu menyebabkan crash ganda
  saat login), fprintd-pam, libsecret client lib
- **Dasar:** paket NetworkManager, power-profiles-daemon (pengganti
  tuned-ppd; tuned/tuned-ppd dari base di-mask), gvfs(+mtp/nfs/smb),
  systemd-oomd-defaults, SDDM
- **Perkakas:** tesseract (+10 langpack),
  unzip/zip/7zip/unar, bat, fzf, zoxide, wl-clipboard
- **Tema/font:** colloid-theme (GTK + ikon), papirus-icon-theme (fallback), jetbrains-mono-nerd-fonts
- **Terra** (repo vendor, diaktifkan saat build: `bibata-cursor-theme`,
  `jetbrainsmono-nerd-fonts`, plus deps dasar `dysk`/`fresh`/`surge`/`termflix`/`wlctl`)
- **Aplikasi:** `rakuos-software-qt` (Software Center) + `rakuos-system-qt`
  (`org.rakuos.System`, pengaturan sistem) + `rakuos-welcome-qt` —
  ditanam saat build, entri autostart dihapus (dibuka hanya lewat menu)
- **Browser (overlay):** `zen-browser` — ditanam lebih dulu via `packages.list` /
  `packages-live.list`, tersedia di ISO live dan sistem terpasang
- **NVIDIA dGPU:** diturunkan dari base image NVIDIA (driver + stack CUDA) —
  umum untuk perangkat NVIDIA mana pun; mesin tanpa NVIDIA tinggal tidak
  menggunakannya
- **Sinkronisasi waktu:** `chrony` untuk NTP otomatis (RTC tetap UTC — Windows
  sudah dikonfigurasi dengan `RealTimeIsUniversal=1`, jadi tidak ada offset
  zona waktu lokal)

## Tidak disertakan (opsional)

Aplikasi di bawah ini **tidak ditanam** — pasang setelah boot pertama dengan:

```bash
sudo rum install <package>     # overlay (tahan image upgrade)
sudo dnf5 install <package>    # lapisan base image (dev-only, tidak atomik)
```

Keybind KineticWE sudah mengarah ke semuanya:

- **editor** `zeditor`, **kalkulator** `gnome-calculator`, **pemutar video/audio**
  `mpv`
- **asusctl** (kontrol kipas/lampu ASUS ROG) — **khusus hardware ASUS**;
  lewati di perangkat lain:
  ```bash
  sudo rum install asusctl
  ```

## Pembagian overlay & live

- `packages.list` (overlay — ISO live **dan** sistem terpasang): `zen-browser`
- `packages-live.list` (khusus ISO live, tidak dibawa ke instalasi): `zen-browser`

---

## Cara membangunnya

`.github/workflows/build.yml` berjalan di GitHub Actions:

1. `docker buildx build --provenance=false` — manifest tunggal, sehingga Quay
   menampilkan ukuran gambar yang sebenarnya.
2. Base = RakuOS `rakuos-base-nvidia-v3:staging` (COPR
   `mindset/Mindset-Apps`, repo Terra/RPM-Fusion disesuaikan).
3. Menulis GID sistem kanonik ke `/etc/group` (audio/video/input/kvm/utmp
   dst. — base `bootc-minimal` tidak punya modul NSS `altfiles`, jadi
   `getent` memakai file) dan meredam tmpfiles systemd yang bising
   (`home.conf`/`root.conf` → `/dev/null`, `provision.conf` dipangkas) di
   `build.sh`.
4. Menonaktifkan `rum-makecache.timer` — refresh metadata repo `rum makecache`
   berkala tidak diperlukan di gambar immutable; `rum` mengambil metadata
   on-demand saat install.
5. Push `latest` + tag tanggal ke `quay.io/mindset404/kineticwe-nvidia-v3`.
6. **Retensi:** menghapus tag tanggal yang lebih lama dari 5 terbaru (menjaga
   penyimpanan tetap dalam kuota gratis Quay).
7. Pemulihan otomatis kunci tanda tangan Terra (refresh `key.asc` dari Fyralabs,
   kembali ke menonaktifkan `gpgcheck` jika kunci berputar lagi).
8. Mengaktifkan NTP (`chrony`) — SELinux tetap dihapus sesuai kebijakan base.

### Pemicu manual

```bash
gh workflow run "Build RakuOS KineticWE Image" --repo tofan79/custome-rakuos --ref kineticwe
```

Input workflow: `base_image_tag` (default `staging`) dan `rakuos_staging`
(default `1`).

---

## Menjaga sistem tetap ter-update

Tag baru dipush ke `quay.io/mindset404/kineticwe-nvidia-v3:latest`; menarik
referensi itu adalah semua yang dibutuhkan `bootc upgrade` untuk mendeteksi
build baru. `rakuos-updater.service` + `.timer` (harian 03:00 UTC) juga
memeriksa update gambar dan overlay secara otomatis.

> **Catatan:** plugin panel Noctalia "RakuOS Updates" beserta berkas sudoers
> pendukungnya sudah dihapus — urusan update center berjalan lewat
> `rakuos-updater` dan CLI `rum`/`bootc`.

## Update & pemecahan masalah

Gambar ini mengikuti base RakuOS pada tag **mengambang** (floating), sehingga
setiap rebuild menarik `rakuos-base-nvidia-v3:staging` terbaru. Upstream
merilis 1–3 update base per hari; build repo ini berjalan:

- **Otomatis tiap 3 hari** pukul 17:00 UTC (`0 17 */3 * *`)
- **Manual kapan saja** lewat `Actions → Run workflow`

### Penelusuran digest base

Setiap build mencatat base persis dari mana ia dibangun:

- Langkah **"Resolve base image digest"** mencetak digest sebelum membangun.
- Nilai digest ditanam ke label gambar `org.rakuos.base-digest`.
- Halaman run menampilkan ringkasan **Build info** (digest base + revisi commit).

Gunakan untuk menelusuri regresi: bandingkan digest build yang gagal dengan
yang terakhir sukses.

### Kapan dicek / apa yang dilakukan

1. **Setelah setiap update** — pemeriksaan cepat:
   ```bash
   sudo bootc upgrade && sudo reboot
   systemctl --failed            # harap kosong
   ```
2. **Build gagal** → baca langkah yang gagal. Penyebab biasanya salah satu dari:
   - Perubahan **base staging upstream** (sering kernel/`dkms-nvidia`/rakuos-core) —
     bandingkan digest yang gagal dengan yang terakhir sukses, lalu coba lagi.
   - **Lapisan kita** (prebake/scriptlet, `post-build*.sh`, `system_files`) —
     perbaiki di repo ini lalu build ulang.
3. **Masalah runtime setelah upgrade** → cek digest gambar yang berjalan
   (`podman image inspect --format '{{.Labels}}' ...`). Jika regresi berasal dari
   perubahan base, laporkan ke upstream (`rakuos-base`); untuk membangun ulang
   terhadap base yang lebih lama, pin sementara digest di `Containerfile` lalu
   picu ulang.

## Kekhasan perangkat yang diketahui (ASUS TUF Gaming A15 FA506ICB)

Hardware referensi untuk gambar ini adalah **ASUS TUF Gaming A15 FA506ICB** —
AMD **Ryzen 7 4800H** (Zen 2) + **Radeon iGPU** (Vega) + **NVIDIA dGPU**
(terhubung lewat base NVIDIA v3). Semua di bawah ini **khusus silicon mesin
ini** — perangkat lain sebaiknya membuang workaround kategori **2** (lihat
bagian Kompatibilitas di atas).

### 1. "Bising" boot/kernel yang tidak berbahaya

Hanya log, tanpa dampak fungsional, aman di perangkat mana pun:

- ACPI `_TZ.THRM._SCP` / `AE_NOT_FOUND` — stub metode termal ACPI
- asersi `NVRM PlatformRequestHandler` SBIOS (ambil temp / mode daya)
- `amdgpu DCN reg offset` — dump register layar internal saat init
- `bpf-restrict-fs` — kernel gagal memuat objek BPF LSM
- `mcelog` gagal: **CPU AMD tidak didukung daemon userspace mcelog**
  (`AMD Processor family 23`); dekode MCE AMD ada di dalam kernel
  (`edac_mce_amd`) sehingga unit-nya di-`mask` di `build.sh`

> **Biarkan saja.** Ini pesan log kernel/driver, bukan unit systemd yang bisa
> di-`mask`; satu-satunya unit (`mcelog`) memang sudah di-mask di `build.sh`.

### 2. Workaround hardware nyata yang disertakan dalam gambar

Khusus perangkat — hapus saat membangun untuk hardware lain:

- **Wi-Fi MT7921 gantung** (`14c3:7961`, MediaTek Filogic 330): driver bisa
  menggantung beberapa menit setelah boot dengan `driver own failed` /
  `Timeout for driver own` / `chip reset failed` (bug upstream terkenal
  #215391, #220353). Ini **bug driver/firmware upstream, masih terbuka**.
  Workaround yang tadinya disertakan di sini (`mt7921e disable_aspm=1`,
  `wifi.powersave = 2`) **tidak mencegah** hang tersebut, jadi sudah dihapus —
  pantau image base untuk perbaikan di level kernel.
- **fwupd** tetap **di-mask** di hardware ini (daemon menggantung di D-state);
  shim `fwupdmgr --version` membuat konsumen API firmware tetap tidak error,
  tetapi refresh/update LVFS sengaja non-fungsional di sini.
- **Penggantian sumber jam TSC → HPET:** watchdog sumber jam menandai TSC
  `unstable due to frequency skew` dibanding HPET saat boot dan beralih ke HPET
  (performa pencatatan waktu lebih rendah). CPU di sini punya TSC invariant
  (`constant_tsc` + `nonstop_tsc`), jadi TSC andal dan yang melenceng adalah
  HPET. Diperbaiki dengan karg `tsc=reliable`, ditanam via
  `system_files/usr/lib/bootc/kargs.d/11-kineticwe-tsc.toml` (digabung bootc
  di atas `10-rakuos.toml` base, berlaku pada `bootc upgrade` berikutnya).
- **`nvidia-powerd` mati diam-diam:** base mengaktifkan service, tetapi
  `ConditionPathExistsGlob=/dev/nvidia*` bawaan dievaluasi sebelum modul dGPU
  membuat node (race boot yang sama dengan `nvidia-persistenced`), sehingga
  selalu dilewati. Diperbaiki dengan drop-in yang serupa
  (`system_files/usr/lib/systemd/system/nvidia-powerd.service.d/override.conf`)
  yang menghapus kondisi dan melakukan polling `/dev/nvidia0` pada
  `ExecStartPre` — dynamic boost kini berjalan saat dGPU aktif. Barang mati
  yang tidak berbahaya di perangkat tanpa NVIDIA.

> **Untuk menghapus ini di perangkat lain** (masing-masing juga tercantum di
> bagian Kompatibilitas):
>
> - `system_files/usr/lib/bootc/kargs.d/11-kineticwe-tsc.toml` — `tsc=reliable`
>   (biarkan hanya jika CPU kamu menampilkan `clocksource: unstable TSC` yang sama)
> - `system_files/etc/udev/rules.d/99-thinkpad-thresholds-udev.rules` — mematikan
>   aturan ThinkPad (driver baterai ASUS tidak punya atribut charge itu)
> - `system_files/usr/lib/systemd/system/nvidia-powerd.service.d/override.conf`
>   (+ yang persistenced) — khusus NVIDIA, hapus di mesin iGPU-only
> - `system_files/var/usrlocal/bin/fwupdmgr` + blok "Disable fwupd" di
>   `build_files/build.sh` — gantung D-state khusus ASUS ini; hardware lain
>   biasanya punya update firmware yang berfungsi
> - blok "Mask mcelog" di `build_files/build.sh` — khusus AMD (Intel
>   membiarkan mcelog aktif)

---

## Lisensi

Dilisensikan di bawah [Apache License 2.0](LICENSE).

Proyek ini dibangun di atas **[RakuOS](https://rakuos.org)** — Linux berbasis
gambar atomik di Fedora. Proyek RakuOS juga Apache 2.0
(lihat [gitlab.com/rakuos](https://gitlab.com/rakuos), mis. `rakuos-base`).
KineticWE, Noctalia, dan paket lain tetap dengan lisensinya masing-masing.

> **Pernyataan:** ini adalah **gambar tak resmi buatan komunitas**. Tidak
> berafiliasi dengan, mendapat dukungan dari, atau merupakan produk proyek
> RakuOS. "RakuOS" dan merek terkait adalah milik pemiliknya masing-masing dan
> digunakan hanya untuk mendeskripsikan base upstream yang dipakai gambar ini.
