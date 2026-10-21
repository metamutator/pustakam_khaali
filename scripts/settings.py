#!/usr/bin/env python3
"""Read publishing.yml and print the settings the publish workflow needs.

Usage: python3 scripts/settings.py >> "$GITHUB_OUTPUT"
Prints `name=value` lines. Only simple `key: value` lines are read.
"""
import os
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def read_settings():
    values = {}
    path = ROOT / "publishing.yml"
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            m = re.match(r"^([A-Za-z][\w-]*):\s*(.*?)\s*$", line)
            if m:
                value = m.group(2)
                if value.startswith("#"):
                    value = ""
                value = re.sub(r"\s+#.*$", "", value).strip().strip("'\"")
                values[m.group(1)] = value
    return values


def slug(text):
    s = re.sub(r"[^a-z0-9-]+", "-", text.lower())
    s = re.sub(r"-{2,}", "-", s).strip("-")
    return s[:58].strip("-")


def main():
    s = read_settings()
    repo = os.environ.get("GITHUB_REPOSITORY", "book").split("/")[-1]
    name = slug(s.get("short-name") or repo)
    if not name:
        sys.exit("settings: couldn't work out a short name; set short-name in publishing.yml")
    print(f"name={name}")
    for key in ("domain", "readers-policy"):
        if key in s:
            print(f"{key.replace('-', '_')}={s[key]}")


if __name__ == "__main__":
    main()
