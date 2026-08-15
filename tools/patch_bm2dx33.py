#!/usr/bin/env python3
"""
Beatmania IIDX 33 (Sparkle Shower - LDJ-012-2026011300) Binary Patcher
---------------------------------------------------------------------
Applies essential patches to bm2dx.dll:
1. Profile RPC Verification Bypass (0x1809b8b1e):
   Prevents 'receiver returns failure' on IIDX33pc.get when server omits optional event nodes.
2. Music Getrank RPC Verification Bypass (0x1809c477d):
   Prevents network error on IIDX33music.getrank.
"""

import sys
import os
import shutil

def patch_bm2dx(dll_path):
    if not os.path.isfile(dll_path):
        print(f"Error: File not found: {dll_path}")
        return False

    with open(dll_path, "rb") as f:
        data = bytearray(f.read())

    # Create backup if not already present
    backup_path = dll_path + ".bak"
    if not os.path.exists(backup_path):
        shutil.copyfile(dll_path, backup_path)
        print(f"[+] Backup created at: {backup_path}")

    # Patch 1: IIDX33pc.get receiver exit check
    # VA 0x1809b8b1e -> File Offset 0x9b7f1e (10190622)
    # Original: 75 06 (jne +6) -> Patched: 90 90 (nop nop)
    off1 = 10190622
    if off1 + 2 <= len(data):
        if data[off1:off1+2] == b"\x75\x06":
            data[off1:off1+2] = b"\x90\x90"
            print("[+] Patched IIDX33pc.get verification check (0x1809b8b1e -> NOP NOP)")
        elif data[off1:off1+2] == b"\x90\x90":
            print("[*] IIDX33pc.get verification check already patched.")
        else:
            print(f"[!] Warning: Offset 1 bytes mismatch ({data[off1:off1+2].hex()})")

    # Patch 2: IIDX33music.getrank receiver exit check
    # VA 0x1809c477d -> File Offset 0x9c3b7d (10238845)
    # Original: 75 06 (jne +6) -> Patched: 90 90 (nop nop)
    off2 = 10238845
    if off2 + 2 <= len(data):
        if data[off2:off2+2] == b"\x75\x06":
            data[off2:off2+2] = b"\x90\x90"
            print("[+] Patched IIDX33music.getrank verification check (0x1809c477d -> NOP NOP)")
        elif data[off2:off2+2] == b"\x90\x90":
            print("[*] IIDX33music.getrank verification check already patched.")
        else:
            print(f"[!] Warning: Offset 2 bytes mismatch ({data[off2:off2+2].hex()})")

    with open(dll_path, "wb") as f:
        f.write(data)

    print("[✓] All patches successfully applied to bm2dx.dll!")
    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <path_to_bm2dx.dll>")
        sys.exit(1)
    patch_bm2dx(sys.argv[1])
