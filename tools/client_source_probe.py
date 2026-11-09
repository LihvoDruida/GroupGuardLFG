#!/usr/bin/env python3
"""Compatibility entry point: run the current native-source contract."""
from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).with_name('forever_source_probe.py')), run_name='__main__')
