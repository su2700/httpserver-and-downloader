# HTTP Server and Downloader 🚀

A specialized utility suite for penetration testing and CTF environments, designed to make file transfers as frictionless as possible.

## 🧠 ADHD-Friendly UX
This toolkit is built with a focus on cognitive accessibility:
- **Visual Anchors**: Emojis (🌐, 📁, 📄) help you navigate the flow without getting lost in text.
- **Scannable Output**: High-contrast colors and clear borders make the important parts (commands) pop.
- **Clear Defaults**: No more guessing—prompts explicitly state `[Enter for default]`.
- **Wall-of-Text Prevention**: Extra whitespace and grouped outputs keep your focus where it belongs.

## 🛠️ Main Tools

### 1. `serve_local.py` (Local Server)
The "Host" side. Run this on your machine to serve files to a target.
- **Protocols**: HTTP, SMB (Impacket), FTP (pyftpdlib).
- **Features**: Interface selection, multi-file picking, and automatic command generation for Linux/Windows.
- **Usage**:
  ```bash
  python3 serve_local.py
  ```

### 2. `remote_fetch.py` (Remote Retrieval)
The "Reverse" side. Run this when you need to download a file *from* a target back to your machine.
- **Protocols**: HTTP (Python, PHP, Ruby, Busybox), SMB, FTP, Netcat.
- **Windows Perks**: Includes a **No-Admin** PowerShell one-liner that bypasses native restrictions.
- **Usage**:
  ```bash
  python3 remote_fetch.py
  ```

### 3. `serve_local.sh` (Classic Bash Version)
The original multi-protocol script (HTTP, HTTPS, SMB, FTP, TFTP, WebDAV, DNS). Requires `goshs` for the full experience.
- **Usage**:
  ```bash
  ./serve_local.sh
  ```

## 📦 Requirements
- **Python 3.x** (Standard)
- **Optional (for full features)**:
  - `pip install impacket` (SMB Support)
  - `pip install pyftpdlib` (FTP Support)
  - `goshs` (for `serve_local.sh` HTTPS support)

---
*Created for speed and focus in high-pressure environments.*
