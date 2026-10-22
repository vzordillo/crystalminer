#!/usr/bin/env python3
"""Convert the checked-in MPContribs samples to compact game-grid data."""

import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAMPLES = ["MgMn4O8-0", "SrTiO3", "CaTiO3"]
BLOCK_ANGSTROM = 0.7
ANIONS = {"O", "S", "Se", "Te", "F", "Cl", "Br", "I", "N"}
COVALENT_RADII = {
	"O": 0.66, "Mn": 1.39, "Mg": 1.41, "Ac": 2.15, "Se": 1.20, "S": 1.05,
	"Sr": 1.95, "Ca": 1.76, "Ti": 1.60,
}


def max_fractional_gaps(record):
	lengths = (record["lattice"]["a"], record["lattice"]["b"], record["lattice"]["c"])
	gaps = []
	for axis, length in enumerate(lengths):
		values = sorted(site["abc"][axis] % 1.0 for site in record["sites"])
		largest = max((values[(index + 1) % len(values)] - values[index]) % 1.0
					  for index in range(len(values)))
		gaps.append(largest * length)
	return gaps


def check_bulk(record):
	gaps = max_fractional_gaps(record)
	if max(gaps) > 6.0:
		raise ValueError("record %s has a vacuum gap of %.3f A; only bulk structures are allowed" %
					 (record["id"], max(gaps)))


def rounded_grid(point, minimum):
	return tuple(math.floor((point[axis] - minimum[axis]) / BLOCK_ANGSTROM + 0.5) for axis in range(3))


def line_voxels(start, end):
	steps = max(1, int(math.ceil(max(abs(end[axis] - start[axis]) for axis in range(3)) / 0.5)))
	voxels = set()
	for step in range(steps + 1):
		fraction = step / steps
		voxels.add(tuple(math.floor(start[axis] + (end[axis] - start[axis]) * fraction + 0.5) for axis in range(3)))
	return voxels


def convert(record):
	matrix = record["lattice"]["matrix"]
	points = []
	for site in record["sites"]:
		f1, f2, f3 = (value % 1.0 for value in site["abc"])
		points.append([
			f1 * matrix[0][axis] + f2 * matrix[1][axis] + f3 * matrix[2][axis]
			for axis in range(3)
		])
	minimum = [min(point[axis] for point in points) for axis in range(3)]
	atoms = []
	seen = set()
	for point, site in zip(points, record["sites"]):
		grid = rounded_grid(point, minimum)
		atom = (grid[0], grid[1], grid[2], site["species"][0]["element"])
		if atom[:3] in seen:
			raise ValueError("two atoms share a grid cell in " + record["id"])
		seen.add(atom[:3])
		atoms.append(atom)

	atom_voxels = {atom[:3] for atom in atoms}
	box = [max(atom[axis] for atom in atoms) + 1 for axis in range(3)]
	corners = []
	for f1 in (0, 1):
		for f2 in (0, 1):
			for f3 in (0, 1):
				point = [f1 * matrix[0][axis] + f2 * matrix[1][axis] + f3 * matrix[2][axis]
						for axis in range(3)]
				corners.append(rounded_grid(point, minimum))
	extent_points = list(atom_voxels) + corners
	lo = [min(point[axis] for point in extent_points) for axis in range(3)]
	hi = [max(point[axis] for point in extent_points) for axis in range(3)]

	cell = set()
	edge_pairs = ((0, 1), (0, 2), (0, 4), (1, 3), (1, 5), (2, 3),
				  (2, 6), (3, 7), (4, 5), (4, 6), (5, 7), (6, 7))
	for first, second in edge_pairs:
		cell.update(line_voxels(corners[first], corners[second]))

	def inside(point):
		return all(lo[axis] <= point[axis] <= hi[axis] for axis in range(3))

	bonds = {}
	for metal_point, metal_site in zip(points, record["sites"]):
		metal = metal_site["species"][0]["element"]
		if metal in ANIONS:
			continue
		for anion_point, anion_site in zip(points, record["sites"]):
			anion = anion_site["species"][0]["element"]
			if anion not in ANIONS:
				continue
			bond_limit = 1.25 * (COVALENT_RADII.get(metal, 1.5) + COVALENT_RADII.get(anion, 1.5))
			for s1 in (-1, 0, 1):
				for s2 in (-1, 0, 1):
					for s3 in (-1, 0, 1):
						shift = (s1, s2, s3)
						image = [anion_point[axis] + sum(shift[row] * matrix[row][axis] for row in range(3))
								 for axis in range(3)]
						distance = math.sqrt(sum((image[axis] - metal_point[axis]) ** 2 for axis in range(3)))
						if distance < bond_limit:
							for voxel in line_voxels(rounded_grid(metal_point, minimum), rounded_grid(image, minimum)):
								if inside(voxel) and voxel not in atom_voxels and (voxel not in bonds or metal < bonds[voxel]):
									bonds[voxel] = metal

	cell = {point for point in cell if inside(point) and point not in atom_voxels and point not in bonds}
	return atoms, box, lo, hi, sorted(cell), sorted((x, y, z, metal) for (x, y, z), metal in bonds.items())


def lua_string(value):
	return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def formula(record):
	counts = {}
	order = []
	for site in record["sites"]:
		element = site["species"][0]["element"]
		if element not in counts:
			order.append(element)
		counts[element] = counts.get(element, 0) + 1
	divisor = 0
	for count in counts.values():
		divisor = math.gcd(divisor, count)
	return "".join(element + (str(counts[element] // divisor) if counts[element] // divisor != 1 else "") for element in order)


def main():
	records = []
	for sample in SAMPLES:
		path = os.path.join(ROOT, "data", "mpcontribs", sample + ".json")
		with open(path, encoding="utf-8") as source:
			record = json.load(source)
		check_bulk(record)
		atoms, box, lo, hi, cell, bonds = convert(record)
		records.append((record, atoms, box, lo, hi, cell, bonds))

	out = [
		"-- Baked records fetched from the Materials Project MPContribs API /structures/.",
		"-- The licence of each contribution's project must be confirmed and credited before release; no licence is claimed here.",
		"return {",
	]
	for record, atoms, box, lo, hi, cell, bonds in records:
		lat = record["lattice"]
		out.append("\t{")
		for key in ("id", "name", "md5"):
			out.append("\t\t%s = %s," % (key, lua_string(record[key])))
		out.append("\t\tformula = %s," % lua_string(formula(record)))
		out.append("\t\tlattice = { a = %.12g, b = %.12g, c = %.12g, alpha = %.12g, beta = %.12g, gamma = %.12g }," %
				   tuple(lat[key] for key in ("a", "b", "c", "alpha", "beta", "gamma")))
		out.append("\t\tsites = %d," % len(record["sites"]))
		out.append("\t\tbox = { %d, %d, %d }," % tuple(box))
		out.append("\t\tlo = { %d, %d, %d }," % tuple(lo))
		out.append("\t\thi = { %d, %d, %d }," % tuple(hi))
		out.append("\t\tbond_count = %d," % len(bonds))
		out.append("\t\tatoms = {")
		for x, y, z, element in atoms:
			out.append("\t\t\t{ %d, %d, %d, %s }," % (x, y, z, lua_string(element)))
		out.append("\t\t},")
		out.append("\t\tcell = {")
		for x, y, z in cell:
			out.append("\t\t\t{ %d, %d, %d }," % (x, y, z))
		out.append("\t\t},")
		out.append("\t\tbonds = {")
		for x, y, z, metal in bonds:
			out.append("\t\t\t{ %d, %d, %d, %s }," % (x, y, z, lua_string(metal)))
		out.append("\t\t},")
		out.append("\t},")
	out.append("}")
	output = os.path.join(ROOT, "mods", "crystalminer", "exhibit_data.lua")
	with open(output, "w", encoding="utf-8") as target:
		target.write("\n".join(out) + "\n")


if __name__ == "__main__":
	main()
