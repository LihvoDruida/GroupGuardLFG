#!/usr/bin/env python3
"""Fetch the pinned original UI sources outside the addon for source analysis.
No client source is bundled or loaded by the addon. No game/account access.
"""
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import URLError
import argparse
import hashlib
import json
import time

parser = argparse.ArgumentParser()
parser.add_argument("--destination", required=True, type=Path)
args = parser.parse_args()
manifest = json.loads(Path(__file__).with_name("client-source-manifest.json").read_text())
args.destination.mkdir(parents=True, exist_ok=True)
for item in manifest["files"]:
    url = ("https://raw.githubusercontent.com/Gethe/wow-ui-source/"
           + manifest["commit"] + "/" + item["path"])
    target = args.destination / item["name"]
    data = target.read_bytes() if target.is_file() else b""
    if hashlib.sha256(data).hexdigest() != item["sha256"]:
        for attempt in range(3):
            try:
                with urlopen(Request(url, headers={"User-Agent": "GroupGuard-source-audit"}), timeout=30) as response:
                    data = response.read(1024 * 1024)
                break
            except (URLError, TimeoutError) as error:
                if attempt == 2:
                    raise SystemExit("Unable to fetch pinned source " + item["name"] + ": " + str(error)) from error
                time.sleep(attempt + 1)
    if hashlib.sha256(data).hexdigest() != item["sha256"]:
        raise SystemExit("Source checksum mismatch: " + item["name"])
    blob = b"blob " + str(len(data)).encode() + b"\0" + data
    if hashlib.sha1(blob).hexdigest() != item["git_blob_sha"]:
        raise SystemExit("Git object mismatch: " + item["name"])
    target.write_bytes(data)
    print(target)
print("Verified original client UI", manifest["client_version"], manifest["commit"])
