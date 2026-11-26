#!/usr/bin/env python3
"""Rename the project in one go.

Rewrites the values of the project configuration block in CMakeLists.txt (the
single source of truth read by CMake, the justfile, the CI workflows and the
packaging scripts) and then replaces what cannot be derived from it: the old
product name and the old project URL written out in comments and documents.

Only the options that are given change anything. Run it from anywhere:

    just rename --project-name Retrace --product-name "Retrace" \\
        --plugin-name "Retrace Synth" --app-name "Retrace App" \\
        --company "My Company" --bundle-id com.mycompany.retrace \\
        --plugin-code Rtrc --manufacturer-code Myco

Use --dry-run to see what would change. LICENSE is never touched.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CMAKELISTS = ROOT / "CMakeLists.txt"

# The installer id shipped with the template: a renamed product must not keep it.
TEMPLATE_INSTALLER_GUID = "28F190D9-1045-4E2D-B7BC-F7D875542C27"

# Command line option -> CMake variable of the configuration block.
OPTIONS = {
    "project_name": "PROJECT_NAME",
    "product_name": "PRODUCT_NAME",
    "description": "PRODUCT_DESCRIPTION",
    "company": "COMPANY_NAME",
    "bundle_id": "BUNDLE_ID",
    "url": "PRODUCT_URL",
    "email": "PRODUCT_EMAIL",
    "app_name": "APP_PRODUCT_NAME",
    "app_bundle_id": "APP_BUNDLE_ID",
    "plugin_name": "PLUGIN_PRODUCT_NAME",
    "plugin_bundle_id": "PLUGIN_BUNDLE_ID",
    "plugin_description": "PLUGIN_DESCRIPTION",
    "plugin_code": "PLUGIN_CODE",
    "manufacturer_code": "PLUGIN_MANUFACTURER_CODE",
    "aax_native_code": "PLUGIN_AAX_NATIVE_CODE",
    "aax_audiosuite_code": "PLUGIN_AAX_AUDIOSUITE_CODE",
    "installer_guid": "INSTALLER_GUID",
}

FOUR_CHARACTER_CODES = ("PLUGIN_CODE", "PLUGIN_MANUFACTURER_CODE", "PLUGIN_AAX_NATIVE_CODE", "PLUGIN_AAX_AUDIOSUITE_CODE")

# Files that are never rewritten by the text replacement.
SKIPPED_FILES = {"LICENSE", "CMakeLists.txt", "scripts/rename_project.py"}


def setting_pattern(name: str) -> re.Pattern[str]:
    return re.compile(r'^(\s*set\s*\(\s*' + re.escape(name) + r'\s+")([^"]*)(")', re.MULTILINE)


def read_setting(text: str, name: str) -> str:
    match = setting_pattern(name).search(text)
    if match is None:
        sys.exit(f"error: could not read '{name}' from {CMAKELISTS}")
    return match.group(2)


def write_setting(text: str, name: str, value: str) -> str:
    return setting_pattern(name).sub(lambda match: match.group(1) + value + match.group(3), text, count=1)


def tracked_files() -> list[Path]:
    output = subprocess.run(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
                            cwd=ROOT, check=True, capture_output=True).stdout.decode()
    submodules = subprocess.run(["git", "config", "--file", ".gitmodules", "--get-regexp", r"\.path$"],
                                cwd=ROOT, capture_output=True).stdout.decode()
    submodule_paths = [line.split(maxsplit=1)[1] for line in submodules.splitlines() if " " in line]

    files = []
    for name in filter(None, output.split("\0")):
        if name in SKIPPED_FILES or any(name == path or name.startswith(path + "/") for path in submodule_paths):
            continue
        path = ROOT / name
        if path.is_file() and not path.is_symlink():
            files.append(path)
    return files


def validate(values: dict[str, str]) -> None:
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", values["PROJECT_NAME"]):
        sys.exit("error: the project name must start with a letter and hold only letters, digits and underscores")

    for name, value in values.items():
        if not value or '"' in value or "$" in value or "\n" in value:
            sys.exit(f"error: {name} must be a plain, non-empty literal string (no quotes, no $)")

    for name in FOUR_CHARACTER_CODES:
        if len(values[name]) != 4:
            sys.exit(f"error: {name} must be exactly 4 characters, got \"{values[name]}\"")

    for name in ("BUNDLE_ID", "APP_BUNDLE_ID", "PLUGIN_BUNDLE_ID"):
        if not re.fullmatch(r"[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+", values[name]):
            sys.exit(f"error: {name} must be a reverse-domain identifier, got \"{values[name]}\"")

    names = {name: values[name] for name in ("PROJECT_NAME", "APP_PRODUCT_NAME", "PLUGIN_PRODUCT_NAME")}
    if len(set(names.values())) != len(names):
        sys.exit("error: PROJECT_NAME, APP_PRODUCT_NAME and PLUGIN_PRODUCT_NAME must all differ: "
                 "they name a target and two executables of the same build ("
                 + ", ".join(f"{name}=\"{value}\"" for name, value in names.items()) + ")")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--project-name", help="internal name and target prefix, no spaces (PROJECT_NAME)")
    parser.add_argument("--product-name", help="display name of the product, names the installers (PRODUCT_NAME)")
    parser.add_argument("--description", help="product description (PRODUCT_DESCRIPTION)")
    parser.add_argument("--company", help="vendor / author (COMPANY_NAME)")
    parser.add_argument("--bundle-id", help="reverse-domain id; the application and the plugin get <id>.app and "
                                            "<id>.plugin unless given (BUNDLE_ID)")
    parser.add_argument("--url", help="website / support URL (PRODUCT_URL)")
    parser.add_argument("--email", help="contact e-mail (PRODUCT_EMAIL)")
    parser.add_argument("--app-name", help="name of the application executable (APP_PRODUCT_NAME)")
    parser.add_argument("--app-bundle-id", help="reverse-domain id of the application (APP_BUNDLE_ID)")
    parser.add_argument("--plugin-name", help="name of the plugin and of its standalone (PLUGIN_PRODUCT_NAME)")
    parser.add_argument("--plugin-bundle-id", help="reverse-domain id of the plugin (PLUGIN_BUNDLE_ID)")
    parser.add_argument("--plugin-description", help="plugin description (PLUGIN_DESCRIPTION)")
    parser.add_argument("--plugin-code", help="four character plugin id (PLUGIN_CODE)")
    parser.add_argument("--manufacturer-code", help="four character manufacturer id (PLUGIN_MANUFACTURER_CODE)")
    parser.add_argument("--aax-native-code", help="four character AAX native id (PLUGIN_AAX_NATIVE_CODE)")
    parser.add_argument("--aax-audiosuite-code", help="four character AAX AudioSuite id (PLUGIN_AAX_AUDIOSUITE_CODE)")
    parser.add_argument("--installer-guid", help="Windows installer id; a new one is generated while the "
                                                 "template's is still in place (INSTALLER_GUID)")
    parser.add_argument("--dry-run", action="store_true", help="print what would change without writing anything")
    args = parser.parse_args()

    requested = {variable: getattr(args, option) for option, variable in OPTIONS.items()
                 if getattr(args, option) is not None}
    if not requested:
        parser.error("nothing to do: give at least one option")

    cmake_text = CMAKELISTS.read_text(encoding="utf-8")
    old = {variable: read_setting(cmake_text, variable) for variable in OPTIONS.values()}
    new = dict(old)
    new.update(requested)

    if "BUNDLE_ID" in requested:
        if "APP_BUNDLE_ID" not in requested:
            new["APP_BUNDLE_ID"] = new["BUNDLE_ID"] + ".app"
        if "PLUGIN_BUNDLE_ID" not in requested:
            new["PLUGIN_BUNDLE_ID"] = new["BUNDLE_ID"] + ".plugin"

    if "INSTALLER_GUID" not in requested and old["INSTALLER_GUID"].upper() == TEMPLATE_INSTALLER_GUID:
        new["INSTALLER_GUID"] = str(uuid.uuid4()).upper()

    validate(new)

    changed = {variable: value for variable, value in new.items() if value != old[variable]}
    if not changed:
        print("Nothing to change.")
        return

    print(f"{CMAKELISTS.relative_to(ROOT)}:")
    for variable, value in changed.items():
        print(f"  {variable}: \"{old[variable]}\" -> \"{value}\"")
        cmake_text = write_setting(cmake_text, variable, value)

    if not args.dry_run:
        CMAKELISTS.write_text(cmake_text, encoding="utf-8")

    # What is written out literally elsewhere: the product name in comments and
    # documents (also in capitals) and the project URL in the README badges.
    replacements = []
    for variable in ("PRODUCT_NAME", "PRODUCT_URL"):
        if variable in changed:
            replacements.append((old[variable], new[variable]))
    if "PRODUCT_NAME" in changed and old["PRODUCT_NAME"].upper() != old["PRODUCT_NAME"]:
        replacements.append((old["PRODUCT_NAME"].upper(), new["PRODUCT_NAME"].upper()))

    patterns = [(re.compile(r"(?<![\w-])" + re.escape(before) + r"(?![\w-])"), after) for before, after in replacements]

    for path in tracked_files():
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue

        count = 0
        for pattern, after in patterns:
            text, replaced = pattern.subn(lambda _: after, text)
            count += replaced

        if count:
            print(f"{path.relative_to(ROOT)}: {count} replacement{'s' if count != 1 else ''}")
            if not args.dry_run:
                path.write_text(text, encoding="utf-8")

    if args.dry_run:
        print("Dry run: nothing was written.")
    else:
        print("Done. Review the changes with `git diff`, then configure a fresh build folder: "
              "the old one still holds targets with the old names.")


if __name__ == "__main__":
    main()
