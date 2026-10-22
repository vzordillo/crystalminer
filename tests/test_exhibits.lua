package.path = "mods/crystalminer/?.lua;tests/?.lua;" .. package.path
local C = require("exhibit_structures")
local Live = loadfile("mods/crystalminer/exhibit_live.lua")(dofile("mods/crystalminer/exhibit_elements.lua"))
local data = dofile("mods/crystalminer/exhibit_data.lua")
local content = dofile("mods/crystalminer/content.lua")
local T = require("testlib")

print("structure exhibits")

local rooms = {
	{ id = "exhibit_1", portal = { -59, 65 }, min = { -280, -1, -20 }, size = { 35, 32, 35 } },
	{ id = "exhibit_2", portal = { 59, 65 }, min = { 230, -1, -20 }, size = { 35, 32, 35 } },
	{ id = "exhibit_3", portal = { -59, 75 }, min = { -230, -1, -20 }, size = { 35, 32, 35 } },
	{ id = "exhibit_4", portal = { 59, 75 }, min = { 180, -1, -20 }, size = { 35, 32, 35 } },
	{ id = "exhibit_5", portal = { -59, 85 }, min = { -330, -1, -20 }, size = { 35, 32, 35 } },
	{ id = "exhibit_6", portal = { 59, 85 }, min = { 280, -1, -20 }, size = { 35, 32, 35 } },
}

local function overlap(a, b)
	return a.min[1] < b.min[1] + b.size[1] and b.min[1] < a.min[1] + a.size[1]
		and a.min[2] < b.min[2] + b.size[2] and b.min[2] < a.min[2] + a.size[2]
		and a.min[3] < b.min[3] + b.size[3] and b.min[3] < a.min[3] + a.size[3]
end

T.run("fallback records and baked geometry remain intact", function()
	local expected = { ["MgMn4O8-0"] = 52, SrTiO3 = 40, CaTiO3 = 5 }
	for _, item in ipairs(data) do
		T.ok(expected[item.name] == #item.atoms, item.name .. " atom count")
		T.ok(item.lo and item.hi and item.cell and item.bonds, item.name .. " geometry")
		local atoms = {}
		for _, atom in ipairs(item.atoms) do
			local key = atom[1] .. ":" .. atom[2] .. ":" .. atom[3]
			T.ok(not atoms[key], item.name .. " atom grid collision")
			atoms[key] = true
		end
	end
end)

T.run("six permanent portals and rooms are ordered and disjoint", function()
	for i, room in ipairs(rooms) do
		T.eq(room.id, "exhibit_" .. i)
		T.eq(room.size[1], 35); T.eq(room.size[2], 32); T.eq(room.size[3], 35)
		T.eq(room.portal[2], 65 + math.floor((i - 1) / 2) * 10)
		T.eq(room.portal[1], i % 2 == 1 and -59 or 59)
		for j = 1, i - 1 do T.ok(not overlap(room, rooms[j]), room.id .. " overlaps " .. rooms[j].id) end
	end
	local museum = { min = content.museum.at, size = content.museum.size }
	for _, room in ipairs(rooms) do
		T.ok(not overlap(room, museum), room.id .. " overlaps museum")
		for _, world in ipairs(content.regions) do
			local ws = world.size or { 160, 20, 160 }
			T.ok(not overlap(room, { min = { world.at[1] - 60, world.at[2] - 1, world.at[3] - 60 },
				size = { ws[1] + 120, ws[2] + 20, ws[3] + 120 } }), room.id .. " overlaps " .. world.id)
		end
	end
end)

T.run("baked cell and bond voxels stay inside their extents", function()
	for _, item in ipairs(data) do
		local atoms = {}
		for _, atom in ipairs(item.atoms) do atoms[atom[1] .. ":" .. atom[2] .. ":" .. atom[3]] = true end
		for _, kind in ipairs({ "bonds", "cell" }) do
			for _, voxel in ipairs(item[kind]) do
				T.ok(voxel[1] >= item.lo[1] and voxel[1] <= item.hi[1] and voxel[2] >= item.lo[2] and voxel[2] <= item.hi[2]
					and voxel[3] >= item.lo[3] and voxel[3] <= item.hi[3], item.name .. " " .. kind .. " extent")
				T.ok(not atoms[voxel[1] .. ":" .. voxel[2] .. ":" .. voxel[3]], item.name .. " " .. kind .. " atom overlap")
			end
		end
	end
end)

T.run("uniform scale and platform constraints remain", function()
	T.eq(C.BLOCK_ANGSTROM, 0.7)
	for _, item in ipairs(data) do
		local fp = C.footprint(item)
		T.ok(fp[1] + 2 <= 19 and fp[2] + 2 <= 19, item.name .. " platform")
		T.ok(fp[3] + 4 <= 32, item.name .. " room height")
	end
end)

T.run("bulk validation accepts fallbacks and rejects a slab", function()
	for _, item in ipairs(data) do
		T.ok(item.name == "MgMn4O8-0" or item.name == "SrTiO3" or item.name == "CaTiO3", item.name .. " bulk")
	end
	local slab = { lattice = { a = 10, b = 10, c = 20 }, sites = {
		{ abc = { 0, 0, 0 }, species = { { element = "Sr", occu = 1 } } },
		{ abc = { 0.5, 0.5, 0.01 }, species = { { element = "O", occu = 1 } } },
	} }
	T.ok(not Live.is_bulk(slab), "slab rejected")
end)

T.run("rooms are outside the conservative world bounds", function()
	for _, room in ipairs(rooms) do
		for _, world in ipairs(content.regions) do
			local ws = world.size or { 160, 20, 160 }
			T.ok(not overlap(room, { min = { world.at[1] - 60, world.at[2] - 1, world.at[3] - 60 },
				size = { ws[1] + 120, ws[2] + 20, ws[3] + 120 } }), room.id .. " clear")
		end
	end
end)

T.finish()
