# Changelog

The themes and the tool that builds them. The app's side of the contract is
versioned separately — the payload is `v2` there, and `v3` is drafted here.

## 1.4.0 — the toolchain

The repository grew a build of its own, and the themes moved into it.

- `tools/build.dart` compiles a theme, runs it, validates the payload it
  produces and packages it. A theme that returns nothing, or a colour the app
  cannot parse, fails the build instead of the app.
- `tools/validate.dart`, `tools/inspect.dart`, `tools/install.dart` and
  `tools/export.dart`: validate a payload, print a build's payload and compare
  two builds, install a build into a profile, refresh the golden payloads.
- `lib/validator.dart` mirrors the app's rules one-for-one — the seventeen
  required roles, the ranges it clamps, the enums it falls back on — and
  `lib/v3_validator.dart` does the same for the v3 blocks.
- `schemas/theme.v2.schema.json` freezes the payload the app reads today;
  `schemas/theme.v3.schema.json` drafts what comes next.
- `conformance/` holds the payloads that have to keep working: one golden per
  theme, generated; one broken payload per failure mode, hand-written; and
  the v3 kitchen sink.
- `sdk/palette.ht` derives both schemes from one seed colour;
  `sdk/defaults.ht` holds the neutral palette and a merge.
- `themes/minimal` is the SDK in nine lines. `themes/brand-demo` is the v3
  payload in full, including a slot and a screen.

## 1.3.0 — the balanced Caelestia theme

`caelestia-shell` at 75% surface opacity: the desktop still shows through,
and text stays readable over a bright wallpaper. Published as
`caelestia-shell/plugin.smplug`.

## 1.2.0 — the base Caelestia theme

The published `caelestia` theme, with the transparency opt-in the published
copy never had: with the host's transparency setting on, the compositor shows
through instead of a painted backdrop.

## 1.1.0 — the glassier Caelestia theme

Thinner surfaces than the base theme: more transparency, more blur, a lighter
veil over the shell background.
