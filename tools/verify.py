#!/usr/bin/env python3
"""Optional portable audit runner: Python 3 + lupa (Lua 5.1 and 5.4).
No dependency is loaded by the addon. Native Lua users can run check_all.sh.
"""
from pathlib import Path
import importlib
import json
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SUITES = (
    'tests.lua', 'tests_extra.lua', 'tests_lfgfilters_forever.lua',
    'tests_lfg_metadata.lua', 'tests_forever_languages.lua',
    'tests_runtime_audit.lua', 'tests_settings_ui.lua',
)


def lua51_globals(blob):
    """Read GETGLOBAL/SETGLOBAL from compiled Lua 5.1 prototypes, incl. closures."""
    assert blob[:6] == b'\x1bLua\x51\x00', 'Lua 5.1 bytecode required'
    endian = 'little' if blob[6] else 'big'
    int_size, size_t, instruction_size, number_size = blob[7:11]
    pos = 12
    reads, writes = set(), set()

    def take(n):
        nonlocal pos
        data = blob[pos:pos+n]
        assert len(data) == n, 'truncated bytecode'
        pos += n
        return data

    def integer(n=int_size):
        return int.from_bytes(take(n), endian)

    def string():
        n = integer(size_t)
        return take(n)[:-1].decode('utf-8', 'replace') if n else None

    def prototype():
        string()
        take(2*int_size + 4)
        code = [integer(instruction_size) for _ in range(integer())]
        constants = []
        for _ in range(integer()):
            tag = integer(1)
            if tag == 0: value = None
            elif tag == 1: value = integer(1)
            elif tag == 3: value = take(number_size)
            elif tag == 4: value = string()
            else: raise ValueError(f'unknown constant tag {tag}')
            constants.append(value)
        for word in code:
            opcode, index = word & 63, word >> 14
            if opcode in (5, 7):
                value = constants[index]
                (reads if opcode == 5 else writes).add(value)
        for _ in range(integer()): prototype()
        take(integer()*int_size)
        for _ in range(integer()): string(); take(2*int_size)
        for _ in range(integer()): string()

    prototype()
    assert pos == len(blob), 'unparsed bytecode'
    return sorted(reads), sorted(writes)


def suite(version, filename):
    os.chdir(ROOT / 'tools')
    runtime = importlib.import_module('lupa.lua' + version).LuaRuntime()
    runtime.execute('dofile(...)', filename)


def main():
    if len(sys.argv) == 4 and sys.argv[1] == '--suite':
        suite(sys.argv[2], sys.argv[3])
        return 0
    failed = False
    for version in ('51', '54'):
        try:
            runtime = importlib.import_module('lupa.lua' + version).LuaRuntime(encoding=None)
        except ImportError:
            print('Install the optional audit dependency: python3 -m pip install lupa')
            return 2
        compile_source = runtime.eval(b'function(s,n) local f,e=(loadstring or load)(s,n);return f~=nil,e end')
        sources = sorted(ROOT.rglob('*.lua'))
        for path in sources:
            ok, err = compile_source(path.read_bytes(), str(path).encode())
            if not ok:
                failed=True; print('SYNTAX FAIL', path.relative_to(ROOT), err)
        print(f'Lua {version[0]}.{version[1]} syntax: {len(sources)} files')
        for filename in SUITES:
            result = subprocess.run([sys.executable, __file__, '--suite', version, filename], capture_output=True, text=True)
            lines = result.stdout.strip().splitlines()
            print(f'Lua {version[0]}.{version[1]} {filename}: {lines[-1] if lines else "no output"}')
            if result.returncode:
                failed=True; print(result.stdout); print(result.stderr)
    for toc in ROOT.glob('*.toc'):
        for entry in toc.read_text().splitlines():
            if entry.strip() and not entry.startswith('#') and not (ROOT / entry.replace('\\', '/')).is_file():
                failed=True; print('MISSING TOC FILE',toc.name,entry)
    runtime = importlib.import_module('lupa.lua51').LuaRuntime(encoding=None)
    dump = runtime.eval(b'function(s,n) return string.dump(assert(loadstring(s,n))) end')
    inventory = {}
    for path in sorted(ROOT.rglob('*.lua')):
        if path.parts[len(ROOT.parts)] == 'tools': continue
        reads, writes = lua51_globals(dump(path.read_bytes(), str(path).encode()))
        leaks = [name for name in writes if not name.startswith('SLASH_')]
        inventory[str(path.relative_to(ROOT))] = {'reads':reads,'writes':writes}
        if leaks:
            failed=True; print('GLOBAL LEAK',path.relative_to(ROOT),leaks)
    (ROOT/'tools'/'api-global-audit.json').write_text(json.dumps(inventory,indent=2,ensure_ascii=False)+'\n')
    print('TOC paths and accidental global writes: ' + ('FAIL' if failed else 'PASS'))
    return int(failed)


if __name__ == '__main__':
    raise SystemExit(main())
