# HTTP Server and Downloader

A simple bash script to serve files from your current directory over HTTP and generate platform-specific download commands for penetration testing and CTF scenarios.

## Features

- 🚀 **Quick HTTP Server**: Serves files using `goshs` (preferred) or `python3` (fallback)
- 🔍 **Auto-Detection**: Detects `tun0` by default or prompts for an active network interface
- 📋 **Download Commands**: Generates ready-to-use download commands for:
  - Linux (curl, wget)
  - Windows CMD (certutil, curl, bitsadmin)
  - Windows PowerShell (Invoke-WebRequest, WebClient)
- 🖥️ **Interactive Interface**:
  - Select specific files from a numbered list
  - Choose target OS (Linux/Windows) to filter commands
- 🔒 **URL Encoding**: Properly handles filenames with spaces, `#`, and `%` characters
- 🛡️ **Smart Port Binding**: Automatically falls back to port 8000 if port 80 is requested without root privileges

## Prerequisites

- **goshs** (Optional): A simple HTTP server written in Go
  ```bash
  go install github.com/patrickhener/goshs@latest
  ```
- **python3** (Fallback): Used if `goshs` is not found

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

### Version 1.2 (Current)
- Added fallback to `python3 -m http.server`
- Added flexible network interface selection (or interactive prompt)
- Added command-line argument parsing (`-i`, `-p`)
- Added smart port binding with root check
- Added installation instructions for system-wide access as `srvl`
