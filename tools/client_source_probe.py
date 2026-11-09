#!/usr/bin/env python3
"""Run only the new original-client-source probe, never existing test suites.

Supply extracted/mirrored ORIGINAL files externally; copyrighted client sources
are deliberately not bundled. Requires optional lupa, not loaded by the addon.
"""
from pathlib import Path
import argparse
import hashlib
import json
from functools import reduce
from operator import or_, and_
from lupa.lua51 import LuaRuntime

parser = argparse.ArgumentParser()
parser.add_argument("--client-source", required=True, type=Path)
parser.add_argument("--addon-root", type=Path, help="Optional previous release for comparative inspection")
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
names = ["Mixin.lua", "TableUtil.lua", "CallbackRegistry.lua", "DataProvider.lua",
         "TreeListDataProvider.lua", "EnumUtil.lua", "Flags.lua", "ScrollUtil.lua", "Blizzard_LFGVanilla_Browse.lua"]
expected = json.loads((root / "tools/client-source-manifest.json").read_text())
hashes = {entry["name"]: entry["sha256"] for entry in expected["files"]}
manifest = {}
for name in names:
    path = args.client_source / name
    if not path.is_file():
        parser.error(f"missing original client file: {path}")
    manifest[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    if manifest[name] != hashes[name]:
        parser.error(f"source does not match verified client {expected['client_version']}: {path}")
lua = LuaRuntime()
lua.globals().bit = lua.table_from({
    "bor": lambda *values: reduce(or_, map(int,values), 0),
    "band": lambda *values: reduce(and_, map(int,values), 0xffffffff),
    "bnot": lambda a: (~int(a)) & 0xffffffff,
    "lshift": lambda a,b: int(a)<<int(b),
})
lua.globals().CLIENT_SOURCE = str(args.client_source.resolve())
project = args.addon_root.resolve() if args.addon_root else root
lua.globals().PROJECT_ROOT = str(project)
compile_only = lua.eval("function(s,n) local f,e=loadstring(s,n); return f~=nil,e end")
for path in project.rglob("*.lua"):
    if "tools" in path.relative_to(project).parts:
        continue
    ok, error = compile_only(path.read_text(), str(path))
    if not ok:
        raise RuntimeError(f"{path}: {error}")
observations = lua.execute("return dofile(...)", str(root / "tools/client_source_probe.lua"))
print(json.dumps({"original_client_sha256": manifest,
                  "observations": list(observations.values()),
                  "limits": "No real WoW renderer, security engine, server or existing test suite ran."},
                 ensure_ascii=False, indent=2))
