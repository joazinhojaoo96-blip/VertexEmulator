#!/usr/bin/env python3
"""Make the pinned DXMT Metal atomic call compatible with the 4-argument API."""
from pathlib import Path
import re
import sys

path = Path("Vendor/Madeira/dxmt/src/airconv/shaders/air_tessellation.metal")
if not path.is_file():
    raise SystemExit(f"DXMT source not found: {path}")
source = path.read_text()
bad = re.compile(
    r"__metal_atomic_fetch_add_explicit\\(\\s*out_count\\s*,\\s*1\\s*,"
    r"\\s*int\\(memory_order_relaxed\\)\\s*,"
    r"\\s*__METAL_MEMORY_SCOPE_THREADGROUP__\\s*,"
    r"\\s*__METAL_MEMORY_FLAGS_NONE__\\s*\\)"
)
fixed, count = bad.subn(
    "__metal_atomic_fetch_add_explicit(out_count, 1, int(memory_order_relaxed), __METAL_MEMORY_SCOPE_THREADGROUP__)",
    source,
)
if count > 1:
    raise SystemExit(f"Refusing unexpected DXMT source: found {count} 5-argument calls")
if count == 1:
    path.write_text(fixed)
    print("Patched DXMT Metal atomic call: removed unsupported fifth argument")
elif "__metal_atomic_fetch_add_explicit(out_count, 1, int(memory_order_relaxed), __METAL_MEMORY_SCOPE_THREADGROUP__)" in source:
    print("DXMT Metal atomic call already uses the supported 4-argument form")
else:
    raise SystemExit("Unknown DXMT atomic API form; stop instead of applying an unsafe patch")
