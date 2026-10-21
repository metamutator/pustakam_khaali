#!/usr/bin/env python3
"""Rewrite the chapter list in _quarto.yml from the files in chapters/.

Chapters are every .md or .qmd file in chapters/, in filename order
(so name them 01-..., 02-..., 10-...). Files whose names start with
"_" or "draft-" are skipped, so you can keep work in progress there.

The list sits between two marker lines in _quarto.yml:
    # >>> chapters (auto) >>>
    # <<< chapters (auto) <<<
Anything outside the markers is left alone. Runs automatically before
every render (see `pre-render` in _quarto.yml) and in the GitHub build.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CONFIG = ROOT / "_quarto.yml"
START = "# >>> chapters (auto) >>>"
END = "# <<< chapters (auto) <<<"


def chapter_files():
    folder = ROOT / "chapters"
    files = [
        p for p in folder.iterdir()
        if p.suffix in (".md", ".qmd")
        and not p.name.startswith(("_", "draft-"))
        and p.name.lower() != "readme.md"
    ] if folder.is_dir() else []
    return sorted(files, key=lambda p: p.name.lower())


def main():
    text = CONFIG.read_text(encoding="utf-8")
    pattern = re.compile(
        r"^([ \t]*)" + re.escape(START) + r"\n.*?^[ \t]*" + re.escape(END),
        re.S | re.M,
    )
    match = pattern.search(text)
    if not match:
        sys.exit(f"list_chapters: markers not found in {CONFIG.name}")
    indent = match.group(1)
    lines = [indent + START]
    for p in chapter_files():
        lines.append(f"{indent}- chapters/{p.name}")
    lines.append(indent + END)
    new = text[: match.start()] + "\n".join(lines) + text[match.end():]
    if new != text:
        CONFIG.write_text(new, encoding="utf-8")
        print(f"list_chapters: {len(lines) - 2} chapter(s) listed")


if __name__ == "__main__":
    main()
