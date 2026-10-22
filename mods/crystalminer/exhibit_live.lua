-- Pure runtime pipeline for live MPContribs crystal exhibits.
-- Loaded with loadfile(...)(element_table).

local elements = ...
local M = {}

M.BLOCK_ANGSTROM = 0.7
M.MAX_SITES = 120
M.MAX_GAP = 6
M.MAX_CELL_HEIGHT = 24
M.MAX_DOTS = 600
M.ANIONS = { O = true, S = true, Se = true, Te = true, F = true, Cl = true, Br = true, I = true, N = true }

local function wrapped(f) return f - math.floor(f) end

local function rounded_grid(point, minimum)
	return {
		math.floor((point[1] - minimum[1]) / M.BLOCK_ANGSTROM + 0.5),
		math.floor((point[2] - minimum[2]) / M.BLOCK_ANGSTROM + 0.5),
		math.floor((point[3] - minimum[3]) / M.BLOCK_ANGSTROM + 0.5),
	}
end

local function key(p) return p[1] .. ":" .. p[2] .. ":" .. p[3] end

local function line_voxels(start, finish)
	local distance = math.max(math.abs(finish[1] - start[1]), math.abs(finish[2] - start[2]), math.abs(finish[3] - start[3]))
	local steps = math.max(1, math.ceil(distance / 0.5))
	local out = {}
	for step = 0, steps do
		local fraction = step / steps
		local p = {
			math.floor(start[1] + (finish[1] - start[1]) * fraction + 0.5),
			math.floor(start[2] + (finish[2] - start[2]) * fraction + 0.5),
			math.floor(start[3] + (finish[3] - start[3]) * fraction + 0.5),
		}
		out[key(p)] = p
	end
	return out
end

local function sorted_voxels(set, with_metal)
	local out = {}
	for _, p in pairs(set) do out[#out + 1] = p end
	table.sort(out, function(a, b)
		for axis = 1, 3 do if a[axis] ~= b[axis] then return a[axis] < b[axis] end end
		return (with_metal and (a[4] or "") or "") < (with_metal and (b[4] or "") or "")
	end)
	return out
end

local function max_fractional_gaps(record)
	local lengths = { record.lattice.a, record.lattice.b, record.lattice.c }
	local gaps = {}
	for axis = 1, 3 do
		local values = {}
		for _, site in ipairs(record.sites) do values[#values + 1] = wrapped(site.abc[axis]) end
		table.sort(values)
		local largest = 0
		for i = 1, #values do
			local next_value = values[i % #values + 1]
			local gap = next_value - values[i]
			if i == #values then gap = gap + 1 end
			largest = math.max(largest, gap)
		end
		gaps[axis] = largest * lengths[axis]
	end
	return gaps
end
M.max_fractional_gaps = max_fractional_gaps

function M.is_bulk(record)
	for _, gap in ipairs(max_fractional_gaps(record)) do if gap > M.MAX_GAP then return false end end
	return true
end

local function cartesian(record)
	local matrix, points, minimum = record.lattice.matrix, {}, { math.huge, math.huge, math.huge }
	for _, site in ipairs(record.sites) do
		local f = { wrapped(site.abc[1]), wrapped(site.abc[2]), wrapped(site.abc[3]) }
		local p = {}
		for axis = 1, 3 do
			p[axis] = f[1] * matrix[1][axis] + f[2] * matrix[2][axis] + f[3] * matrix[3][axis]
			minimum[axis] = math.min(minimum[axis], p[axis])
		end
		points[#points + 1] = p
	end
	return points, minimum
end

function M.convert(record)
	local points, minimum = cartesian(record)
	local atoms, used, size = {}, {}, { 0, 0, 0 }
	for i, point in ipairs(points) do
		local grid = rounded_grid(point, minimum)
		if used[key(grid)] then return nil, "two atoms share grid cell " .. key(grid) end
		used[key(grid)] = true
		local element = record.sites[i].species[1].element
		atoms[#atoms + 1] = { grid[1], grid[2], grid[3], element }
		for axis = 1, 3 do size[axis] = math.max(size[axis], grid[axis] + 1) end
	end
	return { atoms = atoms, box = size, points = points, minimum = minimum }
end

local function inside(p, lo, hi)
	return p[1] >= lo[1] and p[1] <= hi[1] and p[2] >= lo[2] and p[2] <= hi[2] and p[3] >= lo[3] and p[3] <= hi[3]
end

local function formula_keys(record)
	local counts = {}
	for _, site in ipairs(record.sites) do
		local element = site.species[1].element
		counts[element] = (counts[element] or 0) + 1
	end
	local gcd
	for _, count in pairs(counts) do
		local a, b = count, gcd or count
		while b ~= 0 do a, b = b, a % b end
		gcd = a
	end
	local reduced, formula = {}, {}
	for element, count in pairs(counts) do reduced[#reduced + 1] = { element, count / gcd } end
	table.sort(reduced, function(a, b) return a[1] < b[1] end)
	for _, pair in ipairs(reduced) do
		formula[#formula + 1] = pair[1] .. tostring(pair[2])
	end
	local anonymous = {}
	for _, pair in ipairs(reduced) do anonymous[#anonymous + 1] = pair[2] end
	table.sort(anonymous)
	for i, count in ipairs(anonymous) do anonymous[i] = tostring(count) end
	return table.concat(formula), table.concat(anonymous, ",") .. "-" .. #reduced
end
M.formula_keys = formula_keys

function M.fingerprint(record)
	if type(record.sites) ~= "table" then return M.fingerprint_formula(record.formula or "") end
	local formula, anonymous = formula_keys(record)
	return { formula = formula, anonymous = anonymous }
end

function M.fingerprint_formula(text)
	local counts, index = {}, 1
	while index <= #text do
		local element, digits = text:match("([A-Z][a-z]?)(%d*)", index)
		if not element then break end
		counts[element] = (counts[element] or 0) + (digits == "" and 1 or tonumber(digits))
		index = index + #element + #digits
	end
	local gcd
	for _, count in pairs(counts) do
		local a, b = count, gcd or count
		while b ~= 0 do a, b = b, a % b end
		gcd = a
	end
	local reduced = {}
	for element, count in pairs(counts) do reduced[#reduced + 1] = { element, count / gcd } end
	table.sort(reduced, function(a, b) return a[1] < b[1] end)
	local formula, anonymous = {}, {}
	for _, pair in ipairs(reduced) do formula[#formula + 1] = pair[1] .. tostring(pair[2]); anonymous[#anonymous + 1] = pair[2] end
	table.sort(anonymous)
	for i, count in ipairs(anonymous) do anonymous[i] = tostring(count) end
	return { formula = table.concat(formula), anonymous = table.concat(anonymous, ",") .. "-" .. #reduced }
end

-- Parse formula-like structure names used by the filtered API list. A trailing -<digits>
-- is a structure suffix, not part of the formula; malformed names return nil so the detail
-- record remains the authority.
function M.name_fingerprint(name)
	if type(name) ~= "string" then return nil end
	local text = name:gsub("%-%d+$", "")
	local function add(into, from, multiplier)
		for element, count in pairs(from) do into[element] = (into[element] or 0) + count * multiplier end
	end
	local function group(index, closing)
		local counts = {}
		while index <= #text do
			local character = text:sub(index, index)
			if closing and character == closing then return counts, index + 1 end
			if character == "(" then
				local nested; nested, index = group(index + 1, ")")
				if not nested then return nil end
				local digits = text:match("(%d*)", index)
				local multiplier = digits == "" and 1 or tonumber(digits)
				add(counts, nested, multiplier); index = index + #digits
			elseif character:match("%u") then
				local element = text:match("([A-Z][a-z]?)", index)
				local digits = text:match("(%d*)", index + #element)
				local multiplier = digits == "" and 1 or tonumber(digits)
				counts[element] = (counts[element] or 0) + multiplier
				index = index + #element + #digits
			else
				return nil
			end
		end
		return closing and nil or counts, index
	end
	local counts, index = group(1)
	if not counts or index <= #text then return nil end
	local reduced, gcd = {}, nil
	for _, count in pairs(counts) do
		local a, b = count, gcd or count
		while b ~= 0 do a, b = b, a % b end
		gcd = a
	end
	for element, count in pairs(counts) do reduced[#reduced + 1] = { element, count / gcd } end
	table.sort(reduced, function(a, b) return a[1] < b[1] end)
	local formula, anonymous = {}, {}
	for _, pair in ipairs(reduced) do formula[#formula + 1] = pair[1] .. tostring(pair[2]); anonymous[#anonymous + 1] = pair[2] end
	table.sort(anonymous)
	for i, count in ipairs(anonymous) do anonymous[i] = tostring(count) end
	return { formula = table.concat(formula), anonymous = table.concat(anonymous, ",") .. "-" .. #reduced }
end

function M.similar_fingerprint(fingerprint, fingerprints)
	for _, existing in ipairs(fingerprints or {}) do
		if existing.formula == fingerprint.formula or existing.anonymous == fingerprint.anonymous then return true end
	end
	return false
end

function M.filter_name_candidates(list, fingerprints, tried)
	local candidates, similar = {}, 0
	for _, item in ipairs(list or {}) do
		if type(item) == "table" and item.id and not (tried and tried[item.id]) then
			local fingerprint = M.name_fingerprint(item.name)
			if fingerprint and M.similar_fingerprint(fingerprint, fingerprints) then similar = similar + 1
			else candidates[#candidates + 1] = item end
		end
	end
	return candidates, similar
end

function M.similar(record, fingerprints)
	local fingerprint = M.fingerprint(record)
	for _, existing in ipairs(fingerprints or {}) do
		if existing.formula == fingerprint.formula or existing.anonymous == fingerprint.anonymous then return true, fingerprint end
	end
	return false, fingerprint
end

-- The next candidate must differ from every other room's current record and from this
-- room's previous record. A and B are both compared by similar().
function M.exclusion_fingerprints(entries, previous, current)
	local out = {}
	for _, entry in ipairs(entries or {}) do
		if entry ~= current and entry.record then out[#out + 1] = entry.fingerprint or M.fingerprint(entry.record) end
	end
	if previous then out[#out + 1] = previous end
	return out
end

local function make_geometry(record, converted)
	local matrix, minimum = record.lattice.matrix, converted.minimum
	local corners = {}
	for f1 = 0, 1 do for f2 = 0, 1 do for f3 = 0, 1 do
		local p = {}
		for axis = 1, 3 do p[axis] = f1 * matrix[1][axis] + f2 * matrix[2][axis] + f3 * matrix[3][axis] end
		corners[#corners + 1] = rounded_grid(p, minimum)
	end end end
	local atom_voxels, extent = {}, {}
	for _, atom in ipairs(converted.atoms) do atom_voxels[key(atom)] = true; extent[#extent + 1] = atom end
	for _, corner in ipairs(corners) do extent[#extent + 1] = corner end
	local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	for _, p in ipairs(extent) do for axis = 1, 3 do lo[axis] = math.min(lo[axis], p[axis]); hi[axis] = math.max(hi[axis], p[axis]) end end
	local cell_set, edge_pairs = {}, { { 1, 2 }, { 1, 3 }, { 1, 5 }, { 2, 4 }, { 2, 6 }, { 3, 4 },
		{ 3, 7 }, { 4, 8 }, { 5, 6 }, { 5, 7 }, { 6, 8 }, { 7, 8 } }
	for _, edge in ipairs(edge_pairs) do for voxel, p in pairs(line_voxels(corners[edge[1]], corners[edge[2]])) do cell_set[voxel] = p end end
	local bonds, anion_count = {}, 0
	for _, site in ipairs(record.sites) do if M.ANIONS[site.species[1].element] then anion_count = anion_count + 1 end end
	local function add_bond(metal_i, neighbour_i, metal)
		local metal_point, neighbour_point = converted.points[metal_i], converted.points[neighbour_i]
		local r1 = elements[metal] and elements[metal].radius or 1.5
		local anion = record.sites[neighbour_i].species[1].element
		local r2 = elements[anion] and elements[anion].radius or 1.5
		for s1 = -1, 1 do for s2 = -1, 1 do for s3 = -1, 1 do
			local shift = { s1, s2, s3 }
			local image = {}
			for axis = 1, 3 do image[axis] = neighbour_point[axis]
				+ shift[1] * matrix[1][axis] + shift[2] * matrix[2][axis] + shift[3] * matrix[3][axis] end
			local distance = 0
			for axis = 1, 3 do distance = distance + (image[axis] - metal_point[axis]) ^ 2 end
			if math.sqrt(distance) < 1.25 * (r1 + r2) then
				local start, finish = rounded_grid(metal_point, minimum), rounded_grid(image, minimum)
				for voxel, p in pairs(line_voxels(start, finish)) do
					if inside(p, lo, hi) and not atom_voxels[key(p)] and (not bonds[voxel] or metal < bonds[voxel][4]) then
						p[4] = metal; bonds[voxel] = p
					end
				end
			end
		end end end
	end
	for i, site in ipairs(record.sites) do
		local metal = site.species[1].element
		if not M.ANIONS[metal] then
			for j, other in ipairs(record.sites) do
				if M.ANIONS[other.species[1].element] then add_bond(i, j, metal) end
			end
		end
	end
	if anion_count == 0 then
		for i, site in ipairs(record.sites) do for j = i + 1, #record.sites do
			if site.species[1].element ~= record.sites[j].species[1].element then add_bond(i, j, site.species[1].element) end
		end end
	end
	local cell = {}
	for voxel, p in pairs(cell_set) do if inside(p, lo, hi) and not atom_voxels[voxel] and not bonds[voxel] then cell[#cell + 1] = p end end
	local sorted_bonds = sorted_voxels(bonds, true)
	for _, p in ipairs(sorted_bonds) do p[4] = p[4] end
	table.sort(cell, function(a, b) for axis = 1, 3 do if a[axis] ~= b[axis] then return a[axis] < b[axis] end end return false end)
	return { atoms = converted.atoms, box = converted.box, lo = lo, hi = hi, cell = cell, bonds = sorted_bonds }
end

function M.prepare(record)
	if not record or not record.lattice or not record.lattice.matrix then return nil, "missing lattice matrix" end
	if not record.sites or #record.sites == 0 or #record.sites > M.MAX_SITES then return nil, "unsupported atom count" end
	for _, site in ipairs(record.sites) do
		if not site.abc or not site.species or #site.species ~= 1 or site.species[1].occu ~= 1 then return nil, "disordered or incomplete site" end
		if not elements[site.species[1].element] then return nil, "unknown element" end
	end
	if not M.is_bulk(record) then return nil, "structure is not bulk" end
	local converted, err = M.convert(record)
	if not converted then return nil, err end
	local output = make_geometry(record, converted)
	local fp = M.footprint(output)
	if fp[1] + 2 > 19 or fp[2] + 2 > 19 then return nil, "horizontal footprint is too large" end
	if fp[3] > M.MAX_CELL_HEIGHT then return nil, "cell is too tall" end
	if #output.bonds < 1 then return nil, "structure has no bonds" end
	if #output.bonds + #output.cell > M.MAX_DOTS then return nil, "too many marker dots" end
	output.id, output.name, output.md5 = record.id, record.name, record.md5
	output.formula = record.formula or formula_keys(record)
	output.lattice, output.sites = record.lattice, #record.sites
	return output
end

function M.footprint(record)
	return { record.hi[1] - record.lo[1] + 1, record.hi[2] - record.lo[2] + 1, record.hi[3] - record.lo[3] + 1 }
end

function M.dots(record, origin)
	local dots = {}
	local function add(voxel, colour, kind, size)
		dots[#dots + 1] = { pos = { x = origin.x + voxel[1] - record.lo[1] - 0.5,
			y = origin.y + voxel[3] - record.lo[3] - 0.5, z = origin.z + voxel[2] - record.lo[2] - 0.5 },
			colour = colour, kind = kind, size = size }
	end
	for _, voxel in ipairs(record.bonds) do add(voxel, "#FFFFFF", "bonds", 1.7) end
	for _, voxel in ipairs(record.cell) do add(voxel, "#FF8C00", "cells", 1.2) end
	return dots
end

return M
