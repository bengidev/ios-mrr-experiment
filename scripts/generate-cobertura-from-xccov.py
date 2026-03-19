#!/usr/bin/env python3

import json
import os
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path


def usage() -> int:
    print(
        "Usage: generate-cobertura-from-xccov.py <xcresult> <report-json> <output-xml> [target-name] [source-root]",
        file=sys.stderr,
    )
    return 1


def format_rate(numerator: int, denominator: int) -> str:
    if denominator <= 0:
        return "0"
    return f"{numerator / denominator:.4f}"


def indent_xml(element: ET.Element, level: int = 0) -> None:
    indent = "\n" + level * "  "
    if len(element):
        if not element.text or not element.text.strip():
            element.text = indent + "  "
        for child in element:
            indent_xml(child, level + 1)
        if not element[-1].tail or not element[-1].tail.strip():
            element[-1].tail = indent
    elif level and (not element.tail or not element.tail.strip()):
        element.tail = indent


def build_package_name(relative_path: str) -> str:
    directory = os.path.dirname(relative_path)
    if not directory:
        return "."
    return directory.replace(os.sep, ".")


def choose_target(report: dict, requested_name: str) -> dict:
    targets = report.get("targets", [])
    if requested_name:
        for target in targets:
            if target.get("name") == requested_name:
                return target

    for target in targets:
        name = target.get("name", "")
        if name.endswith(".app"):
            return target

    if targets:
        return targets[0]

    raise RuntimeError("No coverage targets found in xccov report JSON.")


def load_archive(result_bundle_path: Path) -> dict:
    command = [
        "xcrun",
        "xccov",
        "view",
        "--archive",
        "--json",
        str(result_bundle_path),
    ]
    completed = subprocess.run(command, capture_output=True, text=True, check=True)
    return json.loads(completed.stdout)


def main() -> int:
    if len(sys.argv) < 4:
        return usage()

    result_bundle_path = Path(sys.argv[1]).resolve()
    report_json_path = Path(sys.argv[2]).resolve()
    output_xml_path = Path(sys.argv[3]).resolve()
    requested_target_name = sys.argv[4] if len(sys.argv) > 4 else ""
    source_root = Path(sys.argv[5]).resolve() if len(sys.argv) > 5 else Path.cwd().resolve()

    report = json.loads(report_json_path.read_text())
    target = choose_target(report, requested_target_name)
    archive = load_archive(result_bundle_path)

    source_root_prefix = str(source_root) + os.sep
    package_entries = {}
    total_lines_covered = 0
    total_lines_valid = 0

    for file_entry in target.get("files", []):
        absolute_path = file_entry.get("path")
        if not absolute_path:
            continue
        if not absolute_path.startswith(source_root_prefix):
            continue

        relative_path = os.path.relpath(absolute_path, source_root)
        if relative_path.startswith(f"ci_artifacts{os.sep}"):
            continue
        if relative_path.startswith(f"MRR ProjectTests{os.sep}"):
            continue

        archive_lines = archive.get(absolute_path)
        if not isinstance(archive_lines, list):
            continue

        executable_lines = []
        for line_entry in archive_lines:
            if not line_entry.get("isExecutable"):
                continue
            line_number = line_entry.get("line")
            execution_count = int(line_entry.get("executionCount", 0))
            if not isinstance(line_number, int):
                continue
            executable_lines.append((line_number, execution_count))

        if not executable_lines:
            continue

        lines_valid = len(executable_lines)
        lines_covered = sum(1 for _, hits in executable_lines if hits > 0)
        total_lines_valid += lines_valid
        total_lines_covered += lines_covered

        package_name = build_package_name(relative_path)
        class_entry = {
            "filename": relative_path,
            "name": os.path.basename(relative_path),
            "line_rate": format_rate(lines_covered, lines_valid),
            "lines": executable_lines,
            "lines_covered": lines_covered,
            "lines_valid": lines_valid,
        }

        package_entries.setdefault(package_name, []).append(class_entry)

    if total_lines_valid == 0:
        raise RuntimeError("No executable repository lines were found for Cobertura export.")

    coverage = ET.Element(
        "coverage",
        {
            "line-rate": format_rate(total_lines_covered, total_lines_valid),
            "branch-rate": "0",
            "lines-covered": str(total_lines_covered),
            "lines-valid": str(total_lines_valid),
            "branches-covered": "0",
            "branches-valid": "0",
            "complexity": "0",
            "version": "xccov-cobertura/1",
            "timestamp": str(int(time.time())),
        },
    )

    sources = ET.SubElement(coverage, "sources")
    source = ET.SubElement(sources, "source")
    source.text = str(source_root)

    packages = ET.SubElement(coverage, "packages")
    for package_name in sorted(package_entries):
        classes_data = sorted(package_entries[package_name], key=lambda item: item["filename"])
        package_lines_valid = sum(item["lines_valid"] for item in classes_data)
        package_lines_covered = sum(item["lines_covered"] for item in classes_data)
        package_element = ET.SubElement(
            packages,
            "package",
            {
                "name": package_name,
                "line-rate": format_rate(package_lines_covered, package_lines_valid),
                "branch-rate": "0",
                "complexity": "0",
            },
        )

        classes = ET.SubElement(package_element, "classes")
        for class_data in classes_data:
            class_element = ET.SubElement(
                classes,
                "class",
                {
                    "name": class_data["name"],
                    "filename": class_data["filename"],
                    "line-rate": class_data["line_rate"],
                    "branch-rate": "0",
                    "complexity": "0",
                },
            )
            ET.SubElement(class_element, "methods")
            lines = ET.SubElement(class_element, "lines")
            for line_number, execution_count in class_data["lines"]:
                ET.SubElement(
                    lines,
                    "line",
                    {
                        "number": str(line_number),
                        "hits": str(execution_count),
                        "branch": "false",
                    },
                )

    indent_xml(coverage)
    output_xml_path.parent.mkdir(parents=True, exist_ok=True)
    output_xml_path.write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!DOCTYPE coverage SYSTEM "http://cobertura.sourceforge.net/xml/coverage-04.dtd">\n'
    )
    with output_xml_path.open("a", encoding="utf-8") as handle:
        ET.ElementTree(coverage).write(handle, encoding="unicode")
        handle.write("\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
