# Remote_OS 🚀

**Remote_OS** is a lightweight, secure, and locked-down Linux Live USB operating system built on Debian 12 (Bookworm). Designed specifically for secure remote administration and IT support, Remote_OS boots directly into a kiosk workspace featuring only **RustDesk** and **Tailscale**, backed by persistent storage and an auto-updating backend script.

---

## 📸 Overview & Key Features

- **Ultralight Footprint:** Under 800 MB total ISO size built with Debian `minbase` and Openbox.
- **Plug-and-Play Kiosk:** Bypasses traditional desktop clutter and auto-logins into an optimized double-app workspace.
- **Hardened UI Lockdown:** Right-click context menus, terminal access, and system keybindings (e.g., `Ctrl+Alt+T`) are fully disabled.
- **Persistent Storage Support:** Native Debian live persistence support retains login state, Tailscale credentials, and RustDesk configurations across reboots.
- **Auto-Update System:** Integrated `auto-update.sh` background service checks for and upgrades RustDesk and Tailscale binaries on boot whenever an internet connection is detected.

---

## 🏗 System Architecture

```
+-------------------------------------------------------------------+
|                            Remote_OS                              |
+-------------------------------------------------------------------+
|  [ User Space ]       RustDesk UI    |     Tailscale daemon       |
|  [ WM Layer ]                     Openbox WM                      |
|  [ Display ]                X11 Server / LightDM                  |
|  [ Persistence ]       EXT4 Partition Overlay (`/ union`)         |
|  [ Services ]       tailscaled | auto-update.timer | NetworkManager |
|  [ Base System ]        Debian 12 Bookworm (Linux Kernel)         |
+-------------------------------------------------------------------+
```

---

## 📂 Repository Directory Structure

```text
Remote_OS/
├── build.sh                        # One-click build script
├── config/
│   ├── hooks/
│   │   └── normal/
│   │       └── 0100-install-apps.hook.chroot # Installs RustDesk & Tailscale
│   ├── includes.chroot/             # Overlays directly into target OS rootfs
│   │   ├── etc/
│   │   │   ├── lightdm/
│   │   │   │   └── lightdm.conf.d/
│   │   │   │       └── autologin.conf    # Auto-logins kiosk user
│   │   │   └── systemd/
│   │   │       └── system/
│   │   │           ├── auto-update.service # Background updater service
│   │   │           ├── auto-update.timer   # Daily update schedule
│   │   │           ├── kiosk-lockdown.service
│   │   │           └── lightdm.service.d/
│   │   ├── home/
│   │   │   └── kiosk/
│   │   │       └── .config/
│   │   │           └── openbox/
│   │   │               ├── autostart     # Startup app launcher
│   │   │               └── rc.xml        # Locked down keybindings & menus
│   │   └── usr/
│   │       └── local/
│   │       ├── bin/
│   │       │   └── auto-update.sh    # Fetch & install latest updates
│   │       └── libexec/
│   │           ├── kiosk-lockdown
│   │           └── kiosk-session-setup
│   └── package-lists/
│       └── kiosk.list.chroot       # APT package manifest
└── README.md                       # Project documentation
```

---

## ⚙️ Prerequisites & Environment Setup

To compile Remote_OS, you need a Debian/Ubuntu-based build environment (native Linux or WSL2 on Windows).

Install required build dependencies:

```bash
sudo apt update
sudo apt install -y live-build debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin git curl wget
```

Make the build hook and local scripts executable after copying the project to a
Linux filesystem:

```bash
chmod +x build.sh config/hooks/normal/0100-install-apps.hook.chroot \
  config/includes.chroot/usr/local/bin/auto-update.sh \
  config/includes.chroot/usr/local/libexec/kiosk-*
```

---

## 🛠️ Building the ISO

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/your-username/Remote_OS.git
   cd Remote_OS
   ```

2. **Initialize `live-build` Configuration:**
   ```bash
   lb config \
       --distribution bookworm \
       --architectures amd64 \
       --binary-images iso-hybrid \
       --archive-areas "main contrib non-free non-free-firmware" \
       --apt-indices false \
       --apt-recommends false \
       --debootstrap-options "--variant=minbase" \
       --bootappend-live "boot=live components quiet splash persistence"
   ```

3. **Compile the OS:**
   ```bash
   sudo ./build.sh
   ```
   The build hook creates the `kiosk` account, configures the official
   Tailscale repository, and downloads the current amd64 RustDesk `.deb`.
   Upon success, `live-image-amd64.hybrid.iso` is created in the working
   directory.

---

## 💾 Flashing to USB with Persistent Storage

To ensure configurations (Tailscale auth, RustDesk ID, network profiles) are saved across reboots, format your USB drive with two partitions:

### Partition Layout Recommendation
- **Partition 1 (`FAT32` or `ISO9660`, ~1–2 GB):** Bootable OS Image
- **Partition 2 (`EXT4`, Remaining space):** Labeled `persistence`

### Step-by-Step Flashing (Linux)

1. **Write the ISO to the USB disk (not a partition):**
   ```bash
   sudo dd if=live-image-amd64.hybrid.iso of=/dev/sdX status=progress conv=fsync
   ```
   *(Replace `/dev/sdX` with your target USB disk device node. This erases it.)*

2. **Configure Partition 2 for Persistence:**
   Format the remaining USB space as `ext4`, set the volume label to `persistence`, and mount it:
   ```bash
   sudo mkfs.ext4 -L persistence /dev/sdX2
   sudo mkdir -p /mnt/persistence
   sudo mount /dev/sdX2 /mnt/persistence
   ```

3. **Enable Universal Overlay:**
   ```bash
   echo "/ union" | sudo tee /mnt/persistence/persistence.conf
   sudo umount /mnt/persistence
   ```

---

## 🔒 Security & Kiosk Lockdown Features

Remote_OS is configured to prevent user tampering while in session:

- **Disabled Terminal Hotkeys:** `Ctrl+Alt+T`, `Alt+F2`, and shortcut sequences are stripped from `rc.xml`.
- **Disabled Desktop Context Menus:** Mouse right-click actions on the root window are unmapped.
- **No GUI Terminal Emulator:** No terminal binaries (`xterm`, `gnome-terminal`, etc.) are pre-installed in the default PATH.
- **Power & Sleep Management:** Screen dimming, blanking, and suspend modes are disabled via `xset`.

---

## 🔄 Auto-Update Mechanism

Remote_OS features an automated background timer (`auto-update.timer`) that
runs 10 minutes after boot and then approximately once per day.

### How It Works:
1. Waits for an active internet connection via `NetworkManager`.
2. Queries the GitHub API for the latest release of **RustDesk** `.deb`.
3. Checks official **Tailscale** APT repositories for package updates.
4. If a newer release exists, it downloads and upgrades the application in the
   background. With `/ union` persistence enabled, package changes are stored
   on the persistence partition and `dpkg` preserves existing configuration
   files.

The updater uses the official Tailscale APT repository and the latest amd64
RustDesk GitHub release. Network or API failures are reported to the journal;
they are not treated as successful updates.

To view update logs locally:
```bash
journalctl -u auto-update.service
```

To force an update check:

```bash
sudo systemctl start auto-update.service
```

---

## 📄 License

Distributed under the [MIT License](LICENSE). 

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [Issues page](https://github.com/your-username/Remote_OS/issues).