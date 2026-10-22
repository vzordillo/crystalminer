#!/usr/bin/env python3
"""Bake the three checked-in JSON records as dependency-free Lua parity fixtures."""

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAMPLES = ["MgMn4O8-0", "SrTiO3", "CaTiO3"]


def lua(value):
	if isinstance(value, str): return '"' + value.replace('"', '\\"') + '"'
	if isinstance(value, float): return "%.15g" % value
	return str(value)


def main():
	lines = ["-- Generated from data/mpcontribs/*.json for runtime parity tests.", "return {"]
	for sample in SAMPLES:
		with open(os.path.join(ROOT, "data", "mpcontribs", sample + ".json"), encoding="utf-8") as source:
			r = json.load(source)
		lines.append("\t{")
		for key in ("id", "name", "md5"):
			lines.append("\t\t%s = %s," % (key, lua(r[key])))
		l = r["lattice"]
		lines.append("\t\tlattice = { a = %s, b = %s, c = %s, alpha = %s, beta = %s, gamma = %s, matrix = {" %
				  tuple(lua(l[k]) for k in ("a", "b", "c", "alpha", "beta", "gamma")))
		for row in l["matrix"]: lines.append("\t\t\t{%s,%s,%s}," % tuple(lua(v) for v in row))
		lines.append("\t\t} },\n\t\tsites = {")
		for site in r["sites"]:
			sp = site["species"][0]
			lines.append("\t\t\t{ abc = {%s,%s,%s}, species = {{ element = %s, occu = %s }} }," %
					 tuple([lua(v) for v in site["abc"]] + [lua(sp["element"]), lua(sp.get("occu", 1))]))
		lines.append("\t\t},\n\t},")
	lines.append("}")
	os.makedirs(os.path.join(ROOT, "tests", "fixtures"), exist_ok=True)
	with open(os.path.join(ROOT, "tests", "fixtures", "exhibit_records.lua"), "w", encoding="utf-8") as target:
		target.write("\n".join(lines) + "\n")


if __name__ == "__main__": main()
