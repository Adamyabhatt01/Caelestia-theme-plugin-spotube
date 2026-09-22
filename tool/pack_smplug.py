#!/usr/bin/env python3
"""Pack a plugin directory into the .smplug archive Spotube installs.

Spotube's loader reads exactly two entries out of the zip: `plugin.json`
(the manifest) and `plugin.out` (Hetu bytecode). Entry order is preserved
and paths stay relative, so the archive matches what the app's own bundled
plugins look like.

    python3 tool/pack_smplug.py caelestia
"""

import sys
import zipfile
from pathlib import Path

ENTRIES = ("plugin.json", "plugin.out")


def main(argv):
    if len(argv) != 2:
        print(__doc__.strip(), file=sys.stderr)
        return 64

    plugin_dir = Path(argv[1]).resolve()
    missing = [name for name in ENTRIES if not (plugin_dir / name).is_file()]
    if missing:
        print(f"{plugin_dir}: missing {', '.join(missing)}", file=sys.stderr)
        return 1

    target = plugin_dir / "plugin.smplug"
    # 'w' rather than append: a rebuilt archive must not inherit stale entries.
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for name in ENTRIES:
            archive.write(plugin_dir / name, name)

    print(f"packed {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
