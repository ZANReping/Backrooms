# UI Icon Assets

The shared UI uses a small vendored subset of **Lucide Static 1.41.0**, released
from upstream commit `bca7e75a816dcf1e75e8feb5a3198a68cbb8a052`.

- Upstream: https://github.com/lucide-icons/lucide
- Package: https://www.npmjs.com/package/lucide-static/v/1.41.0
- Source SVG location: `icons/<name>.svg` in that release
- License: ISC, with the complete bundled Feather MIT notice retained in
  `assets/ui/icons/lucide/LICENSE`
- Integrity: final vendored files are listed in
  `assets/ui/icons/lucide/SHA256SUMS`
- Package tarball SHA-256:
  `d10f583e2076986ddcf79def168e6ce1e64f742fa06b6014347c59fa581aa6cb`

The only project-side modification is replacing `stroke="currentColor"` with
`stroke="#ffffff"`. Geometry, 24×24 view box, two-pixel stroke, line caps and
line joins remain unchanged. White strokes allow Godot controls to tint icons
through `self_modulate` without separate colored copies.

`UiIcons.tinted_icon()` caches a small runtime color variant for native texture
properties without their own tint (phone search/address `LineEdit.right_icon`).
It preserves the imported source and alpha. Phone button icon colors come from
the phone theme; white home-screen app symbols remain on colored tiles.

Use `UiIcons.icon(&"id")` from `ui/shared/ui_icons.gd`. Canonical IDs match the
SVG filenames. Stable semantic aliases include:

- Apps: `chat`, `maps`, `browser`, `workspace`
- Status: `health`, `stamina`, `thirst`, `hunger`, `sanity`, `fatigue`, `offline`
- Equipment: `head`, `face`, `torso`, `legs`, `feet`, `back`, `primary_hand`,
  `secondary_hand`, `accessory_1`, `accessory_2`

Run `tools/fetch_ui_icons.ps1` from any location to reproduce the subset from
the pinned package version and regenerate the SHA-256 list. Review diffs before
accepting a package version change because upstream geometry may change.

Five equipment symbols in `assets/ui/icons/project/` (head/legs/feet/necklace/ring)
are original project SVG artwork, not modified Lucide drawings. `UiIcons` resolves
those semantic IDs before the Lucide aliases so trousers and shoes remain distinct.
