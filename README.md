# Zyxel-Local-Toolkit

**Local diagnostics, configuration management and interoperability tool for Zyxel modems and routers**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-blue.svg)](#-usage)
[![Version: v1.0.0](https://img.shields.io/badge/Version-v1.0.0-brightgreen.svg)](https://github.com/iamfahrig/Zyxel-Local-Toolkit/releases)
[![Downloads](https://img.shields.io/github/downloads/iamfahrig/Zyxel-Local-Toolkit/total?label=Downloads&color=blue)](https://github.com/iamfahrig/Zyxel-Local-Toolkit/releases)
[![Hardware](https://img.shields.io/badge/Hardware-Zyxel%20NR%20Series-green.svg)](#-supported-hardware)

> 🌐 **Dil / Language:** &nbsp; [ **Türkçe** ](README_TR.md) &nbsp;•&nbsp; [ **English** ](README.md)

---

## 📌 About

An open-source tool that lets you perform local diagnostics, configuration backup/restore and independent management of **your own** Zyxel device over the local network.

There are no external servers and no telemetry; all traffic goes only to the modem's local IP address. The goal is to support **interoperability** and the **right to repair** on hardware you own.

> ⚠️ **Important:** This tool must only be used on devices **you own**. Using it on a device leased/provided by your ISP may violate your service agreement. All responsibility lies with the user.

---

## 📁 Project Structure

```text
Zyxel-Local-Toolkit/
├── core/                  # Diagnostic & crypto engines (PowerShell & Python)
│   ├── unlock.ps1         # Windows local diagnostic engine (zero dependency)
│   └── unlock.py          # Linux & macOS local diagnostic engine
├── START.bat              # Windows launcher (double-click to run)
├── start.command          # macOS launcher (double-click from Finder)
├── start.sh               # Linux launcher (run from terminal)
├── LICENSE                # MIT License
├── SECURITY.md            # Security policy & responsible disclosure
├── README.md              # English documentation
└── README_TR.md           # Turkish documentation
```

---

## ⚡ Key Features

* `backup.bin` → readable `zcfg_config.json` conversion
* Restore edited JSON back in the device's native format
* AES-256-CBC + RSA-2048 hybrid session (`/UserLogin`), reusing the device's own login flow
* Enables SSH (22), Telnet (23), FTP (21) and Web (80/443) services
* **Access scope choice:** defaults to **LAN only** (safe); **LAN + WAN** can be chosen deliberately
* Routes TR-069, TR-369 and MQTT remote-management endpoints to `127.0.0.1`, disabling external management
* Automatic, timestamped backup before every operation (`yedek_YYYY-MM-DD_HH-mm-ss/`)

---

## ⚙️ How It Works (Technical Summary)

The tool performs nothing hidden; the full flow is:

1. **Authentication:** The device web UI's hybrid encryption flow is reproduced. An RSA-2048 public key is fetched from `/getRSAPublickKey`, a random AES-256 session key is generated, the login payload is AES-CBC encrypted, the AES key is RSA-wrapped and posted to `/UserLogin`. It falls back to plain login if needed. **Your admin password is required.**
2. **Backup:** The encrypted `backup.bin` is downloaded via `/cgi-bin/Backup_Restore?action=Backup`.
3. **Decode:** The ZCFG backup format is decrypted with a 3DES-CBC key derived via OpenSSL `EVP_BytesToKey` and parsed into a JSON object model.
4. **Edit (Mode 1 only):** Relevant fields are updated according to the chosen scope (LAN or LAN+WAN).
5. **Repack & restore:** The JSON is repacked into `.bin` and uploaded via `/cgi-bin/Backup_Restore?action=Restore`.

### What Mode 1 changes in the config

| Field | Change | Purpose |
|:---|:---|:---|
| `X_ZYXEL_LoginCfg` | Opens management pages and diagnostic privileges; sets `root`/`sUser` password equal to admin | Shell/FTP access |
| `X_ZYXEL_RemoteManagement` | Enables SSH/Telnet/FTP/Web for the chosen scope (`Mode=LAN` or `LAN_WAN`) | Local/remote diagnostics |
| `ManagementServer` | Disables TR-069 (CWMP), sets URL to `127.0.0.1:0` | Cut external management |
| `LocalAgent` | Disables TR-369 (USP) subscription/controller services | Cut external telemetry |
| `MQTT` | Disables client, points broker to `127.0.0.1` | Cut external telemetry |

---

<a id="-supported-hardware"></a>
## 📋 Supported Hardware

| Model Family | Example / Tested Models | Architecture | Status |
|:---|:---|:---|:---|
| **NR Indoor Series** | **Zyxel NR5313** (Wi-Fi 7) | ZCFG / 5G Indoor | 🟢&nbsp;**Tested & Verified** |
| **Wi-Fi 7 Series** | NR5307 · NR5331 · NR5731 · NR5333 | ZCFG Common WebAPI | 🔵&nbsp;**Platform Compatible** |
| **NR Indoor Series** | NR5103 · NR5101 · NR5103EV3 · NR5309 | ZCFG Common WebAPI | 🔵&nbsp;**Platform Compatible** |
| **NR Outdoor Series** | NR7101 · NR7102 · NR7103 · NR7301 · NR7501 | ZCFG Common WebAPI | 🟡&nbsp;**Open to Community Testing** |
| **Gateway Series** | VMG3625 · VMG8623 · DX3301 · EX3300 · EX5401 | ZCFG Common WebAPI | 🟡&nbsp;**Open to Community Testing** |

> These models likely share the same software stack. Exact results may vary by firmware version.
> **Open an issue to report tested devices (with firmware version) or to contribute.**

---

## 📥 Download

| Method | Link / Command | Description |
|:---|:---|:---|
| **v1.0.0 Package (ZIP)** | [**Download Zyxel-Local-Toolkit-v1.0.0.zip**](https://github.com/iamfahrig/Zyxel-Local-Toolkit/releases/download/v1.0.0/Zyxel-Local-Toolkit-v1.0.0.zip) | Verified official release |
| **Latest Code (ZIP)** | [**Download Latest ZIP**](https://github.com/iamfahrig/Zyxel-Local-Toolkit/archive/refs/heads/main.zip) | Newest files on `main` |
| **GitHub Releases** | [**Releases Page**](https://github.com/iamfahrig/Zyxel-Local-Toolkit/releases) | Packaged releases & notes |
| **Clone with Git** | `git clone https://github.com/iamfahrig/Zyxel-Local-Toolkit.git` | For developers |

> 🔐 **Integrity check:** The SHA-256 digest of each release package is published on its Releases page. Verify before running:
> `sha256sum Zyxel-Local-Toolkit-v1.0.0.zip` (Linux/macOS) · `certutil -hashfile file.zip SHA256` (Windows)

---

<a id="-usage"></a>
## 🚀 Usage

### 1. Setup
1. Extract the `Zyxel-Local-Toolkit.zip` archive into a folder.
2. Connect your computer to the modem via **Ethernet** or **Wi-Fi**.
3. Have your modem management password ready (printed on the label under the device).

### 2. Run
* **Windows:** double-click **`START.bat`**.
* **macOS:** double-click **`start.command`**.
* **Linux:** run **`./start.sh`** in a terminal.

### 3. Mode Selection

| Mode | What It Does | Duration & Device State |
|:---:|---|:---:|
| **1** | Enables SSH/Telnet/FTP, disables remote management (backs up first) | ~90-120s (device reboots) |
| **2** | Saves current settings as JSON | ~5s (no reboot) |
| **3** | Uploads your edited JSON to the device | ~90-120s (device reboots) |

In Mode 1 the tool also asks for the **access scope**:
* **[1] LAN only (recommended):** services reachable only on the local network. Default and safe.
* **[2] LAN + WAN (risky):** also exposes services to the internet. Choose only if you understand the risk and have a specific need.

Then enter the modem IP (default `192.168.1.1`) and your password. Default login username: **admin**

### 4. After the Operation
* **Mode 1 or 3:** The device reboots. The link takes **90-120 seconds** to settle. Do not unplug during this time.
* **Access after Mode 1 (per chosen scope):**
  * **SSH:** `ssh root@192.168.1.1` (Port: 22, Password: your modem web password)
  * **Web:** `http://192.168.1.1` (User: `admin`)
  * **FTP:** `ftp://192.168.1.1` (Port: 21)
  * **Telnet:** `telnet 192.168.1.1 23`
* **Account roles (after Mode 1):**
  * `admin` → Default privileged web account
  * `root` → Privileged shell (SSH) and FTP account
  * `sUser` → Elevated system account
* **Mode 2:** No reboot. A `yedek_*/zcfg_config.json` file is created.

---

## 🔄 Factory Reset

* **Reset button:** Hold the Reset pinhole on the back for **10-15 seconds**.
* **Web UI:** Maintenance → Reboot → Restore Factory Defaults.
* **From backup:** Restore the first `zcfg_config.json` via Mode 3.

---

## 🔒 Security & Privacy

* All operations stay on the local network; there is no external server communication.
* Mode 1 enables services for **LAN only** by default. WAN exposure happens only on explicit user choice, never silently.
* **⚠️ WAN exposure risk:** If LAN + WAN is selected, SSH/Telnet/FTP are exposed to the internet side. Telnet and FTP are unencrypted; if your modem has a public IP, these services become reachable from outside. Stay on the LAN option unless you genuinely need otherwise.
* **⚠️ Backup files are sensitive:** `backup.bin` and `zcfg_config.json` contain your device configuration including `root`/`sUser` passwords. Do **not** share them or upload them anywhere public (including GitHub). The repo's `.gitignore` excludes these files.
* Your password is held in memory only and is not written to a separate file by the tool.

---

## ⚖️ Legal Framework

This project is research and software work carried out under **interoperability** and the **right to repair** on hardware the user owns:

* **EU Software Directive (2009/24/EC) Article 6** — permits studying and adapting interface information for interoperability.
* **US DMCA § 1201(f)** — grants a reverse-engineering exemption so independently developed software can interoperate.
* **Right to Repair** — supports the user's right to diagnose, configure and maintain hardware they own.
* **Turkish Law on Intellectual and Artistic Works (FSEK) Article 38** — treats obtaining interface information for interoperability as lawful.

> **Copyright & Data Notice:** This repository contains no closed-source firmware binaries, trade secrets or third-party private data. The tool operates locally only on configuration objects obtained from the user's own device on their own local network.

### Disclaimer
This software is provided for **educational, research and interoperability** purposes. The operations may void the manufacturer warranty and may violate your ISP agreement. The user bears full responsibility for any technical, legal or hardware consequences. The tool is not designed for unauthorized access, service disruption or illegal use, and must only be used on devices the user owns.

### Responsible Disclosure
The technical findings were analyzed solely to enable independent management of the device on the local network. For security reports, see [`SECURITY.md`](SECURITY.md).

---

## 🤝 Contributing

Test results, new model compatibility and bug reports are welcome. When opening an issue, include the **device model and firmware version**. Do **not** attach your backup/config files (they contain passwords) to issues or PRs.

---

## 📄 License

Released under the [MIT License](LICENSE).

---

*Last updated: 2026*
