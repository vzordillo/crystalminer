package.path = "mods/crystalminer/?.lua;tests/?.lua;" .. package.path
local elements = dofile("mods/crystalminer/exhibit_elements.lua")
local Live = loadfile("mods/crystalminer/exhibit_live.lua")(elements)
local baked = dofile("mods/crystalminer/exhibit_data.lua")
local fixtures = dofile("tests/fixtures/exhibit_records.lua")
local content = dofile("mods/crystalminer/content.lua")
local T = require("testlib")

print("live structure pipeline")

local function compact_record()
	local sites = {}
	for x = 0.25, 0.75, 0.5 do for y = 0.25, 0.75, 0.5 do for z = 0.25, 0.75, 0.5 do
		sites[#sites + 1] = { abc = { x, y, z }, species = { { element = (#sites % 2 == 0) and "O" or "Sr", occu = 1 } } }
	end end end
	return { id = "synthetic", name = "Synthetic", md5 = "synthetic", lattice = {
		a = 6, b = 6, c = 6, alpha = 90, beta = 90, gamma = 90,
		matrix = { { 6, 0, 0 }, { 0, 6, 0 }, { 0, 0, 6 } },
	}, sites = sites }
end

T.run("live pipeline prepares bulk geometry", function()
	local out, err = Live.prepare(compact_record())
	T.ok(out, err)
	T.ok(#out.atoms == 8 and #out.bonds > 0, "atoms and bonds")
	T.ok(#out.cell > 0 and out.hi[3] - out.lo[3] + 1 <= 24, "cell geometry")
	T.ok(#out.bonds + #out.cell <= Live.MAX_DOTS, "dot cap")
end)

T.run("live filters reject slabs, disorder, unknown elements, and grid collisions", function()
	local slab = compact_record(); slab.lattice.c = 20; slab.lattice.matrix[3][3] = 20
	T.ok(not Live.is_bulk(slab), "slab rejected")
	local disorder = compact_record(); disorder.sites[1].species[1].occu = 0.5
	T.ok(not Live.prepare(disorder), "disorder rejected")
	local unknown = compact_record(); unknown.sites[1].species[1].element = "Xx"
	T.ok(not Live.prepare(unknown), "unknown element rejected")
	local collision = compact_record(); collision.sites[2].abc = collision.sites[1].abc
	T.ok(not Live.prepare(collision), "grid collision rejected")
end)

T.run("similarity uses reduced formula and anonymous stoichiometry", function()
	local sr = Live.fingerprint_formula("SrTiO3")
	local ca = Live.fingerprint_formula("CaTiO3")
	local mg = Live.fingerprint_formula("MgMn4O8")
	T.eq(sr.formula, "O3Sr1Ti1")
	T.eq(sr.anonymous, "1,1,3-3")
	T.ok(sr.anonymous == ca.anonymous and sr.formula ~= ca.formula, "ABO3 structures are similar")
	T.ok(mg.anonymous ~= sr.anonymous, "different stoichiometry is distinct")
	T.ok(Live.similar({ formula = "CaTiO3" }, { sr }), "formula or anonymous match")
end)

T.run("entry exclusion uses other current rooms and this room's previous record", function()
	local a, b, c = { formula = "A1B1O3", anonymous = "1,1,3-3" }, { formula = "C1D1O3", anonymous = "1,1,3-3" }, { formula = "E1F2", anonymous = "1,2-2" }
	local current = { record = { sites = {} }, fingerprint = a }
	local excluded = Live.exclusion_fingerprints({ current, { record = { sites = {} }, fingerprint = b } }, c, current)
	T.eq(#excluded, 2)
	T.ok(Live.similar_fingerprint(a, excluded), "other current fingerprint excluded")
	T.ok(Live.similar_fingerprint(c, excluded), "previous fingerprint excluded")
end)

T.run("structure-name parser handles formulas and suffixes", function()
	T.eq(Live.name_fingerprint("BaTi(SiO3)3").formula, "Ba1O9Si3Ti1")
	T.eq(Live.name_fingerprint("Ca(TiS2)4").formula, "Ca1S8Ti4")
	T.eq(Live.name_fingerprint("Ag10Sn10CS20N").formula, "Ag10C1N1S20Sn10")
	T.eq(Live.name_fingerprint("BaTiO3-0").anonymous, "1,1,3-3")
	T.eq(Live.name_fingerprint("junk"), nil)
end)

T.run("filtered list candidates keep malformed names for record-level checks", function()
	local list = {
		{ id = "similar", name = "BaTiO3-0" }, { id = "nested", name = "BaTi(SiO3)3" },
		{ id = "malformed", name = "junk" }, { id = "seen", name = "Ca(TiS2)4" },
	}
	local candidates, similar = Live.filter_name_candidates(list, { Live.fingerprint_formula("SrTiO3") }, { seen = true })
	T.eq(similar, 1)
	T.eq(#candidates, 2)
	T.eq(candidates[1].id, "nested")
	T.eq(candidates[2].id, "malformed")
	local empty = Live.filter_name_candidates({}, {})
	T.eq(#empty, 0)
end)

T.run("live slots are ordered, limited, and outside existing worlds", function()
	local slots = {
		{ portal = { -59, 65 }, min = { -280, -1, -20 } }, { portal = { 59, 65 }, min = { 230, -1, -20 } },
		{ portal = { -59, 75 }, min = { -230, -1, -20 } }, { portal = { 59, 75 }, min = { 180, -1, -20 } },
		{ portal = { -59, 85 }, min = { -330, -1, -20 } }, { portal = { 59, 85 }, min = { 280, -1, -20 } },
	}
	local function overlap(a, b)
		return a.min[1] < b.min[1] + b.size[1] and b.min[1] < a.min[1] + a.size[1]
			and a.min[3] < b.min[3] + b.size[3] and b.min[3] < a.min[3] + a.size[3]
	end
	for _, slot in ipairs(slots) do
		local room = { min = slot.min, size = { 35, 32, 35 } }
		T.ok(not overlap(room, { min = content.museum.at, size = content.museum.size }), "slot outside museum")
		for _, world in ipairs(content.regions) do
			local size = world.size or { 160, 20, 160 }
			T.ok(not overlap(room, { min = { world.at[1] - 60, -1, world.at[3] - 60 }, size = { size[1] + 120, 52, size[3] + 120 } }), "slot outside world")
		end
	end
	for i = 1, #slots - 1 do T.ok(slots[i].min[1] ~= slots[i + 1].min[1], "slots are distinct") end
end)

T.run("live dots are white bonds and orange cells", function()
	local out = assert(Live.prepare(compact_record()))
	local dots = Live.dots(out, { x = 10, y = 2, z = 20 })
	T.eq(#dots, #out.bonds + #out.cell)
	for i = 1, #out.bonds do T.eq(dots[i].colour, "#FFFFFF"); T.eq(dots[i].kind, "bonds") end
	for i = #out.bonds + 1, #dots do T.eq(dots[i].colour, "#FF8C00"); T.eq(dots[i].kind, "cells") end
end)

T.run("runtime pipeline matches the three baked structures", function()
	for i, fixture in ipairs(fixtures) do
		local out = assert(Live.prepare(fixture))
		local expected = baked[i]
		T.eq(#out.atoms, #expected.atoms, fixture.name .. " atom parity")
		for j, atom in ipairs(expected.atoms) do
			for axis = 1, 4 do T.eq(out.atoms[j][axis], atom[axis], fixture.name .. " atom parity") end
		end
		for axis = 1, 3 do T.eq(out.lo[axis], expected.lo[axis], fixture.name .. " lo parity"); T.eq(out.hi[axis], expected.hi[axis], fixture.name .. " hi parity") end
		for _, kind in ipairs({ "cell", "bonds" }) do
			T.eq(#out[kind], #expected[kind], fixture.name .. " " .. kind .. " count parity")
			for j, voxel in ipairs(expected[kind]) do
				for axis = 1, 3 do T.eq(out[kind][j][axis], voxel[axis], fixture.name .. " " .. kind .. " parity") end
			end
		end
	end
end)

T.finish()
