#!/usr/bin/env python3
"""Reject release packages that could replace Opaline or route shares to it."""
import argparse
import io
from pathlib import Path
import plistlib
import subprocess
import tarfile
import tempfile
import zipfile

BUNDLE_ID = "com.kharrison.utube"


def check_info(info, extension=False):
    expected = BUNDLE_ID + (".OpenIn" if extension else "")
    assert info["CFBundleIdentifier"] == expected, info["CFBundleIdentifier"]
    assert info["CFBundleDisplayName"] == ("Open in uTube" if extension else "uTube")
    if not extension:
        schemes = [scheme for group in info.get("CFBundleURLTypes", [])
                   for scheme in group.get("CFBundleURLSchemes", [])]
        assert schemes == ["utube"], schemes


def check_signature(binary, expected_id):
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "app-binary"
        path.write_bytes(binary)
        entitlements = plistlib.loads(subprocess.check_output(["ldid", "-e", str(path)]))
    assert entitlements["application-identifier"] == "UTUBE00000." + expected_id
    assert entitlements["com.apple.developer.team-identifier"] == "UTUBE00000"
    assert not entitlements.get("keychain-access-groups")
    assert not entitlements.get("com.apple.security.application-groups")


def check_ipa(path, signatures):
    with zipfile.ZipFile(path) as archive:
        assert archive.testzip() is None
        infos = [name for name in archive.namelist() if name.endswith("/Info.plist")]
        main = [name for name in infos if name.count("/") == 2]
        extensions = [name for name in infos if ".appex/Info.plist" in name]
        assert len(main) == len(extensions) == 1
        main_info = plistlib.loads(archive.read(main[0]))
        for name in main + extensions:
            info = plistlib.loads(archive.read(name))
            check_info(info, extension=name in extensions)
            for key in ("CFBundleVersion", "CFBundleShortVersionString"):
                assert info[key] == main_info[key], (name, key)
            if signatures:
                binary = name.rsplit("/", 1)[0] + "/" + info["CFBundleExecutable"]
                check_signature(archive.read(binary), info["CFBundleIdentifier"])
        return main_info


def check_deb(path, main_info):
    data = subprocess.check_output(["ar", "p", str(path), "data.tar.gz"])
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
        names = archive.getnames()
        assert not any("/Applications/Opaline.app" in name for name in names)
        main = [name for name in names if name.endswith("/Applications/uTube.app/Info.plist")]
        assert len(main) == 1
        info = plistlib.loads(archive.extractfile(main[0]).read())
        assert info == main_info
    control = subprocess.check_output(["ar", "p", str(path), "control.tar.gz"])
    with tarfile.open(fileobj=io.BytesIO(control), mode="r:gz") as archive:
        fields = archive.extractfile("./control").read().decode()
        assert "Package: " + BUNDLE_ID + "\n" in fields
        postinst = archive.extractfile("./postinst").read().decode()
        assert "/Applications/uTube.app" in postinst
        assert "/Applications/Opaline.app" not in postinst


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa")
    parser.add_argument("debs", nargs="*")
    parser.add_argument("--check-signatures", action="store_true")
    args = parser.parse_args()
    info = check_ipa(args.ipa, args.check_signatures)
    for deb in args.debs:
        check_deb(deb, info)
    print(f"Standalone uTube identity verified: {info['CFBundleShortVersionString']}, "
          f"build {info['CFBundleVersion']}, {len(args.debs)} deb packages")
