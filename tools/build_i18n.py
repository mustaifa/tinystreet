#!/usr/bin/env python3
"""Writes game/data/i18n/{en,ar}.json from strings_en.py / strings_ar.py.
Usage (from the repo root): python3 tools/build_i18n.py
Fails if a language misses a key or a string's %s count differs from English."""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from strings_en import EN
from strings_ar import AR

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "data", "i18n")
errors = []
for k in EN:
    if k not in AR:
        errors.append("ar missing: " + k)
    elif EN[k].count("%s") != AR[k].count("%s"):
        errors.append("%%s mismatch: " + k)
for k in AR:
    if k not in EN:
        errors.append("ar extra: " + k)
if errors:
    print("\n".join(errors))
    sys.exit(1)
for name, table in (("en", EN), ("ar", AR)):
    with open(os.path.join(root, name + ".json"), "w", encoding="utf-8") as f:
        json.dump(table, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")
print("wrote %d keys per language" % len(EN))
