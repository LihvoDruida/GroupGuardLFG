#!/usr/bin/env python3
"""Shared native-source validation entry point for both addon audit runners."""
import argparse
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def run(client_source=None, report_dir=None):
    if importlib.util.find_spec('lupa') is None:
        print('Install CI dependencies: python3 -m pip install -r tools/requirements-ci.txt', file=sys.stderr)
        return 2
    source = client_source or os.environ.get('GROUPGUARD_CLIENT_SOURCE')
    reports = report_dir or os.environ.get('GROUPGUARD_CI_REPORT_DIR')
    with tempfile.TemporaryDirectory(prefix='groupguard-forever-') as temporary:
        temporary = Path(temporary)
        if source:
            source = Path(source).resolve()
            if not source.is_dir():
                print('Client source directory does not exist: ' + str(source), file=sys.stderr)
                return 2
        else:
            source = temporary / 'client'
            result = subprocess.run([sys.executable, str(ROOT/'tools/fetch_client_sources.py'),
                                     '--destination', str(source)])
            if result.returncode:
                return result.returncode
        reports = Path(reports).resolve() if reports else temporary / 'reports'
        failed = False
        for style in ('modern', 'classic'):
            result = subprocess.run([sys.executable, str(ROOT/'tools/forever_source_probe.py'),
                                     '--client-source', str(source), '--style', style,
                                     '--report', str(reports/('forever-'+style+'.json'))])
            if result.returncode:
                failed = True
                print('FAIL Forever source contract: ' + style, file=sys.stderr)
        return int(failed)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--client-source', type=Path, help='Use an existing pinned source cache; all hashes remain mandatory.')
    parser.add_argument('--report-dir', type=Path)
    options = parser.parse_args()
    raise SystemExit(run(options.client_source, options.report_dir))
