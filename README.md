# Zyxel-Local-Toolkit

**Local diagnostic, configuration management, and interoperability toolkit for Zyxel modems and routers**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-blue.svg)](#usage)
[![Release: v1.0.0](https://img.shields.io/badge/Release-v1.0.0-brightgreen.svg)](https://github.com/iamfahrig/Zyxel-Local-Toolkit/releases)
[![Downloads](https://img.shields.io/github/downloads/iamfahrig/Zyxel-Local-Toolkit/total?color=blue)](https://github.com/iamfahrig/Zyxel-Local-Toolkit/releases)
[![Hardware](https://img.shields.io/badge/Hardware-Zyxel%20NR%20Series-green.svg)](#supported-hardware)

> 🌐 **Language / Dil:** &nbsp; [ **English** ](README.md) &nbsp;•&nbsp; [ **Türkçe** ](README_TR.md)

---

## 📌 About

An open-source utility that allows users to perform local network diagnostics, configuration backup/restore, and independent management on their own Zyxel devices.  
Operates completely offline on the local network; there is no external server communication or telemetry. Designed to facilitate interoperability and the right to repair on user-owned hardware.

---

## 📁 Project Structure

```text
Zyxel-Local-Toolkit/
├── core/                  # Diagnostic & cryptographic engines (PowerShell & Python)
│   ├── unlock.ps1         # Windows native diagnostic engine (zero-dependency)
│   └── unlock.py          # Linux & macOS native diagnostic engine
├── START.bat              # Windows launcher (double-click to run)
├── start.command          # macOS launcher (double-click in Finder)
├── start.sh               # Linux launcher (run via terminal)
├── LICENSE                # MIT License
├── README.md              # English documentation
└── README_TR.md           # Türkçe dokümantasyon
```

---

## ⚡ Key Features

* **Config Package Unpacker:** Converts `backup.bin` into human-readable `zcfg_config.json`.
* **Custom Config Restore:** Repacks modified JSON into the device standard binary format.
* **Hybrid Session Engine:** Authenticates with the device's native `/UserLogin` endpoint using AES-256-CBC and RSA-2048.
* **Local Diagnostic Services:** Enables SSH (22), Telnet (23), FTP (21), and Web (80/443) services on the local network.
* **CWMP / Telemetry Reset:** Redirects TR-069 and TR-369 remote management endpoints to local default (`127.0.0.1:0`).
* **Timestamped Archives:** Automatically saves every retrieved configuration to `yedek_YYYY-MM-DD_HH-mm-ss/`.

---

<a id="supported-hardware"></a>
## 📋 Supported Hardware

| Model Family | Examples / Tested Models | Architecture | Status |
|:---|:---|:---|:---|
| **NR Indoor Series** | **Zyxel NR5313** (Wi-Fi 7) | ZCFG / 5G Indoor | 🟢&nbsp;**Tested & Verified** |
| **Wi-Fi 7 Series** | NR5307 · NR5331 · NR5731 · NR5333 | ZCFG Unified WebAPI | 🔵&nbsp;**Family Compatible** |
| **NR Indoor Series** | NR5103 · NR5101 · NR5103EV3 · NR5309 | ZCFG Unified WebAPI | 🔵&nbsp;**Family Compatible** |
| **NR Outdoor Series** | NR7101 · NR7102 · NR7103 · NR7301 · NR7501 | ZCFG Unified WebAPI | 🟡&nbsp;**Community Testing** |
| **Gateway Series** | VMG3625 · VMG8623 · DX3301 · EX3300 · EX5401 | ZCFG Unified WebAPI | 🟡&nbsp;**Community Testing** |

> These models share the same ZCFG object model and web API architecture. Compatibility may vary by firmware build.  
> **Feel free to open an issue to report tested hardware or contribute.**

---

<a id="download"></a>
## 📥 Download

Get the ready-to-run package using any of the following methods:

| Method | Link / Action | Details |
|:---|:---|:---|
| **Release v1.0.0 (ZIP)** | [**Download Zyxel-Local-Toolkit-v1.0.0.zip**](https://github.com/iamfahrig/Zyxel-Local-Toolkit/releases/download/v1.0.0/Zyxel-Local-Toolkit-v1.0.0.zip) | Verified official release package, extract and run |
| **Latest Source (ZIP)** | [**Download Latest ZIP**](https://github.com/iamfahrig/Zyxel-Local-Toolkit/archive/refs/heads/main.zip) | Direct download from `main` branch |
| **GitHub Releases** | [**View Releases Page**](https://github.com/iamfahrig/Zyxel-Local-Toolkit/releases) | Packaged zip releases, assets & changelog |
| **Git Clone** | `git clone https://github.com/iamfahrig/Zyxel-Local-Toolkit.git` | Recommended for developers and terminal users |

---

<a id="usage"></a>
## 🚀 Usage

### 1. Setup
1. Extract the downloaded `Zyxel-Local-Toolkit.zip` archive into a folder.
2. Connect your computer to the router via **Ethernet cable** or **Wi-Fi**.
3. Have your router web management password ready (found on the device sticker).

### 2. Running
* **Windows:** Double-click **`START.bat`**.
* **macOS:** Double-click **`start.command`** (or run `./start.sh` in Terminal).
* **Linux:** Open a terminal and execute **`./start.sh`**.

### 3. Select Mode
Choose your preferred language (English / Türkçe), then select an operation:

| Mode | Action | Estimated Time & Device Status |
|:---:|---|:---:|
| **1** | Enable SSH/Telnet & disable remote CWMP (auto-backups first) | ~90-120s (device reboots) |
| **2** | Export current configuration as readable JSON | ~5s (no reboot) |
| **3** | Restore modified JSON configuration to device | ~90-120s (device reboots) |

Enter your router IP (default `192.168.1.1`) and web password.  
Default username: **admin**

### 4. Post-Operation & Access
* **Modes 1 & 3:** The device automatically reboots to apply settings. Full reboot, 5G cellular link, and Wi-Fi broadcast take **90 to 120 seconds (1.5 - 2 minutes)**. Do not unplug the router; wait until LED lights stabilize.
* **Access after Mode 1:**
  * **SSH:** `ssh root@192.168.1.1` (Port: 22, Password: your router web password)
  * **Web:** `http://192.168.1.1` (Username: `admin`)
  * **FTP:** `ftp://192.168.1.1` (Port: 21)
  * **Telnet:** `telnet 192.168.1.1 23`
* **Account Roles:**
  * `admin` → Default privileged web interface account
  * `root` → Privileged shell and FTP account
  * `sUser` → Elevated system account
* **Mode 2:** The device does not reboot. `zcfg_config.json` is exported within ~5 seconds into the backup folder.

---

## 🔄 Factory Reset (Recovery)

* **Hardware Reset Button (Easiest):** Press and hold the `Reset` pinhole on the back for **10-15 seconds** with a paperclip or pin. When the LEDs flash, release it. The device resets to factory defaults.
* **Web GUI:** `Maintenance → Reboot → Factory Default`.
* **From Backup:** Restore the original `zcfg_config.json` package using `Mode 3`.

---

## 🔒 Security & Privacy

* Operates strictly on the local area network (LAN); no external server communication.
* Backups (`yedek_*/`, `*.bin`, `*.json`) remain strictly in your local working directory and are never uploaded or transmitted.
* Passwords are held temporarily in memory and never written to disk.

---

## ⚖️ Legal Notice & Compliance

This project is conducted under the legal framework of **interoperability** and the **right to repair** on user-owned hardware:

* **EU Software Directive (2009/24/EC) Article 6** — Permits reverse engineering and interoperability analysis without authorization from the copyright holder.
* **US DMCA § 1201(f)** — Reverse engineering exemption for interoperability of computer programs.
* **Right to Repair** — Protects the right of hardware owners to inspect, diagnose, and configure their equipment.
* **Turkish Law on Intellectual and Artistic Works (FSEK) Article 38** — Permits necessary technical analysis and interoperability procedures.

> **Statement:** This repository contains no proprietary firmware binaries, trade secrets, or personal data. All diagnostic operations run locally on data retrieved from the user's own hardware.

### Disclaimer
This software is provided for **educational, research, and interoperability** purposes. Modifying configurations may affect warranty status. The user assumes all technical and operational responsibility. Not intended for unauthorized access or service disruption.

### Responsible Disclosure
All technical findings are documented for offline interoperability and local diagnostic purposes. No remote exploits or external services are targeted.

---

## 📄 License

Distributed under the [MIT License](LICENSE).

---

*Last update: 2026*
