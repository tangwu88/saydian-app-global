"""Local fixture tests: no credentials, phones, network, or production writes."""

import json
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path

import portable_handoff as handoff


class PortableHandoffTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.app = self.repository("app")
        self.server = self.repository("server")
        self.output = self.root / "Health handoff.zip"

    def tearDown(self):
        self.temporary.cleanup()

    def repository(self, name):
        repo = self.root / name
        repo.mkdir()
        subprocess.run(["git", "init", "-q", "-b", "main", str(repo)], check=True)
        handoff.git(repo, "config", "user.name", "Fixture")
        handoff.git(repo, "config", "user.email", "fixture@example.invalid")
        for path in ["docs/CURRENT-HANDOFF.md", "docs/IMPLEMENTATION-LOG-20261005-CLEANUP-HANDOFF.md",
                     "docs/IMPLEMENTATION-LOG-20261004-IOS-TESTFLIGHT.md", "docs/CLIENT-CODE-MAP.md",
                     "tool/handoff/portable_handoff.py"]:
            file = repo / path
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text("fixture\n", encoding="utf-8")
        handoff.git(repo, "add", ".")
        handoff.git(repo, "commit", "-qm", "fixture")
        return repo

    def package(self):
        handoff.build(self.app, self.server, self.output)
        with zipfile.ZipFile(self.output) as archive:
            self.assertIsNone(archive.testzip())
            for name in archive.namelist():
                self.assertFalse(name.startswith("/"))
                self.assertNotIn("..", Path(name).parts)
            archive.extractall(self.root / "unpacked")
        return self.root / "unpacked" / self.output.stem

    def test_offline_round_trip_with_spaces_and_exact_commits(self):
        package = self.package()
        manifest = handoff.verify(package)
        target = self.root / "new machine"
        handoff.import_package(package, target)
        for repo in manifest["repositories"]:
            self.assertEqual(repo["commit"], handoff.git(target / repo["name"], "rev-parse", "HEAD"))
            self.assertEqual(repo["remote"], handoff.git(target / repo["name"], "remote", "get-url", "origin"))
        self.assertEqual(handoff.digest(self.output), Path(str(self.output) + ".sha256").read_text().split()[0])

    def test_untracked_private_files_are_not_copied(self):
        (self.app / "private-upload.p12").write_bytes(b"fixture-private-material")
        package = self.package()
        target = self.root / "import"
        handoff.import_package(package, target)
        self.assertFalse((target / "saydian-app-global/private-upload.p12").exists())
        self.assertNotIn("private-upload.p12", json.dumps(handoff.verify(package)))

    def test_dirty_tracked_source_is_refused(self):
        (self.app / "docs/CURRENT-HANDOFF.md").write_text("changed", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "dirty"):
            handoff.build(self.app, self.server, self.output)
        self.assertFalse(self.output.exists())

    def test_existing_output_and_import_destination_are_preserved(self):
        package = self.package()
        original = handoff.digest(self.output)
        with self.assertRaisesRegex(ValueError, "already exists"):
            handoff.build(self.app, self.server, self.output)
        self.assertEqual(original, handoff.digest(self.output))
        target = self.root / "existing"
        target.mkdir()
        (target / "keep.txt").write_text("keep", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "already exists"):
            handoff.import_package(package, target)
        self.assertEqual("keep", (target / "keep.txt").read_text())

    def test_modified_missing_extra_or_symlink_files_are_refused(self):
        package = self.package()
        readme = package / "README.md"
        original = readme.read_bytes()
        readme.write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "verification failed"):
            handoff.verify(package)
        readme.unlink()
        with self.assertRaisesRegex(ValueError, "verification failed"):
            handoff.verify(package)
        readme.write_bytes(original)
        extra = package / "unlisted"
        extra.mkdir()
        (extra / "manifest.json").write_text("{}")
        with self.assertRaisesRegex(ValueError, "Unlisted"):
            handoff.verify(package)
        (extra / "manifest.json").unlink()
        (extra / "link").symlink_to(readme)
        with self.assertRaisesRegex(ValueError, "symbolic"):
            handoff.verify(package)

    def test_manifest_path_escape_and_bundle_ref_mismatch_are_refused(self):
        package = self.package()
        path = package / "manifest.json"
        manifest = handoff.verify(package)
        manifest["files"]["../outside"] = "0" * 64
        handoff.save_json(path, manifest)
        with self.assertRaisesRegex(ValueError, "relative path"):
            handoff.verify(package)
        del manifest["files"]["../outside"]
        manifest["repositories"][0]["commit"] = "1" * 40
        handoff.save_json(path, manifest)
        with self.assertRaisesRegex(ValueError, "recorded commit"):
            handoff.import_package(package, self.root / "not-created")
        self.assertFalse((self.root / "not-created").exists())

    def test_invalid_repository_identities_are_refused(self):
        package = self.package()
        manifest = handoff.verify(package)
        manifest["repositories"][0]["remote"] = "https://example.invalid/other.git"
        handoff.save_json(package / "manifest.json", manifest)
        with self.assertRaisesRegex(ValueError, "identity"):
            handoff.verify(package)

    def test_unverified_ipa_is_not_packaged(self):
        ipa = self.root / "unknown.ipa"
        ipa.write_bytes(b"not-the-approved-artifact")
        with self.assertRaisesRegex(ValueError, "1013"):
            handoff.build(self.app, self.server, self.output, ipa)
        self.assertFalse(self.output.exists())

    def test_tracked_signing_file_blocks_packaging(self):
        (self.app / "upload.p12").write_bytes(b"fixture-only")
        handoff.git(self.app, "add", "upload.p12")
        handoff.git(self.app, "commit", "-qm", "fixture signing file")
        with self.assertRaisesRegex(ValueError, "private signing"):
            handoff.build(self.app, self.server, self.output)
        self.assertFalse(self.output.exists())

    def test_malformed_manifest_root_is_refused(self):
        package = self.package()
        (package / "manifest.json").write_text("[]", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Unsupported"):
            handoff.verify(package)

    def test_incomplete_repository_manifest_is_refused(self):
        package = self.package()
        manifest = handoff.verify(package)
        manifest["repositories"].pop()
        handoff.save_json(package / "manifest.json", manifest)
        with self.assertRaisesRegex(ValueError, "Both App and server"):
            handoff.verify(package)

    def test_relative_path_validation(self):
        for value in ["../outside", "/absolute", "a/../b", "a//b", "./a", "a\\b", "C:/data", ""]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                handoff.safe_path(self.root, value)


if __name__ == "__main__":
    unittest.main()
