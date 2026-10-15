"""Real temporary Git indexes exercise the optional large-file hook tools."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1]
GUARD = SCRIPTS / "git_large_file_guard.py"
INSTALLER = SCRIPTS / "install_git_hooks.py"
MIB = 1024 * 1024
POINTER = b"version https://git-lfs.github.com/spec/v1\noid sha256:" + b"a" * 64 + b"\nsize 200000000\n"


class GitToolTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.repo = Path(self.temp.name)
        self.git("init", "-q")
        self.git("config", "user.email", "guard-test@example.invalid")
        self.git("config", "user.name", "Guard Test")
        # Tests never invoke user's global hooks or filters.
        self.git("config", "filter.lfs.clean", "cat")
        self.git("config", "filter.lfs.smudge", "cat")
        self.git("config", "filter.lfs.process", "")
        self.git("config", "filter.lfs.required", "false")

    def tearDown(self):
        self.temp.cleanup()

    def git(self, *args, data=None):
        result = subprocess.run(["git", *args], cwd=self.repo, input=data,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
        return result.stdout

    def stage(self, name, data=b"small\n", size=None):
        if size is None:
            oid = self.git("hash-object", "-w", "--stdin", data=data).decode().strip()
        else:
            path = self.repo / "fixture.bin"
            with path.open("wb") as stream:
                stream.truncate(size)
            oid = self.git("hash-object", "-w", str(path)).decode().strip()
            path.unlink()
        self.git("update-index", "--add", "--cacheinfo", f"100644,{oid},{name}")
        return oid

    def attributes(self, text):
        self.stage(".gitattributes", text.encode())

    def run_tool(self, tool=GUARD, *args):
        return subprocess.run([os.sys.executable, str(tool), "--repo", str(self.repo), *args],
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    def test_small_unborn_index_passes(self):
        self.stage("small.txt")
        result = self.run_tool()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_warn_threshold_is_strict_and_reads_staged_blob(self):
        self.stage("exact.bin", size=25 * MIB)
        self.stage("staged big with spaces.bin", size=25 * MIB + 1)
        (self.repo / "staged big with spaces.bin").write_bytes(b"tiny worktree")
        result = self.run_tool()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("WARN", result.stderr)
        self.assertIn("staged big with spaces.bin", result.stderr)
        self.assertNotIn("exact.bin", result.stderr)

    def test_review_above_fifty_is_nonblocking(self):
        self.stage("review.bin", size=50 * MIB + 1)
        result = self.run_tool()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("REVIEW", result.stderr)

    def test_block_above_hundred(self):
        self.stage("blocked.bin", size=100 * MIB + 1)
        result = self.run_tool()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("BLOCK", result.stderr)

    def test_valid_lfs_pointer_uses_staged_filter_and_not_worktree_size(self):
        self.attributes("*.blend filter=lfs diff=lfs merge=lfs -text\n")
        self.stage("large asset.blend", POINTER)
        with (self.repo / "large asset.blend").open("wb") as stream:
            stream.truncate(101 * MIB)
        (self.repo / ".gitattributes").write_text("*.blend -filter\n")
        result = self.run_tool()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_lfs_pointer_without_filter_blocks(self):
        self.stage("raw-pointer.txt", POINTER)
        result = self.run_tool()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("filter=lfs", result.stderr)

    def test_fake_pointer_header_cannot_bypass_lfs_validation(self):
        self.attributes("*.blend filter=lfs\n")
        for malformed in [POINTER + b"payload\n", POINTER.replace(b"a" * 64, b"xyz"),
                          POINTER.replace(b"size 200000000", b"size -3")]:
            with self.subTest(pointer=malformed[-24:]):
                self.stage("bad.blend", malformed)
                result = self.run_tool()
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn("invalid LFS pointer", result.stderr)

    def test_empty_lfs_file_is_allowed(self):
        self.attributes("*.blend filter=lfs\n")
        self.stage("empty.blend", b"")
        self.assertEqual(self.run_tool().returncode, 0)

    def test_unchanged_large_blob_and_deletion_are_skipped(self):
        self.stage("historical.bin", size=101 * MIB)
        self.git("-c", "core.hooksPath=/dev/null", "commit", "-qm", "baseline")
        self.stage("new.txt")
        self.assertEqual(self.run_tool().returncode, 0)
        self.git("update-index", "--force-remove", "historical.bin")
        self.assertEqual(self.run_tool().returncode, 0)

    def test_rename_with_spaces_checks_destination_blob(self):
        oid = self.stage("old asset.bin", size=26 * MIB)
        self.git("-c", "core.hooksPath=/dev/null", "commit", "-qm", "baseline")
        self.git("update-index", "--force-remove", "old asset.bin")
        self.git("update-index", "--add", "--cacheinfo", f"100644,{oid},new asset.bin")
        result = self.run_tool()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("new asset.bin", result.stderr)
        self.assertNotIn("old asset.bin", result.stderr)

    def test_installer_adds_only_precommit_and_is_idempotent(self):
        prepush = self.repo / ".git/hooks/pre-push"
        prepush.write_text("#!/bin/sh\n# existing LFS hook\n")
        config = (self.repo / ".git/config").read_bytes()
        first = self.run_tool(INSTALLER)
        self.assertEqual(first.returncode, 0, first.stderr)
        hook = self.repo / ".git/hooks/pre-commit"
        self.assertTrue(hook.stat().st_mode & 0o111)
        before = hook.read_bytes()
        self.assertEqual(self.run_tool(INSTALLER).returncode, 0)
        self.assertEqual(hook.read_bytes(), before)
        self.assertEqual(prepush.read_text(), "#!/bin/sh\n# existing LFS hook\n")
        self.assertEqual((self.repo / ".git/config").read_bytes(), config)

    def test_installer_refuses_unrelated_hook(self):
        hook = self.repo / ".git/hooks/pre-commit"
        hook.write_text("#!/bin/sh\nexit 19\n")
        result = self.run_tool(INSTALLER)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(hook.read_text(), "#!/bin/sh\nexit 19\n")

    def test_installer_refuses_custom_hookspath(self):
        self.git("config", "core.hooksPath", "custom hooks")
        result = self.run_tool(INSTALLER)
        self.assertEqual(result.returncode, 1)
        self.assertIn("core.hooksPath", result.stderr)
        self.assertFalse((self.repo / "custom hooks").exists())

    def test_installer_dry_run_does_not_write(self):
        result = self.run_tool(INSTALLER, "--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.repo / ".git/hooks/pre-commit").exists())


if __name__ == "__main__":
    unittest.main()
