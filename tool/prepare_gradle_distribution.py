#!/usr/bin/env python3
"""Keep Flutter's Gradle version while using Gradle's official binary CDN."""
from pathlib import Path
import re
import sys

def change_wrapper(content: str) -> str:
    found = re.search(r"(?m)^distributionUrl=(.*)$", content)
    if found is None:
        raise ValueError("Missing Gradle distributionUrl")
    match = re.search(r"gradle-([0-9][0-9A-Za-z.\-]*)-(?:all|bin)\.zip", found.group(1))
    if match is None:
        raise ValueError("Unknown Gradle distribution; refusing override")
    version = match.group(1)
    replacement = f"distributionUrl=https\\://downloads.gradle.org/distributions/gradle-{version}-bin.zip"
    return content[:found.start()] + replacement + content[found.end():]

def main() -> int:
    path = Path("android/gradle/wrapper/gradle-wrapper.properties")
    if not path.is_file():
        print("Gradle wrapper properties missing", file=sys.stderr)
        return 2
    try:
        original = path.read_text(encoding="utf-8")
        path.write_text(change_wrapper(original), encoding="utf-8")
    except (ValueError, OSError) as exc:
        print(f"Gradle configuration error: {exc}", file=sys.stderr)
        return 2
    print("Gradle configured for official binary distribution.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
