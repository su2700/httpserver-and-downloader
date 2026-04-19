# GEMINI.md - HTTP Server and Downloader

This document provides context and instructions for AI agents working within this repository.

## Project Overview

**HTTP Server and Downloader** is a specialized utility script designed for penetration testing and Capture The Flag (CTF) environments. Its primary goal is to simplify the process of serving local tools and scripts to a target machine via HTTP.

- **Main Component**: `serve_local.sh` (Bash script)
- **Primary Technology**: Bash, `goshs` (Go-based HTTP server)
- **Target Use Case**: Rapid file transfer from a penetration testing host (e.g., Kali Linux) to a compromised target using common CLI tools (`curl`, `wget`, `certutil`, `PowerShell`).

## Building and Running

### Prerequisites
- **goshs** (Optional): Preferred HTTP server.
  ```bash
  go install github.com/patrickhener/goshs@latest
  ```
- **python3** (Fallback): Used if `goshs` is not found.
- **Network Connection**: Supports `tun0` (default) or any active IPv4 interface.

### Execution
- **Basic run**:
  ```bash
  ./serve_local.sh
  ```
- **With specific interface and port**:
  ```bash
  ./serve_local.sh -i eth0 -p 8080
  ```
- **System-wide command**:
  To run from any directory, create a symlink:
  ```bash
  sudo ln -s /home/noah/Documents/httpserver-and-downloader/serve_local.sh /usr/local/bin/srvl
  ```
- **Privileges**: Running on privileged ports (< 1024) requires root (`sudo`). If run as a normal user on port 80, the script automatically falls back to port 8000.

### Configuration
- **Port**: Can be specified via `-p` or `--port`.
- **Interface**: Can be specified via `-i` or `--interface`. If neither is provided and `tun0` is missing, the script will prompt for an interface.

## Key Files

- `serve_local.sh`: The core logic. It handles IP detection, file selection, OS selection, command generation (with URL encoding), and launching the `goshs` server.
- `README.md`: Comprehensive user documentation including features, installation, and usage examples.

## Development Conventions

- **Bash Standards**: The script uses `set -euo pipefail` for robust error handling.
- **File Handling**: Uses `mapfile` with `find -print0` to safely handle filenames containing spaces or special characters.
- **URL Encoding**: Implements manual URL encoding for spaces (`%20`), hashes (`%23`), and percent signs (`%25`) to ensure compatibility with target machine downloaders.
- **Portability**: Designed to run on Linux hosts commonly used for security research.

## Usage Workflow

1. Navigate to the directory containing the tools you want to serve.
2. Execute `./serve_local.sh`.
3. Select a file from the interactive list.
4. Select the target Operating System (Linux or Windows).
5. Copy the generated download command and execute it on the target machine.
6. The `goshs` server remains running in the foreground until interrupted (Ctrl+C).
