# Caelestia theme plugin for Spotube

A Spotube theme plugin for the [Caelestia shell](https://github.com/caelestia-dots/shell):
it makes Spotube's colours, glass surfaces and background follow your shell instead
of the app's own palette.

Two variants are in this repository, built from the same Hetu source:

| Plugin | Difference | Install URL |
| --- | --- | --- |
| `caelestia` | Base tuning: 65% surface opacity, 30pt blur, 55% shell background with a `#B3FFFFFF` veil | `https://raw.githubusercontent.com/Adamyabhatt01/Caelestia-theme-plugin-spotube/main/caelestia/plugin.smplug` |
| `caelestia-glassier` | Thinner glass: 55% opacity, 36pt blur, 45% shell background with a lighter `#66FFFFFF` veil | `https://raw.githubusercontent.com/Adamyabhatt01/Caelestia-theme-plugin-spotube/main/caelestia-glassier/plugin.smplug` |

## Requirements

**A Spotube build that supports the `theme` plugin ability — that is this fork
([Adamyabhatt01/spotube](https://github.com/Adamyabhatt01/spotube)), not upstream
release builds.** Upstream has no theme plugin API, so installing an `.smplug` here
there would do nothing.

The shell-sync half needs the [Caelestia shell](https://github.com/caelestia-dots/shell)
itself (Linux). Without it the plugin still works — you just get the static palette.

## Install

1. Spotube → **Settings → Metadata plugins** → paste one of the URLs above → install.
   A local `plugin.smplug` works too (the file picker accepts `.smplug`).
2. **Settings → Metadata plugins → Theme** tab → set it as the default theme.

Re-installing after a version bump replaces the entry, since Spotube identifies a
plugin by **name and author**. If you installed an earlier copy of this theme while it
was still attributed to `Spotube Test`, you will end up with **two** theme entries —
remove the old one.

## What the plugin actually controls

The plugin returns a declarative theme: both colour schemes (17 roles each), glass
`surfaces` (opacity, blur), `background` (source, opacity, blur, veil `overlay`),
`radius`, `density`, and the `dynamic` Material marker.

The split of responsibility matters if you plan to edit these files:

- Colours are **shell-owned at runtime**. Spotube merges the live Caelestia palette over
  whatever this plugin declares, so the hex values in `src/caelestia_theme.ht` are the
  *fallback* used when shell state is unavailable — not what you normally see.
- Everything else is **plugin-owned and never overridden**: a shell cannot change the
  glass or background geometry. That is why the two variants here differ only in
  `surfaces` / `background` numbers, and why changing those is the way to tune the look.
- `"source": "shell"` is the only thing the plugin says about the shell. Which shell
  integration serves it is the host's choice, and the values are clamped to render-safe
  ranges on the way in, so a bad edit can break the theme's appearance but not the app.

## Building

```bash
make deps      # resolves hetu_script, pinned to the version Spotube uses
make compile   # src/caelestia_theme.ht -> plugin.out (Hetu bytecode)
make archive   # plugin.json + plugin.out -> plugin.smplug (zip)
```

`make archive` depends on `compile`, and needs `dart` and `python3` on `PATH`
(`make deps DART=/path/to/dart` if it isn't). The resulting `.smplug` is committed to
this repository so the install URLs above resolve without a GitHub release — rebuild it
whenever you change a source or manifest, or the URLs keep serving the old artifact.

A `.smplug` is a zip holding exactly two entries, `plugin.json` and `plugin.out`. The
bytecode embeds its compile timestamp, so a rebuild of unchanged source differs from the
committed artifact in those bytes and nothing else — check with
`cmp -i 48 <new> <old>` before assuming a rebuild changed behaviour.

## Licence

No licence file is included yet — the source is published for use with Spotube, but
formally redistributing it needs one. Upstream Spotube is BSD-4-Clause.
