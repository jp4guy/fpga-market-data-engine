#!/usr/bin/env python3
"""Lightweight repository consistency checks for the Verilator flow."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAKEFILE = ROOT / "Makefile"

REQUIRED_TARGETS = {
    "test_all",
    "ci",
    "event_parser",
    "event_book",
    "event_book_randomized",
    "event_risk",
    "event_engine",
    "event_engine_risk",
    "event_latency",
    "event_stress",
    "assertions",
}

REQUIRED_DOC_SNIPPETS = {
    "README.md": [
        "make event_parser",
        "make event_book",
        "make event_book_randomized",
        "make event_risk",
        "make event_engine",
        "make event_engine_risk",
        "make event_latency",
        "make event_stress",
        "make ci",
    ],
    "docs/toolchain_setup.md": [
        "make ci",
        "make event_book_randomized",
        "make event_risk",
        "make event_engine_risk",
        "make event_latency",
    ],
    "docs/final_report.md": [
        "event_packet_parser",
        "event_order_book",
        "event_risk_engine",
        "make event_latency",
    ],
    "docs/reference_alignment.md": [
        "FIFO/backpressure",
        "bounded event order book",
        "risk gate",
        "AXI-stream",
    ],
}


def fail(message: str) -> None:
    print(f"FAIL: {message}")
    raise SystemExit(1)


def read_text(path: Path) -> str:
    if not path.exists():
        fail(f"missing required file: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


def make_targets(makefile_text: str) -> set[str]:
    targets: set[str] = set()
    for line in makefile_text.splitlines():
        match = re.match(r"^([A-Za-z0-9_][A-Za-z0-9_-]*):", line)
        if match:
            targets.add(match.group(1))
    return targets


def referenced_repo_files(makefile_text: str) -> set[Path]:
    refs: set[Path] = set()
    for token in re.findall(r"(?:rtl|sim|scripts|docs|filelists)/[A-Za-z0-9_./-]+", makefile_text):
        refs.add(ROOT / token)
    return refs


def check_filelists(makefile_text: str) -> None:
    filelists = sorted(set(re.findall(r"-f\s+(filelists/[A-Za-z0-9_./-]+)", makefile_text)))
    if not filelists:
        fail("Makefile does not reference any Verilator filelists")

    for rel_filelist in filelists:
        filelist_path = ROOT / rel_filelist
        text = read_text(filelist_path)
        missing = []

        for raw_line in text.splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue

            source_path = ROOT / line
            if not source_path.exists():
                missing.append(line)

        if missing:
            fail(f"{rel_filelist} references missing files: {', '.join(missing)}")


def check_makefile() -> None:
    makefile_text = read_text(MAKEFILE)

    targets = make_targets(makefile_text)
    missing_targets = sorted(REQUIRED_TARGETS - targets)
    if missing_targets:
        fail(f"Makefile missing targets: {', '.join(missing_targets)}")

    missing_files = [
        path.relative_to(ROOT).as_posix()
        for path in sorted(referenced_repo_files(makefile_text))
        if not path.exists()
    ]
    if missing_files:
        fail(f"Makefile references missing files: {', '.join(missing_files)}")

    check_filelists(makefile_text)


def check_docs() -> None:
    for rel_path, snippets in REQUIRED_DOC_SNIPPETS.items():
        text = read_text(ROOT / rel_path)
        missing = [snippet for snippet in snippets if snippet not in text]
        if missing:
            fail(f"{rel_path} missing documentation snippets: {', '.join(missing)}")


def check_generated_files_ignored() -> None:
    gitignore = read_text(ROOT / ".gitignore")
    required_ignored = [
        "sim/generated_event_order_book_vectors.txt",
        "__pycache__/",
        "*.pyc",
    ]
    missing = [entry for entry in required_ignored if entry not in gitignore]
    if missing:
        fail(f".gitignore missing generated-file ignores: {', '.join(missing)}")


def main() -> int:
    check_makefile()
    check_docs()
    check_generated_files_ignored()
    print("PASS: repository static checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
