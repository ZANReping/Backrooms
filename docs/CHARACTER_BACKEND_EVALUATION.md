# Character Backend Evaluation

## Decision

Use the project-owned `CharacterAppearance` and `CharacterBackend` boundary. For the first playable implementation, use the native BlendShapes and skeleton in `gd_human_delta_v1/candidate_human.glb` through a small project adapter. Do not enable either upstream plugin and do not serialize their `Resource`, node paths, or class names.

The checked-in model is an **evaluation candidate**, not a commercial-clearance claim. It gives development a real skinned human, eyes, teeth, tongue, shirt, jeans, dress, 188 body/face/expression shapes, and a 66-bone skeleton in one GLB. It intentionally excludes Humanizer, upstream scripts, autoloads, the CC-BY MicroDetail textures, and duplicate source meshes.

## Runnable asset

- Local source: `res://assets/third_party/characters/gd_human_delta_v1/candidate_human.glb`
- Upstream: <https://github.com/Yni-Viar/gd-human-framework>
- Pinned commit: `cf0e05de95ddc2f5a371cb27eb4af72d016566d0` (`v0.2.0`, 2025-12-18)
- Upstream path: `src/addons/gd-human-framework/imported_mesh/body.glb`
- Size: 39,763,524 bytes
- SHA-256: `374A21C5082E0B06186698917DC4FC79A222C04F1AB627E6ADCC37901872FF04`
- License asserted by upstream: CC0-1.0; the exact license text is next to the asset.
- Status: `EVALUATION_CANDIDATE_NOT_COMMERCIAL_CLEARANCE`

Godot 4.7.2 imported and instantiated this exact file headlessly. The root is `body2`. Its `skeleton/Skeleton3D` has 66 bones. The body has 188 BlendShapes; dress 41, shirt 34, jeans 18, and eyes 13. Teeth and tongue are skinned meshes without BlendShapes. The GLB also contains a root-level `123_Dress_mini` mesh, so the adapter should hide or ignore it.

The skeleton bones are:

`hips`, `spine`, `chest`, `chest1`, `breast.L/R`, `neck`, `head`, `jaw`, three tongue bones, upper/lower eyelids, eyes, shoulders, upper arms, forearms, hands, three bones per finger, thighs, buttocks, shins, feet, and toes. Full exact names are in the probe output and use Blender-style `.L`/`.R` suffixes.

### Runtime access contract

The GLB already stores native BlendShapes; the 12 MB `shapes.dat` file and upstream vertex-rebuild code are not required for this candidate. At instantiation:

1. Find the `Skeleton3D` recursively rather than relying on the upstream path.
2. Index each child `MeshInstance3D` by name.
3. For each canonical morph mapping, call `find_blend_shape_by_name()` and then `set_blend_shape_value()` on every compatible mesh.
4. Missing clothing shapes are expected. Skip them and emit a development warning once per mesh/morph pair.
5. Keep canonical values in project-owned save data. Reapply them after spawning or changing clothes.

The canonical mapping is in `morph_mapping.json`. A subsequent mesh-delta calibration mapped eye distance/height, jaw height, chin length/width, cheek size, and brow height. The project adapter currently exposes 12 of the 14 requested face controls; only `eye_size` and `jaw_width` remain intentionally unsupported. The calibrated runtime table is `characters/backends/gd_human_backend.gd`.

The complete ordered list of 188 body BlendShape names is in `body_morph_names.json`. This includes 27 eye targets, 13 jaw targets, 6 cheek targets, 25 nose targets, and 20 lip targets for the creator calibration pass.

The source face BlendShapes contained small residual movement below the face. The project pipeline now removes face-target deltas below Y 1.435 m while preserving the rig and shapes, and records body coverage in `COLOR_0`. The cleaned runtime output is `res://characters/generated/human.glb`; keep the third-party GLB as pinned provenance and regression input.

## MakeHuman CC0 supplemental assets

The official MakeHuman system-assets pack was queried by HTTP range and only the requested files were retained under `res://assets/third_party/characters/makehuman_system_cc0/`. The pack catalog identifies these system assets as CC0. More strongly, each retained OBJ and its companion MHCLO/MHMAT starts with an explicit September 2020 CC0 statement and copyright holders. The binary textures remain beside those text records as license evidence.

Available candidates are a young light-skinned male hm08 body texture, brown eye texture, `short01`, `bob01`, and `ponytail01` hair OBJ/texture pairs, and `shoes01` OBJ/diffuse/normal. The skin and eye images should use the same MakeHuman UV convention as the candidate GLB, but still require visual checking. The OBJ accessories import in Godot 4.7 but are not animated assets: hair needs rigid head-bone attachment, and the shoes need offline skinning from the supplied MakeHuman fit/weight data. Initial geometry measurement suggests MakeHuman-to-GLB alignment near scale `0.1` and Y translation `+0.82 m`; this is a calibration hint rather than a final transform.

## GD-Human-Framework audit

This is the real repository behind the name in the design document. It is a fork of `Lexpartizan/Go_MakeHuman_dot`, not a broadly maintained official framework. The source project declares Godot 4.5 and its README says 4.5 or later. Its complete `src` tree is 332,781,032 bytes. The largest files are a 73.9 MB embedded character scene, 67.8 MB test GLB, 55.5 MB imported body mesh, 50.6 MB body mesh, 39.8 MB body GLB, and 12.0 MB compressed morph data.

The original runtime API is unsuitable as a dependency here:

- It defines `class_name HumanCharacter`, conflicting with the project shell.
- It requires a `CharEditGlobal` autoload.
- It hardcodes `res://addons/gd-human-framework/...` paths.
- `HumanGeneratorCharacter.update_morph()` rebuilds surface vertex arrays in GDScript.
- Clothes are instantiated by hardcoded names and have incomplete morph coverage.

The useful facts are the asset, native BlendShapes, and the data convention. Research source is isolated under `artifacts/character_research/.gdignore` and is never imported by the game.

License caveat: the fork contains a repository-level CC0 dedication and says the base comes from MakeHuman assets. Its maintainer also says they added CC0 because the original author wrote “Public Domain or CC-by-zero.” That is weaker provenance than a per-file asset manifest. The skin shader directory additionally contains MIT code and CC-BY-4.0 MicroDetail textures. None of those shader files or MicroDetail textures were copied into the runnable candidate.

## Configura audit

- Repository: <https://github.com/Team-Figoose/Configura>
- Pinned commit: `0a7b08b74a5a7e684d3242cf3f1140cffed023cb` (2026-08-10)
- Addon license: MIT, copyright 2026 Configura Team
- Plugin version: 1.0
- Source snapshot size: 85,971,663 bytes including examples and README media

Configura has the cleaner general API. `CharacterState` stores values by option ID, `CharacterStateApplier.apply()` reapplies a state, and option resources cover native BlendShapes, bone deformation, mesh swapping, color, atlas, and animation. It is useful as an implementation reference for an adapter and editor tooling.

It is not the selected runtime dependency. It uses global `class_name` types, resource paths under `res://addons/Configura`, synchronous `load()`, and its own state resources. Its bundled characters are Mii/simple/low-poly Audrey examples rather than a production realistic human. The MIT addon license does not by itself provide a suitable final realistic character asset.

## Save and controller adaptation

Save only stable project fields such as canonical morph dictionaries, palette values, and stable wardrobe IDs. Never save BlendShape indices, upstream option resource names as the only key, node paths, `CharacterState`, or scene instances. The current project schema 3 strictly validates its canonical fields; missing supported values use defaults, and the backend skips targets it cannot map. Future canonical-field extensions need an explicit compatibility/migration decision rather than depending on an upstream plugin schema.

The movement controller should only own locomotion and animation parameters. The character shell owns the appearance adapter. Skeleton discovery, mesh lookup, morph application, material duplication, and wardrobe synchronization stay inside the backend. This allows the same player/NPC/controller code to use a future cleared MakeHuman export or a Configura-backed editor without a save migration.

## Validation evidence

- `shapes.dat` decoded successfully in Godot 4.7.2 as six entries: body, forms, shirt, jeans, dress, and eyes.
- The forms catalog contains 46 body, 116 head, and 26 expression entries.
- The candidate GLB imported and instantiated in Godot 4.7.2.
- Exact counts: 66 bones; body 188 shapes; shirt 34; jeans 18; dress 41; eyes 13.
- No upstream plugin was enabled and no background process remains.
