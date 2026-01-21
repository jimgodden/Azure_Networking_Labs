#!/usr/bin/env python3
"""
Sends repeated TCP handshakes to a target on port 22, then closes.
Loops every second.

Usage: python3 tcp-handshake-loop.py <target-ip> [port] [interval] [max-tries]
"""

import socket
import sys
import time

target = sys.argv[1] if len(sys.argv) > 1 else None
port = int(sys.argv[2]) if len(sys.argv) > 2 else 22
interval = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0
max_tries = int(sys.argv[4]) if len(sys.argv) > 4 else None

if not target:
    print("Usage: python3 tcp-handshake-loop.py <target-ip> [port] [interval] [max-tries]")
    sys.exit(1)

mode = f"{max_tries} times" if max_tries else "infinite"
print(f"Sending TCP handshakes to {target}:{port} every {interval}s ({mode})")
print("Press Ctrl+C to stop\n")

count = 0
while max_tries is None or count < max_tries:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(5)
        s.connect((target, port))
        s.close()
        count += 1
        print(f"[{count}] Connected to {target}:{port} - OK")
    except Exception as e:
        count += 1
        print(f"[{count}] Failed: {e}")
    time.sleep(interval)
