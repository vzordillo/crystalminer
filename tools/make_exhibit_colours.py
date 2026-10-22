#!/usr/bin/env python3
"""Generate Jmol-colour atom textures and the exhibit colour table."""

import os
import re
import struct
import zlib


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ELEMENTS = os.path.join(ROOT, "mods", "crystalminer", "exhibit_elements.lua")


def png(path, rgb):
	raw = b"".join(b"\x00" + bytes(rgb + (255,)) * 16 for _ in range(16))

	def chunk(kind, data):
		return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

	with open(path, "wb") as target:
		target.write(b"\x89PNG\r\n\x1a\n")
		target.write(chunk(b"IHDR", struct.pack(">IIBBBBB", 16, 16, 8, 6, 0, 0, 0)))
		target.write(chunk(b"IDAT", zlib.compress(raw, 9)))
		target.write(chunk(b"IEND", b""))


def rgb(value):
	return tuple(int(value[index:index + 2], 16) for index in (1, 3, 5))


def main():
	with open(ELEMENTS, encoding="utf-8") as source:
		jmol = dict(re.findall(r"^\s*([A-Z][a-z]?)\s*=\s*\{ hex = \"(#[0-9A-Fa-f]{6})\",", source.read(), re.MULTILINE))

	texture_dir = os.path.join(ROOT, "mods", "crystalminer", "textures")
	os.makedirs(texture_dir, exist_ok=True)
	for element in sorted(jmol): png(os.path.join(texture_dir, "crystalminer_atom_" + element + ".png"), rgb(jmol[element]))

	output = os.path.join(ROOT, "mods", "crystalminer", "exhibit_colours.lua")
	with open(output, "w", encoding="utf-8") as target:
		target.write("-- Jmol colors. See: http://jmol.sourceforge.net/jscolors/; values from ASE jmol_colors.\n")
		target.write("-- Source: ASE jmol_colors (the standard element-colour convention used by CIF viewers).\nreturn {\n")
		for element in sorted(jmol): target.write("\t%s = \"%s\",\n" % (element, jmol[element]))
		target.write("}\n")


if __name__ == "__main__":
	main()
