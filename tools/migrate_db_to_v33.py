#!/usr/bin/env python3
"""
Asphyxia Database Profile Migrator for IIDX 33 (Sparkle Shower)
--------------------------------------------------------------
Duplicates existing profile documents (pc_data, settings, secret, grade, etc.)
from a source version (default: 30 or 31 or 32) to version 33, preserving all
song scores and settings.
"""

import sys
import os
import json
import shutil
import random
import string

def gen_id():
    return "".join(random.choices(string.ascii_letters + string.digits, k=16))

def migrate_db(db_path, src_version=30, target_version=33):
    if not os.path.isfile(db_path):
        print(f"Error: Database not found at: {db_path}")
        return False

    backup_path = db_path + f".bak_v{target_version}"
    if not os.path.exists(backup_path):
        shutil.copyfile(db_path, backup_path)
        print(f"[+] Backup created at: {backup_path}")

    with open(db_path, "r") as f:
        lines = [line.strip() for line in f if line.strip()]

    docs = []
    for line in lines:
        try:
            docs.append(json.loads(line))
        except Exception:
            pass

    existing_target_keys = set()
    for d in docs:
        if d.get("version") == target_version:
            key = (d.get("__refid"), d.get("collection"))
            existing_target_keys.add(key)

    new_docs = []
    for d in docs:
        if d.get("version") == src_version:
            refid = d.get("__refid")
            coll = d.get("collection")
            key = (refid, coll)
            if key not in existing_target_keys:
                cloned = dict(d)
                cloned["_id"] = gen_id()
                cloned["version"] = target_version
                new_docs.append(cloned)
                existing_target_keys.add(key)

    if new_docs:
        docs.extend(new_docs)
        with open(db_path, "w") as f:
            for d in docs:
                f.write(json.dumps(d) + "\n")
        print(f"[✓] Successfully migrated {len(new_docs)} documents to version {target_version}!")
    else:
        print(f"[*] Version {target_version} documents already present in database.")

    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <path_to_iidx@asphyxia.db> [source_version=30] [target_version=33]")
        sys.exit(1)
    db_file = sys.argv[1]
    src_v = int(sys.argv[2]) if len(sys.argv) > 2 else 30
    tgt_v = int(sys.argv[3]) if len(sys.argv) > 3 else 33
    migrate_db(db_file, src_v, tgt_v)
