#!/usr/bin/env python3
"""Build or import a verified, offline Health handoff using only Python + Git.

This copies committed Git history and explicitly selected documents/artifacts,
never working-tree caches, ignored signing configuration or phone containers.
The recipient must independently verify the delivered ZIP digest before use.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path, PurePosixPath


REPOSITORIES = {
    "saydian-app-global": "https://github.com/tangwu88/saydian-app-global.git",
    "saydian-server-global": "https://github.com/tangwu88/saydianserver.git",
}


def git(repo: Path, *arguments: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo), *arguments], text=True, stderr=subprocess.PIPE
    ).strip()


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        hasher = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(chunk)
        return hasher.hexdigest()


def save_json(path: Path, data: object) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def safe_path(root: Path, name: str) -> Path:
    relative = PurePosixPath(name)
    if (
        not name or "\\" in name or relative.is_absolute()
        or any(part in {"..", "."} for part in name.split("/"))
        or relative.as_posix() != name or ":" in name
    ):
        raise ValueError("Invalid handoff relative path")
    candidate = root.joinpath(*relative.parts)
    if not candidate.resolve().is_relative_to(root.resolve()):
        raise ValueError("Handoff path escapes its root")
    if any(part.is_symlink() for part in [candidate, *candidate.parents] if part != root.parent):
        raise ValueError("Handoff symbolic links are not allowed")
    return candidate


def verify(package: Path) -> dict:
    package = package.resolve()
    if (package / "manifest.json").is_symlink():
        raise ValueError("Handoff symbolic links are not allowed")
    manifest = json.loads((package / "manifest.json").read_text(encoding="utf-8"))
    if not isinstance(manifest, dict) or manifest.get("schemaVersion") != 1 or not isinstance(manifest.get("files"), dict):
        raise ValueError("Unsupported handoff manifest")
    listed = manifest["files"]
    if not listed:
        raise ValueError("Empty handoff manifest")
    for name, expected in listed.items():
        path = safe_path(package, name)
        if not isinstance(expected, str) or not re.fullmatch(r"[a-f0-9]{64}", expected):
            raise ValueError("Invalid file checksum")
        if not path.is_file() or digest(path) != expected:
            raise ValueError(f"File verification failed: {name}")
    actual = set()
    for path in package.rglob("*"):
        if path.is_symlink():
            raise ValueError("Handoff symbolic links are not allowed")
        if path.is_file() and path.relative_to(package).as_posix() != "manifest.json":
            actual.add(path.relative_to(package).as_posix())
    if actual != set(listed):
        raise ValueError("Unlisted or missing handoff files")
    repos = manifest.get("repositories")
    if not isinstance(repos, list) or not repos:
        raise ValueError("Missing handoff repositories")
    names = set()
    for repo in repos:
        if not isinstance(repo, dict):
            raise ValueError("Invalid repository record")
        name = repo.get("name")
        if not isinstance(name, str) or name not in REPOSITORIES or name in names or repo.get("remote") != REPOSITORIES[name]:
            raise ValueError("Invalid or duplicate repository identity")
        names.add(name)
        if not isinstance(repo.get("commit"), str) or not re.fullmatch(r"[a-f0-9]{40}", repo["commit"]):
            raise ValueError("Invalid repository commit")
        branch = repo.get("branch", "")
        if not isinstance(branch, str) or not branch:
            raise ValueError("Invalid repository branch")
        git(package, "check-ref-format", "refs/heads/" + branch)
        bundle_name = f"source/{name}.bundle"
        if repo.get("bundle") != bundle_name or bundle_name not in listed:
            raise ValueError("Repository bundle is not verified")
        heads = git(package, "bundle", "list-heads", str(safe_path(package, bundle_name)))
        if f"{repo['commit']} refs/heads/{branch}" not in heads.splitlines():
            raise ValueError("Bundle ref differs from the recorded commit")
    if names != set(REPOSITORIES):
        raise ValueError("Both App and server repositories are required")
    return manifest


def build(app_repo: Path, server_repo: Path, output: Path, ipa: Path | None = None) -> None:
    if output.exists() or output.is_symlink() or Path(str(output) + ".sha256").exists():
        raise ValueError("Output already exists; original handoffs must be preserved")
    records = []
    for name, repo in [("saydian-app-global", app_repo), ("saydian-server-global", server_repo)]:
        if git(repo, "status", "--porcelain", "--untracked-files=no"):
            raise ValueError(f"Tracked worktree is dirty: {name}")
        for filename in git(repo, "ls-files").splitlines():
            path = PurePosixPath(filename)
            if path.suffix.lower() in {".p12", ".p8", ".key", ".pem", ".jks", ".keystore", ".mobileprovision"}:
                raise ValueError(f"Tracked private signing file blocks packaging: {filename}")
        branch = git(repo, "symbolic-ref", "--short", "HEAD")
        records.append({"name": name, "branch": branch, "commit": git(repo, "rev-parse", "HEAD"),
                        "bundle": f"source/{name}.bundle", "remote": REPOSITORIES[name]})
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="health-handoff-", dir=output.parent) as temporary:
        package = Path(temporary) / output.stem
        (package / "source").mkdir(parents=True)
        for record, repo in zip(records, [app_repo, server_repo]):
            git(repo, "bundle", "create", str(package / record["bundle"]), "refs/heads/" + record["branch"])
            if git(repo, "rev-parse", "HEAD") != record["commit"] or git(repo, "status", "--porcelain", "--untracked-files=no"):
                raise ValueError("Repository changed while creating the handoff")
        (package / "docs").mkdir()
        for source, target in [
            ("docs/CURRENT-HANDOFF.md", "README.md"),
            ("docs/IMPLEMENTATION-LOG-20261005-CLEANUP-HANDOFF.md", "docs/CLEANUP-VERIFICATION.md"),
            ("docs/IMPLEMENTATION-LOG-20261004-IOS-TESTFLIGHT.md", "docs/IOS-1013-VERIFICATION.md"),
            ("docs/CLIENT-CODE-MAP.md", "docs/CLIENT-CODE-MAP.md"),
            ("tool/handoff/portable_handoff.py", "IMPORT.py"),
        ]:
            content = subprocess.check_output(["git", "-C", str(app_repo), "show", f"{records[0]['commit']}:{source}"])
            (package / target).write_bytes(content)
        artifacts = []
        if ipa is not None:
            expected = "14363daa2d17155ba08ba4437b6f624dfa482d4b8aba0575d3243a3c0b094d45"
            if ipa.is_symlink() or digest(ipa) != expected:
                raise ValueError("Only the independently verified 1013 App Store IPA is accepted")
            (package / "artifacts").mkdir()
            artifact = package / "artifacts/SAYDIAN-Health-1.0.1-1013-AppStore.ipa"
            shutil.copyfile(ipa, artifact)
            artifacts.append({"file": artifact.relative_to(package).as_posix(), "version": "1.0.1 (1013)",
                              "role": "previously uploaded App Store artifact; not rebuilt from this tools-only commit"})
        files = {p.relative_to(package).as_posix(): digest(p) for p in sorted(package.rglob("*")) if p.is_file()}
        (package / "SHA256SUMS.txt").write_text(
            "".join(f"{checksum}  {name}\n" for name, checksum in files.items()), encoding="utf-8"
        )
        files["SHA256SUMS.txt"] = digest(package / "SHA256SUMS.txt")
        save_json(package / "manifest.json", {"schemaVersion": 1, "repositories": records, "artifacts": artifacts, "files": files})
        verify(package)
        candidate = Path(temporary) / "candidate.zip"
        with zipfile.ZipFile(candidate, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(package.rglob("*")):
                if path.is_file():
                    archive.write(path, path.relative_to(package.parent).as_posix())
        # Exclusive creation protects even a competing writer's newly created output.
        with output.open("xb") as target, candidate.open("rb") as source:
            shutil.copyfileobj(source, target)
        output.chmod(0o600)
        with Path(str(output) + ".sha256").open("x", encoding="utf-8") as receipt:
            receipt.write(f"{digest(output)}  {output.name}\n")
    print(f"Created and verified: {output}")


def import_package(package: Path, target: Path) -> None:
    manifest = verify(package)
    if target.exists() or target.is_symlink():
        raise ValueError("Import destination already exists; refusing to overwrite")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.mkdir()  # Never reuse an existing checkout, even if empty.
    for repo in manifest["repositories"]:
        destination = target / repo["name"]
        subprocess.run(["git", "clone", "--branch", repo["branch"], str((package / repo["bundle"]).resolve()), str(destination)], check=True)
        if git(destination, "rev-parse", "HEAD") != repo["commit"]:
            raise ValueError("Imported HEAD differs from the verified handoff")
        git(destination, "fsck", "--connectivity-only", "--no-reflogs")
        git(destination, "remote", "set-url", "origin", repo["remote"])
        if git(destination, "status", "--porcelain"):
            raise ValueError("Imported checkout is not clean")
        print(f"Imported {repo['name']}: {repo['commit']}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    builder = commands.add_parser("build")
    for name in ["app-repo", "server-repo", "output"]:
        builder.add_argument("--" + name, type=Path, required=True)
    builder.add_argument("--ipa", type=Path)
    importer = commands.add_parser("import")
    importer.add_argument("target", type=Path)
    importer.add_argument("--package", type=Path, default=Path(__file__).resolve().parent)
    checker = commands.add_parser("verify")
    checker.add_argument("package", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "build":
            build(args.app_repo.resolve(), args.server_repo.resolve(), args.output.absolute(), args.ipa)
        elif args.command == "import":
            import_package(args.package.resolve(), args.target.absolute())
        else:
            verify(args.package)
            print("All handoff files and bundle refs verified")
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Handoff stopped: {type(error).__name__}: {error}\n")


if __name__ == "__main__":
    main()
