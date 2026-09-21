# SWG asset integration implementation plan

## Phase 1: tested importer core

1. Add fixtures and tests for v6000 index parsing, keyword/extension search,
   deterministic role scoring, manifest provenance, and encrypted payload
   decoding.
2. Add a small pure-Python Twofish implementation matching the Restoration/SWG
   client’s 128-bit little-endian block decryptor, plus safe block padding and
   zlib handling.
3. Refactor the importer around an inventory of `AssetEntry` records. Add
   `--search`, `--extension`, `--limit`, `--list`, and role-selection output.
4. Replace hardcoded target paths with weighted role rules covering Tatooine
   sand/rock, Mos Eisley/Tatooine walls and floors, concrete, roads, metal,
   vents, and starport/pad surfaces. Preserve deterministic overrides and
   archive/path provenance.

## Phase 2: local output and browser integration

5. Extract selected DDS files through loose or TRE decoding, write a
   provenance-rich manifest, and add an inventory/catalog report. Keep all
   binary output under the ignored local-assets directory.
6. Update the material loader to consume the richer manifest, apply diffuse and
   normal maps where available, and keep per-role procedural fallbacks.
7. Update the README with the exact PowerShell workflow, diagnostics, ignored
   asset policy, and troubleshooting for DDS/browser loading.

## Phase 3: mesh proof boundary

8. Add a small mesh-candidate report and a local static-MSH-to-glTF proof for
   one selected Tatooine industrial object. Keep full `.sht`/`.lod`/`.apt`/`.pob`
   appearance resolution as a documented next boundary without making it block
   texture extraction.

## Phase 4: verification and delivery

9. Run Python tests/compile checks and Node syntax checks.
10. Run the static server, verify the UI with the collaborative preview, and
    capture evidence of the real-asset status/material path.
11. Review the diff for accidental binaries, commit coherent changes, push
    `luna/swg-asset-integration`, open a PR to `main`, and link the PR in the
    collaborative thread.
