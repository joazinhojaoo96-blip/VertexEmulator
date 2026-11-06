#!/usr/bin/env python3
"""Apply Vertex identity to the pinned Madeira runtime build tree."""
from __future__ import annotations
import argparse
import plistlib
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MADEIRA = ROOT / "Vendor" / "Madeira"
PROJECT = MADEIRA / "app" / "Madeira.xcodeproj" / "project.pbxproj"
INFO = MADEIRA / "app" / "Madeira" / "Info.plist"
ICON_SOURCE = ROOT / "Vertex" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon1024.png"
ICON_DEST = MADEIRA / "app" / "Madeira" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon-1024.png"
OLD_ID = "MADEIRA_BUNDLE_IDENTIFIER = com.willfaust.madeora;"
NEW_ID = "MADEIRA_BUNDLE_IDENTIFIER = com.vertex.emulator;"

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    for path in (PROJECT, INFO, ICON_SOURCE):
        if not path.is_file():
            raise SystemExit(f"Required branding input is missing: {path}")
    project_text = PROJECT.read_text(encoding="utf-8")
    old_count, new_count = project_text.count(OLD_ID), project_text.count(NEW_ID)
    if (old_count, new_count) not in ((2, 0), (0, 2)):
        raise SystemExit(f"Expected 2 original or 2 Vertex bundle IDs; found {old_count}/{new_count}.")
    with INFO.open("rb") as stream:
        info = plistlib.load(stream)
    if not isinstance(info, dict):
        raise SystemExit("Madeira Info.plist is not a dictionary.")
    info["CFBundleDisplayName"] = "Vertex"
    url_types = info.setdefault("CFBundleURLTypes", [])
    if not isinstance(url_types, list):
        raise SystemExit("CFBundleURLTypes must be an array.")
    if not any(isinstance(item, dict) and "vertex" in item.get("CFBundleURLSchemes", [])
               for item in url_types):
        url_types.append({"CFBundleURLName": "com.vertex.emulator",
                          "CFBundleURLSchemes": ["vertex"]})
    print("Validated: com.vertex.emulator / Vertex / vertex:// / Vertex icon")
    if args.dry_run:
        print("Dry run only; no files changed.")
        return 0
    if old_count:
        PROJECT.write_text(project_text.replace(OLD_ID, NEW_ID), encoding="utf-8")
    with INFO.open("wb") as stream:
        plistlib.dump(info, stream, fmt=plistlib.FMT_XML, sort_keys=False)
    ICON_DEST.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ICON_SOURCE, ICON_DEST)
    print("Applied Vertex identity overlay.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
