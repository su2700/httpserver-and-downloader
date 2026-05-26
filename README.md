# srvl (CTF & Pentest File Server)

A collection of specialized utility scripts designed for penetration testing and Capture The Flag (CTF) environments. `srvl` simplifies the process of serving local files to a target machine or fetching files from a remote host via multiple protocols.

## 🚀 Overview

This repository contains three main tools:
1. **`serve_local.sh`**: The original Bash script for serving local files.
2. **`serve_local.py`**: A feature-rich Python port with "ADHD-friendly" UX, expanded protocol support, and better error handling.
3. **`remote_fetch.py`**: A companion tool for the reverse flow (fetching files from a remote target to your local machine).

---

## 🛠️ Features

- **Multi-Protocol Support**: HTTP, HTTPS, SMB, FTP, TFTP, WebDAV, DNS (dnscat2), Netcat, and SCP.
- **Smart Command Generation**: Automatically generates ready-to-use download commands for both **Linux** (`curl`, `wget`) and **Windows** (`certutil`, `PowerShell`, `curl.exe`).
- **Interactive Selection**: Easily select interfaces, files, and target operating systems through a clean CLI interface.
- **Privilege Awareness**: Automatically handles port fallbacks if running as a non-root user (e.g., port 80 → 8000).
- **URL Encoding**: Handles special characters in filenames safely.

---

## 📦 Prerequisites

### Linux (Recommended)
Most features work out-of-the-box with standard tools. For expanded protocol support, consider installing:
- **goshs**: High-performance HTTP/HTTPS server (preferred over Python's built-in server).
- **Impacket**: For SMB server support (`impacket-smbserver`).
- **pyftpdlib**: For FTP server support.
- **rclone**: For WebDAV support.
- **atftpd**: For TFTP support.

```bash
# Example install for goshs
go install github.com/patrickhener/goshs@latest
```

---

## 📖 Usage

### 1. Serving Local Files (`serve_local.sh` / `serve_local.py`)
Use this when you have a tool on your machine (e.g., `linpeas.sh`, `winPEAS.exe`) and need to get it onto a target.

```bash
# Using Bash
./serve_local.sh

# Using Python (recommended for better UX)
python3 serve_local.py
```

**Workflow:**
1. Select your network interface (e.g., `tun0` for VPN, `eth0`).
2. Select the file(s) you want to serve.
3. Select the target OS (Linux or Windows).
4. Select the protocol (HTTP is usually the easiest).
5. **Copy the generated command** and paste it into your shell on the target machine.

### 2. Fetching Remote Files (`remote_fetch.py`)
Use this when you find "loot" on a target machine and want to download it to your local machine.

```bash
python3 remote_fetch.py
```

**Workflow:**
1. Enter the Remote IP and the port you want to use.
2. Enter the full path of the file on the remote machine (e.g., `/etc/shadow` or `C:\Users\Admin\Desktop\flag.txt`).
3. Select the Remote OS.
4. **Step 1**: Run the generated "Serve" command on the **target machine**.
5. **Step 2**: Run the generated "Download" command on **your machine**.

---

## 🔧 Installation / Setup

To run these tools from anywhere, you can create symlinks in your `/usr/local/bin`:

```bash
sudo ln -s "$(pwd)/serve_local.sh" /usr/local/bin/srvl
sudo ln -s "$(pwd)/serve_local.py" /usr/local/bin/srvp
/```

---

## ⚠️ Disclaimer

These tools are intended for authorized security testing and educational purposes only. Always ensure you have permission before using them on any network or system.
