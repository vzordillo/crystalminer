#!/bin/sh
# Regenerates every generated file the crystal exhibits need. The outputs are committed, so a fresh
# clone runs without this script; run it only after changing the inputs, then commit the results:
#   mods/crystalminer/exhibit_data.lua            the baked sample structures (the offline fallback)
#   mods/crystalminer/exhibit_colours.lua         element colours used by the baked samples
#   mods/crystalminer/textures/crystalminer_atom_*.png   one flat Jmol-colour texture per element
#   mods/crystalminer/models/crystalminer_atom.obj       the rounded atom mesh
#   tests/fixtures/exhibit_records.lua            parity fixtures for the unit tests
# Inputs: data/mpcontribs/*.json, mods/crystalminer/exhibit_elements.lua and the tools/make_*.py
# scripts it runs. The output is deterministic: running it again without changing them gives
# byte-identical files.
set -e
cd "$(dirname "$0")/.."
python3 tools/make_exhibit_data.py
python3 tools/make_exhibit_colours.py
python3 tools/make_atoms.py
python3 tools/make_exhibit_fixtures.py
