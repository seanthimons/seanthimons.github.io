import importlib.util
import tempfile
import unittest
from datetime import date
from pathlib import Path
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = REPO_ROOT / "scripts" / "build_manifest.py"


def load_build_manifest_module():
    spec = importlib.util.spec_from_file_location("build_manifest_under_test", SCRIPT_PATH)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class BuildManifestCutoffTests(unittest.TestCase):
    def test_build_manifest_excludes_discovered_weeks_after_as_of_date(self):
        bm = load_build_manifest_module()
        discovered = {
            2025: [],
            2026: [
                "2026-06-02",
                "2026-06-09",
                "2026-06-16",
                "2026-06-23",  # present upstream, but future relative to as_of
            ],
        }
        known_names = {
            "2026-06-02": "European Parenting Leave Policies",
            "2026-06-09": "Films Based on Video Games",
            "2026-06-16": "UK Baby Names",
            "2026-06-23": "Future Week Should Not Be Included",
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            with patch.object(bm, "OUTPUT_PATH", Path(tmpdir) / "week_manifest.json"), \
                 patch.object(bm, "START_DATE", date(2026, 6, 1)), \
                 patch.object(bm, "KNOWN_NAMES", known_names), \
                 patch.object(bm, "discover_weeks_for_year", side_effect=lambda year: discovered.get(year, [])), \
                 patch.object(bm, "fetch_week_metadata", return_value=None), \
                 patch.object(bm, "scan_existing_posts_for_2024_datasets", return_value=set()):
                manifest = bm.build_manifest(as_of=date(2026, 6, 21))

        week_dates = [entry["week_date"] for entry in manifest]
        self.assertEqual(week_dates, ["2026-06-02", "2026-06-09", "2026-06-16"])
        self.assertNotIn("2026-06-23", week_dates)

    def test_build_manifest_covers_discovered_dates_in_range_once_and_sorted(self):
        bm = load_build_manifest_module()
        discovered = {
            2025: [],
            2026: ["2026-06-16", "2026-06-02", "2026-06-09"],
        }
        known_names = {
            "2026-06-02": "European Parenting Leave Policies",
            "2026-06-09": "Films Based on Video Games",
            "2026-06-16": "UK Baby Names",
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            with patch.object(bm, "OUTPUT_PATH", Path(tmpdir) / "week_manifest.json"), \
                 patch.object(bm, "START_DATE", date(2026, 6, 1)), \
                 patch.object(bm, "KNOWN_NAMES", known_names), \
                 patch.object(bm, "discover_weeks_for_year", side_effect=lambda year: discovered.get(year, [])), \
                 patch.object(bm, "fetch_week_metadata", return_value=None), \
                 patch.object(bm, "scan_existing_posts_for_2024_datasets", return_value=set()):
                manifest = bm.build_manifest(as_of=date(2026, 6, 21))

        week_dates = [entry["week_date"] for entry in manifest]
        self.assertEqual(week_dates, sorted(discovered[2026]))
        self.assertEqual(len(week_dates), len(set(week_dates)))


if __name__ == "__main__":
    unittest.main()
