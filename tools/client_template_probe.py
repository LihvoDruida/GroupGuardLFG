#!/usr/bin/env python3
"""Original Forever XML/Lua probe. C rendering/security and frame pools are simulated."""
from pathlib import Path
import argparse
import hashlib
import json
import xml.etree.ElementTree as ET
from functools import reduce
from operator import or_, and_
from lupa.lua51 import LuaRuntime

parser = argparse.ArgumentParser()
parser.add_argument('--client-source', required=True, type=Path)
parser.add_argument('--style', choices=['modern', 'classic'], default='modern')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
manifest = json.loads((root/'tools/client-source-manifest.json').read_text())
hashes = {}
for item in manifest['files']:
    p = args.client_source/item['name']
    digest = hashlib.sha256(p.read_bytes()).hexdigest()
    if digest != item['sha256']:
        parser.error('Original source hash mismatch: '+str(p))
    hashes[item['name']] = digest

def tag(e):
    return e.tag.rsplit('}', 1)[-1]

def spec(e):
    d = {'kind':tag(e), 'attrs':dict(e.attrib), 'keys':[], 'children':[], 'points':[]}
    for child in e:
        t = tag(child)
        if t == 'Size':
            d['width'] = float(child.get('x', '0'))
            d['height'] = float(child.get('y', '0'))
        elif t == 'KeyValues':
            d['keys'] = [dict(v.attrib) for v in child]
        elif t == 'Anchors':
            d['points'] = [dict(v.attrib) for v in child]
        elif t == 'Color':
            d['color'] = dict(child.attrib)
        elif t in ['Frames', 'Layers']:
            children = list(child) if t == 'Frames' else [v for layer in child for v in layer]
            d['children'] += [spec(v) for v in children if tag(v) in ['Frame','EventFrame','Button','Texture','FontString','StatusBar','Slider']]
        elif t == 'Scripts':
            d['scripts'] = {tag(v):dict(v.attrib) for v in child}
    return d

templates = {}
names = ['SharedUIPanelTemplates.xml', 'ScrollBox.xml', 'ScrollTemplates.xml', 'MinimalScrollBar.xml',
         ('Mainline' if args.style == 'modern' else 'Classic')+'-LFGVanilla_Browse.xml']
for name in names:
    for e in ET.parse(args.client_source/name).getroot():
        if e.get('name'):
            templates[e.get('name')] = spec(e)

lua = LuaRuntime()
lua.globals().bit = lua.table_from({'bor':lambda *v:reduce(or_,map(int,v),0),
    'band':lambda *v:reduce(and_,map(int,v),0xffffffff),'bnot':lambda a:(~int(a))&0xffffffff,
    'lshift':lambda a,b:int(a)<<int(b)})
lua.globals().XML_SPECS = lua.table_from(templates, recursive=True)
lua.globals().PROBE_MODERN = args.style == 'modern'
lua.globals().CLIENT_SOURCE = str(args.client_source.resolve())
lua.globals().PROJECT_ROOT = str(root)
compile_only = lua.eval('function(s,n) local f,e=loadstring(s,n); return f~=nil,e end')
for p in root.rglob('*.lua'):
    if 'tools' in p.relative_to(root).parts:
        continue
    ok, error = compile_only(p.read_text(), str(p))
    if not ok:
        raise RuntimeError(f'{p}: {error}')
result = lua.execute('return dofile(...)', str(root/'tools/client_template_probe.lua'))
print(json.dumps({'style':args.style, 'observations':list(result.values()),
    'verified_sources':hashes,'limits':'C widgets, pools, rendering, timing and security are simulated; no historical suite ran.'}, indent=2))
