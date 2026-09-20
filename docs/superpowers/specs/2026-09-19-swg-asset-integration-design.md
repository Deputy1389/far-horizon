# SWG asset integration design

## Goal

Make Far Horizon consume a curated, local-only catalog of real SWG Restoration
assets while keeping the public repository free of client binaries. The normal
workflow is one local importer run followed by the existing static HTTP server.
When the local client is unavailable, the current procedural materials remain
the deterministic fallback.

## Findings that shape the design

- The Restoration install contains 46 valid v6000 TRE indexes and about 31,000
  DDS paths, including Tatooine, Mos Eisley, concrete, and industrial material
  families.
- Restoration payloads are protected. The client uses its embedded
  `Crypto::TwofishDecryptor` and then zlib for compressed TRE entries. The
  importer must decode this locally instead of assuming that a payload begins
  with `DDS ` or a zlib header.
- The existing prototype already has a DDS browser loader and role-based
  material fallbacks, so the integration should preserve that API and extend
  the manifest format rather than replace the renderer.
- Static SWG mesh conversion has a larger dependency chain (IFF/APT/LOD/POB,
  MSH parsing, material references, and a glTF exporter). This pass will add a
  catalog/diagnostic boundary for meshes and a conversion hook, but texture
  extraction is the completion-critical path.

## Importer architecture

`tools/import_swg_assets.py` will expose small, testable stages:

1. Discover a source root and parse every TRE index.
2. Build a deterministic virtual-path inventory with archive provenance.
3. Search inventory paths by extension and weighted keywords. Role rules score
   path families instead of relying on guessed exact filenames; ties resolve by
   score, path, and archive name.
4. Decode a selected entry from a loose file or TRE. TRE data is read through
   the Restoration Twofish-ECB decryptor when needed, padded to complete blocks,
   then zlib-decoded according to the TOC compression flag.
5. Copy only browser-compatible outputs below `assets/local-swg/` and write a
   manifest containing role, URL, archive, virtual path, size, decoder, and
   alternatives. The output directory remains ignored by Git.
6. Print search and extraction diagnostics, including the exact archive and
   virtual path for every selected role. A low candidate count or decode failure
   is explicit and non-silent.

The importer will support a search-only CLI mode so a local install can be
explored without writing assets. It will also emit a compact inventory JSON
that can be used by a later shader/IFF reference pass.

## Runtime architecture

`src/materials.js` will accept both the existing URL-only manifest entries and
the new provenance-rich objects. Diffuse DDS roles are assigned to terrain,
walls, floors, concrete/roads, metal, and pad/industrial surfaces. Missing,
invalid, or unsupported assets fall back independently to the existing
procedural materials, so one bad local entry cannot remove the playable scene.

## Mesh boundary

The importer will catalog useful `.msh`, `.lod`, `.pob`, and `.apt` paths and
record their archive provenance. A conversion command will accept one selected
mesh and use an installed external converter (when supplied) to produce GLB;
without that dependency it reports the exact missing step. The browser-side
asset catalog is structured so a future converted GLB can be shown without
changing procedural city generation.

## Validation

- Unit-test index parsing, keyword search, deterministic role selection,
  Twofish/zlib decoding, and manifest compatibility with synthetic fixtures.
- Run Python compilation and unit tests.
- Run Node syntax checks for changed browser modules.
- Start the static server and verify the page with the collaborative preview,
  checking the console and the visible material-loading status.
- Confirm `git status` proves no file under `assets/local-swg/` is tracked.
