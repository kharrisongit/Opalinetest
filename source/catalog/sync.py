#!/usr/bin/env python3
"""Keep external app listings in kharrison Apps without copying their code."""
import copy
import json
import re
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
APPS = {
    "com.kharrison.verse": "kharrisongit/Verse",
    "com.kharrison.quill": "kharrisongit/Quill",
}


def release_key(version):
    number = version["version"]
    if not re.fullmatch(r"\d+\.\d+\.\d+", number):
        raise ValueError(f"Unsupported version: {number}")
    build = str(version.get("buildVersion", "0"))
    if not build.isdigit():
        raise ValueError("Invalid build version")
    return (*map(int, number.split(".")), int(build))


def validate_app(feed, bundle, repo):
    matches = [a for a in feed["apps"] if a["bundleIdentifier"] == bundle]
    if len(matches) != 1:
        raise ValueError(f"Expected exactly one {bundle} listing")
    app = matches[0]
    versions = app.get("versions", [])
    if not versions:
        raise ValueError(f"No published versions for {bundle}")
    keys = [release_key(v) for v in versions]
    if len(set(keys)) != len(keys):
        raise ValueError(f"Duplicate versions for {bundle}")
    for v in versions:
        if not v["downloadURL"].startswith(f"https://github.com/{repo}/releases/download/"):
            raise ValueError("Download must belong to the app's release repository")
        if not v["downloadURL"].endswith(".ipa") or type(v["size"]) is not int or v["size"] <= 0:
            raise ValueError("Invalid IPA metadata")
        if not v.get("date"):
            raise ValueError("Missing publication date")
    return app


def merge_app(catalog, feed, bundle, repo):
    incoming = validate_app(feed, bundle, repo)
    result = copy.deepcopy(catalog)
    old = next((a for a in result["apps"] if a["bundleIdentifier"] == bundle), None)
    versions = {release_key(v): v for v in (old or {}).get("versions", [])}
    versions.update({release_key(v): copy.deepcopy(v) for v in incoming["versions"]})
    # A cached upstream response must not replace newer app metadata or remove history.
    latest_incoming = max(map(release_key, incoming["versions"]))
    metadata = incoming if latest_incoming == max(versions) else old
    app = copy.deepcopy(metadata)
    app["versions"] = [versions[k] for k in sorted(versions, reverse=True)]
    latest = app["versions"][0]
    app.update(version=latest["version"], versionDate=latest["date"],
               versionDescription=latest.get("localizedDescription", ""),
               downloadURL=latest["downloadURL"], size=latest["size"])
    if old is None:
        result["apps"].append(app)
    else:
        result["apps"][result["apps"].index(old)] = app
    news = {n["identifier"]: n for n in result.get("news", [])}
    for item in feed.get("news", []):
        if item.get("appID") == bundle:
            existing = news.get(item["identifier"])
            if existing and existing.get("appID") != bundle:
                raise ValueError("News identifier belongs to another app")
            news[item["identifier"]] = copy.deepcopy(item)
    result["news"] = sorted(news.values(), key=lambda n: n.get("date", ""), reverse=True)
    return result


def fetch_feed(repo):
    url = f"https://raw.githubusercontent.com/{repo}/main/source/apps.json"
    request = Request(url, headers={"Cache-Control": "no-cache", "User-Agent": "kharrison-apps-catalog"})
    with urlopen(request, timeout=30) as response:
        data = response.read(4_000_001)
    if len(data) > 4_000_000:
        raise ValueError("Source is too large")
    return json.loads(data)


def verify_download(app):
    latest = max(app["versions"], key=release_key)
    with urlopen(Request(latest["downloadURL"], method="HEAD"), timeout=30) as response:
        if response.status != 200:
            raise ValueError("IPA is not publicly available")
        length = response.headers.get("Content-Length")
        if length is not None and int(length) != latest["size"]:
            raise ValueError("Published IPA size does not match its listing")


def sync(path=ROOT / "source/apps.json"):
    original = path.read_text()
    catalog = json.loads(original)
    for bundle, repo in APPS.items():
        feed = fetch_feed(repo)
        app = validate_app(feed, bundle, repo)
        verify_download(app)
        catalog = merge_app(catalog, feed, bundle, repo)
        print(f"{app['name']}: {max(app['versions'], key=release_key)['version']}")
    updated = json.dumps(catalog, ensure_ascii=False, indent=2) + "\n"
    # Publish nothing unless every feed and download check succeeded.
    if updated != original:
        temporary = path.with_suffix(".json.tmp")
        temporary.write_text(updated)
        temporary.replace(path)
    return updated != original


if __name__ == "__main__":
    sync()
