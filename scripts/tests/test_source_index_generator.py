"""Generator rejects unknown packs and reproduces the pinned local research input."""
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
GENERATOR = ROOT / "scripts/research/generate_actions_stuff_source_index.py"
PACK = Path("/Users/tin/Desktop/Game Dev/local_references/Actions Stuff 1.12 (resources).mcpack")
CANONICAL = ROOT / "blender/animation/reviews/player_animation_library_v1/actions_stuff_idle_v001/head_face_audit/source_index.json"


class SourceIndexGeneratorTests(unittest.TestCase):
    def run_generator(self, *args, env=None):
        return subprocess.run([os.sys.executable, str(GENERATOR), *map(str, args)],
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env)

    def test_unknown_pack_checksum_fails_without_output(self):
        with tempfile.TemporaryDirectory() as folder:
            pack = Path(folder) / "unknown.mcpack"
            output = Path(folder) / "source_index.json"
            pack.write_bytes(b"untrusted or wrong version")
            result = self.run_generator("--pack", pack, "--output", output)
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertIn("checksum", result.stderr.lower())
            self.assertFalse(output.exists())

    @unittest.skipUnless(PACK.exists(), "Pinned external proprietary pack is not installed")
    def test_matching_pack_regenerates_exact_bytes_outside_repo(self):
        before = hashlib.sha256(CANONICAL.read_bytes()).hexdigest()
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / "generated.json"
            result = self.run_generator("--pack", PACK, "--output", output)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(hashlib.sha256(output.read_bytes()).hexdigest(), before)
        self.assertEqual(hashlib.sha256(CANONICAL.read_bytes()).hexdigest(), before)

    @unittest.skipUnless(PACK.exists(), "Pinned external proprietary pack is not installed")
    def test_canonical_repo_output_is_refused(self):
        before = hashlib.sha256(CANONICAL.read_bytes()).hexdigest()
        result = self.run_generator("--pack", PACK, "--output", CANONICAL)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("outside", result.stderr.lower())
        self.assertEqual(hashlib.sha256(CANONICAL.read_bytes()).hexdigest(), before)

    @unittest.skipUnless(PACK.exists(), "Pinned external proprietary pack is not installed")
    def test_default_output_uses_external_checksum_cache(self):
        with tempfile.TemporaryDirectory() as folder:
            env = dict(os.environ, XDG_CACHE_HOME=folder)
            result = self.run_generator("--pack", PACK, env=env)
            self.assertEqual(result.returncode, 0, result.stderr)
            outputs = list(Path(folder).rglob("source_index.json"))
            self.assertEqual(len(outputs), 1)
            self.assertIn("9d23264d8fde67a4611f73ecbe044ae1c5cbb4759994a5bef670f7b3fb779e5d", str(outputs[0]))


if __name__ == "__main__":
    unittest.main()
