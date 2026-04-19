# Multi-Protocol File Server and Downloader

A versatile bash script to serve files from your current directory over multiple protocols and generate platform-specific download commands for penetration testing and CTF scenarios.

## Features

- 🚀 **Multi-Protocol Support**: Serves files via **HTTP, HTTPS, SMB, FTP, TFTP, WebDAV, or DNS**.
- 🛠️ **Server Management**:
  - **Auto Port Cleaning**: Automatically detects and kills system services (like Apache or Samba) blocking required ports.
  - **Aggressive Cleanup**: Pressing `Ctrl+C` kills the entire process group, ensuring no orphaned background servers remain.
- 🔍 **Interface Selection**: Prompts for an active network interface from a numbered list (bypassed with `-i`).
- 📋 **Download Commands**: Generates ready-to-use download commands for:
  - **Linux**: curl, wget, smbclient, tftp, cadaver, dnscat2.
  - **Windows CMD**: certutil, curl.exe, bitsadmin, copy, tftp, dnscat2.
  - **Windows PowerShell**: Invoke-WebRequest (with TLS 1.2 support), WebClient.
- 🖥️ **Interactive Interface**: Numbered menus for multi-file selection, target OS, and protocol choice.
- 🔒 **Multi-File Support**: Select multiple files by space/comma-separated numbers or type `all` to select every file in the directory.
- 🔒 **Windows Hardening**: 
  - **Authenticated SMB**: Bypasses guest access policies using `smbuser`/`smbpass`.
  - **TLS 1.2/1.3 Force**: Ensures PowerShell downloads succeed on modern Windows systems.
  - **PowerShell Safe**: Uses `.exe` explicitly to avoid alias conflicts (e.g., `curl.exe`).
- 🔒 **URL Encoding**: Safely handles filenames with spaces, `#`, and `%` characters.

## Prerequisites

The script leverages several common tools. Install them based on the protocols you intend to use:

- **HTTP/HTTPS**: `goshs` (recommended) or `python3` (fallback for HTTP).
- **SMB**: `impacket-smbserver`.
- **FTP**: `vsftpd`.
- **TFTP**: `atftpd`.
- **WebDAV**: `rclone`.
- **DNS**: `dnscat2`.

### One-liner for Debian/Kali:
```bash
sudo apt update && sudo apt install vsftpd atftpd rclone dnscat2 python3-impacket -y
# Optional: Install goshs for the best HTTP/HTTPS experience
go install github.com/patrickhener/goshs@latest
```

## Installation

1. Clone or download the repository:
   ```bash
   git clone <repository-url>
   cd httpserver-and-downloader
   ```

2. Make the script executable:
   ```bash
   chmod +x serve_local.sh
   ```

3. Add it to your system PATH as `srvl` (optional):
   ```bash
   sudo ln -s $(pwd)/serve_local.sh /usr/local/bin/srvl
   ```

## Usage

1. Navigate to the directory containing files you want to serve.
2. Run the script (root recommended for privileged ports like 80, 443, 445):
   ```bash
   sudo ./serve_local.sh
   ```
3. Follow the interactive prompts:
   - **Interface**: Choose which network interface to listen on.
   - **File**: Select the file you wish to download.
   - **OS**: Select the target machine's operating system.
   - **Protocol**: Select the desired protocol (or **Option [8]** for all simultaneously).
4. Copy the generated command and execute it on the target machine.

## Protocol Specifics

### SMB (Windows)
Modern Windows systems block guest access. The script starts the SMB server with credentials:
- **User**: `smbuser`
- **Pass**: `smbpass`
The generated command includes a `net use` step to authenticate automatically.

### HTTPS (PowerShell)
To bypass self-signed certificate warnings and TLS protocol mismatches, the PowerShell command includes:
- `[Net.ServicePointManager]::SecurityProtocol` force to TLS 1.2.
- `ServerCertificateValidationCallback` set to ignore errors.

### WebDAV (Windows)
If you encounter "Path not found" errors, ensure the **WebClient** service is running on the target:
```powershell
net start webclient
```

## Technical Details

### Command-Line Arguments
- `-i` or `--interface`: Specify the network interface to use.
- `-p` or `--port`: Specify the HTTP port to listen on (default: 80).

### Port Configuration
- **HTTP**: 80 (fallback: 8000)
- **HTTPS**: 443 (fallback: 8443)
- **SMB**: 445
- **FTP**: 21
- **TFTP**: 69
- **WebDAV**: 8080
- **DNS**: 53

## Security Considerations

⚠️ **Warning**: This script is designed for penetration testing and CTF environments. Do not use in production or expose to untrusted networks.

- Most servers (except SMB) are unauthenticated.
- All files in the directory are accessible.
- Use only in controlled, authorized environments.

## License

This project is provided as-is for educational and authorized penetration testing purposes only.

## Changelog

### Version 1.8 (Current)
- Added **Multi-File Selection** support. Select multiple files via space/comma-separated numbers or `all`.
- Improved input validation for file selection.

### Version 1.7
- Added **HTTPS**, **WebDAV**, and **DNS** (dnscat2) support.
- Added **SMB Authentication** to bypass modern Windows Guest Access policies.
- Added **Aggressive Cleanup** (Process Group kill) and **Auto Port Pre-cleaning**.
- Improved **PowerShell** download commands with TLS 1.2 and `.exe` safety.
- Replaced automatic `tun0` detection with a mandatory interface selection menu.
