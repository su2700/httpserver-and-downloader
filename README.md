# HTTP Server and Downloader

A simple bash script to serve files from your current directory over HTTP and generate platform-specific download commands for penetration testing and CTF scenarios.

## Features

- 🚀 **Multi-Protocol Servers**: Serves files via HTTP, HTTPS, SMB, FTP, TFTP, WebDAV, or DNS
- 🔍 **Interface Selection**: Prompts for an active network interface from a numbered list (bypassed with `-i`)
- 📋 **Download Commands**: Generates ready-to-use download commands for:
  - Linux (curl, wget, smbclient, tftp, cadaver, dnscat2)
  - Windows CMD (certutil, curl, bitsadmin, copy, tftp, dnscat2)
  - Windows PowerShell (Invoke-WebRequest, WebClient)
- 🖥️ **Interactive Interface**:
  - Select specific files from a numbered list
  - Choose target OS (Linux/Windows) to filter commands
  - Choose server protocol (HTTP, HTTPS, SMB, FTP, TFTP, WebDAV, DNS, or ALL)
- 🔒 **URL Encoding**: Properly handles filenames with spaces, `#`, and `%` characters
- 🛡️ **Smart Port Binding**: Automatically falls back to port 8000/8443 if port 80/443 is requested without root privileges

## Prerequisites

- **goshs** (Optional/Required for HTTPS): A simple HTTP/HTTPS server written in Go
- **python3** (Fallback for HTTP): Used if `goshs` is not found
- **impacket-smbserver** (Optional): SMB server part of Impacket
- **vsftpd** (Optional): FTP daemon for anonymous access
- **atftpd** (Optional): TFTP server
- **rclone** (Optional): Used for WebDAV server (`rclone serve webdav`)
- **dnscat2** (Optional): Used for DNS server and file transfer

Install dependencies (example for Debian/Kali):
```bash
sudo apt install vsftpd atftpd rclone dnscat2 python3-impacket
# Install goshs (recommended)
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

3. Add it to your system PATH as `srvl` (optional but recommended):
   ```bash
   sudo ln -s /home/noah/Documents/httpserver-and-downloader/serve_local.sh /usr/local/bin/srvl
   ```

## Usage

1. Navigate to the directory containing files you want to serve:
   ```bash
   cd /path/to/your/files
   ```

2. Run the script:
   ```bash
   ./serve_local.sh
   ```
   *Or with the system-wide command if you created the symlink:*
   ```bash
   srvl
   ```
   *Or with custom options:*
   ```bash
   ./serve_local.sh -i eth0 -p 8080
   ```

3. The script will:
   - Detect your IP address (or prompt for interface)
   - List files with numbers (e.g., `[1] filename`)
   - Prompt you to select a file by number
   - Prompt you to select the target OS (Linux or Windows)
   - Print download commands for the selected file and OS
   - Start the HTTP server

4. Copy and paste the appropriate download command on the target machine

## Technical Details

### Command-Line Arguments
- `-i` or `--interface`: Specify the network interface to use
- `-p` or `--port`: Specify the port to listen on (default: 80)

### URL Encoding
The script properly URL-encodes filenames with special characters:
- Spaces → `%20`
- Hash (`#`) → `%23`
- Percent (`%`) → `%25`

### Port Configuration
Default port is **80** (requires root/sudo on Linux). If run as a non-root user, it automatically falls back to **8000**.

## Security Considerations

⚠️ **Warning**: This script is designed for penetration testing and CTF environments. Do not use in production or expose to untrusted networks.

- The server serves files without authentication
- All files in the directory are accessible
- Use only in controlled, authorized environments

## License

This project is provided as-is for educational and authorized penetration testing purposes only.

## Changelog

### Version 1.7 (Current)
- Replaced automatic `tun0` detection with a mandatory interface selection menu (unless `-i` is provided).
- Improved transparency for network configuration.

### Version 1.6
- Added HTTPS support using `goshs -s -ss`
- Updated "ALL" option to include 7 protocols (HTTP and HTTPS)
- Added insecure SSL bypass flags for all HTTPS download commands

### Version 1.5
- Added WebDAV support using `rclone`
- Added DNS support using `dnscat2`
- Expanded "ALL" option to include 6 different protocols
- Improved process management and protocol selection logic

### Version 1.4
- Added FTP server support using `vsftpd` (with anonymous access)
- Added TFTP server support using `atftpd`
- Added "ALL" protocol option to start all 4 servers simultaneously
- Added FTP and TFTP download commands for Windows and Linux

### Version 1.3
- Added SMB server support using `impacket-smbserver`
- Added interactive protocol selection (HTTP, SMB, or BOTH)
- Added SMB download commands for Windows (`copy`) and Linux (`smbclient`)
- Improved server management with process trapping for simultaneous servers

### Version 1.2
- Added fallback to `python3 -m http.server`
- Added flexible network interface selection (or interactive prompt)
- Added command-line argument parsing (`-i`, `-p`)
- Added smart port binding with root check
- Added installation instructions for system-wide access as `srvl`
