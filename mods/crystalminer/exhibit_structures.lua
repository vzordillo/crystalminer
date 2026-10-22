-- Pure conversion of an MPContribs structure into the sparse game grid.

local M = {}

function M.atom_node(element, colours) return colours and colours[element] and element or "grey" end

--- Marker dots at the centres of the baked bond and cell voxels for one model.
function M.dots(record, origin)
	local dots = {}
	local function add(voxel, colour, kind, size)
		dots[#dots + 1] = {
			pos = {
				x = origin.x + voxel[1] - record.lo[1] - 0.5,
				y = origin.y + voxel[3] - record.lo[3] - 0.5,
				z = origin.z + voxel[2] - record.lo[2] - 0.5,
			},
			colour = colour, kind = kind, size = size,
		}
	end
	for _, voxel in ipairs(record.bonds) do add(voxel, "#FFFFFF", "bonds", 1.7) end
	for _, voxel in ipairs(record.cell) do add(voxel, "#FF8C00", "cells", 1.2) end
	return dots
end

--- Largest wrapped fractional-coordinate gap times each lattice-axis length, in Angstroms.
function M.max_fractional_gaps(record)
	local lengths = { record.lattice.a, record.lattice.b, record.lattice.c }
	local gaps = {}
	for axis = 1, 3 do
		local values = {}
		for _, site in ipairs(record.sites) do
			local f = site.abc[axis] - math.floor(site.abc[axis])
			values[#values + 1] = f
		end
		table.sort(values)
		local largest = 0
		for index = 1, #values do
			local next_value = values[index % #values + 1]
			local gap = next_value - values[index]
			if index == #values then gap = gap + 1 end
			largest = math.max(largest, gap)
		end
		gaps[axis] = largest * lengths[axis]
	end
	return gaps
end

function M.is_bulk(record, maximum_gap)
	for _, gap in ipairs(M.max_fractional_gaps(record)) do
		if gap > (maximum_gap or 6) then return false end
	end
	return true
end

local function wrapped(f)
	return f - math.floor(f)
end

--- Returns atoms { x, y, z, element } and the inclusive grid box, or nil on a collision.
function M.convert(record)
	local matrix = record.lattice.matrix
	local cartesian = {}
	local minimum = { math.huge, math.huge, math.huge }
	for _, site in ipairs(record.sites) do
		local f = site.abc
		local wrapped_f = { wrapped(f[1]), wrapped(f[2]), wrapped(f[3]) }
		local p = {}
		for axis = 1, 3 do
			p[axis] = wrapped_f[1] * matrix[1][axis] + wrapped_f[2] * matrix[2][axis] + wrapped_f[3] * matrix[3][axis]
			minimum[axis] = math.min(minimum[axis], p[axis])
		end
		cartesian[#cartesian + 1] = { point = p, element = site.species[1].element }
	end

	local atoms, used, size = {}, {}, { 0, 0, 0 }
	for _, atom in ipairs(cartesian) do
		local g = {}
		for axis = 1, 3 do g[axis] = math.floor((atom.point[axis] - minimum[axis]) / 0.7 + 0.5) end
		local x, y, z = g[1], g[2], g[3]
		local key = x .. ":" .. y .. ":" .. z
		if used[key] then return nil, "two atoms share grid cell " .. key end
		used[key] = true
		atoms[#atoms + 1] = { x, y, z, atom.element }
		size[1], size[2], size[3] = math.max(size[1], x + 1), math.max(size[2], y + 1), math.max(size[3], z + 1)
	end
	return { atoms = atoms, box = size }
end

-- The baked grid is the CIF geometry at one block per 0.7 Angstrom, uniformly for every model.
M.BLOCK_ANGSTROM = 0.7

--- Blocks covered by the inclusive baked extent { lo, hi }.
function M.footprint(record)
	return { record.hi[1] - record.lo[1] + 1, record.hi[2] - record.lo[2] + 1, record.hi[3] - record.lo[3] + 1 }
end

return M
