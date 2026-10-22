-- Runs inside a real Luanti server when crystalminer.selftest = true (see tests/run_server_test.sh).
-- Exercises the registered callbacks the way the engine calls them, writes the results to
-- <world>/crystalminer_selftest.txt and shuts the server down.

local cm = crystalminer
local S, L, content = cm.S, cm.L, cm.content
local results, failures = {}, 0

local function check(name, cond, detail)
	results[#results + 1] = (cond and "ok    " or "FAIL  ") .. name .. ((not cond and detail) and (" -- " .. detail) or "")
	if not cond then failures = failures + 1 end
end

local function live(id)
	for _, r in ipairs(cm.regions) do
		if r.area.id == id then return r end
	end
end

--- Places a node the way the engine does after a player places it: set it, then run every
-- registered on_placenode callback.
local function place(pos, name)
	local node = { name = name }
	local old = core.get_node(pos)
	core.set_node(pos, node)
	for _, cb in ipairs(core.registered_on_placenodes) do cb(pos, node, nil, old, ItemStack(name), nil) end
end

local function dig(pos)
	local old = core.get_node(pos)
	core.remove_node(pos)
	for _, cb in ipairs(core.registered_on_dignodes) do cb(pos, old, nil) end
end

local function count_in(r, name)
	local n = 0
	for x = r.min[1], r.min[1] + r.size[1] - 1 do
		for y = r.min[2], r.min[2] + r.size[2] - 1 do
			for z = r.min[3], r.min[3] + r.size[3] - 1 do
				if core.get_node({ x = x, y = y, z = z }).name == name then n = n + 1 end
			end
		end
	end
	return n
end

--- Every node of the museum's shell that is missing (air or ignore), per part: the four outer
-- walls, the roof and the floor. A part of the map generated after the build would leave holes.
local function museum_shell_gaps()
	local B = cm.lobby
	local G = cm.GROUND_Y
	core.load_area({ x = B.X0, y = G, z = B.Z0 }, { x = B.X1, y = B.TOP + 1, z = B.Z1 })
	local gaps = { south = 0, north = 0, west = 0, east = 0, roof = 0, floor = 0 }
	local function missing(x, y, z)
		local n = core.get_node({ x = x, y = y, z = z }).name
		return n == "air" or n == "ignore"
	end
	for x = B.X0, B.X1 do
		for z = B.Z0, B.Z1 do
			if missing(x, B.TOP + 1, z) then gaps.roof = gaps.roof + 1 end
			if missing(x, G, z) then gaps.floor = gaps.floor + 1 end
			local side = (z == B.Z0 and "south") or (z == B.Z1 and "north") or (x == B.X0 and "west")
				or (x == B.X1 and "east")
			if side then
				local door = side == "south" and (x == B.ENTRANCE[1] or x == B.ENTRANCE[2])
				for y = door and G + 4 or G + 1, B.TOP do
					if missing(x, y, z) then gaps[side] = gaps[side] + 1 end
				end
			end
		end
	end
	return gaps
end

local function run()
	-- The initial build: how the engine answered each emerge request, and whether the museum's
	-- shell came out whole.
	local st = cm.emerge_stats or {}
	results[#results + 1] = string.format("info  emerge callbacks: cancelled %d, errored %d, memory %d, disk %d, generated %d, retries %d, blocks %d; chunks generated after the build %d",
		st[core.EMERGE_CANCELLED] or 0, st[core.EMERGE_ERRORED] or 0, st[core.EMERGE_FROM_MEMORY] or 0,
		st[core.EMERGE_FROM_DISK] or 0, st[core.EMERGE_GENERATED] or 0, st.retries or 0, st.total or 0, st.late or 0)
	check("the initial build waited for every map block (none given up, none generated after it)",
		(st.gave_up or 0) == 0 and (st.late or 0) == 0, string.format("given up %d, late chunks %d", st.gave_up or 0, st.late or 0))
	local gaps = museum_shell_gaps()
	local total = 0
	for _, v in pairs(gaps) do total = total + v end
	check("museum shell is complete (outer walls, roof, floor)", total == 0,
		string.format("missing: south %d, north %d, west %d, east %d, roof %d, floor %d",
			gaps.south, gaps.north, gaps.west, gaps.east, gaps.roof, gaps.floor))
	-- Mirror Plaza: a block is mirrored across the plane through column min.x + 12.
	local m = live("mirror_plaza").region
	local p = { x = m.min[1] + 2, y = m.min[2], z = m.min[3] + 5 }
	place(p, "crystalminer:red")
	local mirror = core.get_node({ x = m.min[1] + 22, y = m.min[2], z = m.min[3] + 5 }).name
	check("mirror plaza copies a block across the plane", mirror == "crystalminer:red", mirror)
	dig(p)
	mirror = core.get_node({ x = m.min[1] + 22, y = m.min[2], z = m.min[3] + 5 }).name
	check("digging removes the mirror image", mirror == "air", mirror)

	-- Kaleidoscope: one block in a general position becomes 48.
	local k = live("kaleidoscope").region
	place({ x = k.min[1] + 11, y = k.min[2] + 13, z = k.min[3] + 16 }, "crystalminer:yellow")
	local n = count_in(k, "crystalminer:yellow")
	check("kaleidoscope makes 48 copies", n == 48, tostring(n))

	-- Translation Hall: one block in each of the 27 unit cells.
	local t = live("translation_hall").region
	place({ x = t.min[1] + 1, y = t.min[2] + 1, z = t.min[3] + 2 }, "crystalminer:blue")
	n = count_in(t, "crystalminer:blue")
	check("translation hall repeats a block in 27 cells", n == 27, tostring(n))

	-- Square Court (4mm): /whatsymmetry's analysis recovers 4mm from what was built.
	local sq = live("square_court")
	local r = sq.region
	place({ x = r.min[1] + 2, y = r.min[2], z = r.min[3] + 5 }, "crystalminer:green")
	place({ x = r.min[1] + 3, y = r.min[2] + 1, z = r.min[3] + 5 }, "crystalminer:green")
	local _, entry = cm.analyse(sq)
	check("analysis of a build in Square Court finds 4mm", entry and entry.symbol == "4mm", entry and entry.symbol)

	-- Locked regions: a new player cannot build in a tier-1 region; a tier-4 player can.
	check("new player is locked out of tier 1", core.is_protected(p, "newbie") == true)
	cm.progress("teacher_test").tier = 4
	check("tier-4 player may build", core.is_protected(p, "teacher_test") == false)

	-- Gate quiz: correct answers unlock tier 1, a wrong one does not count.
	local qs = L.questions(content.gate, 0)
	cm.answer("student", qs[1].id, (qs[1].answer + 1) % #qs[1].options)
	check("wrong answer does not count", not cm.progress("student").answered[qs[1].id])
	for _, q in ipairs(qs) do cm.answer("student", q.id, q.answer) end
	check("gate quiz unlocks tier 1", cm.progress("student").tier == 1, tostring(cm.progress("student").tier))
	local saved = core.deserialize(cm.storage:get_string("progress:student"))
	check("progress is saved to mod storage", saved and saved.tier == 1)

	-- Gate displays: every display has its original and its copy in place.
	local ok = true
	for _, d in ipairs(cm.G.displays(content.gate.at)) do
		for _, p2 in ipairs(d.original) do if core.get_node(p2).name ~= "crystalminer:" .. d.colour then ok = false end end
		for _, p2 in ipairs(d.copy) do if core.get_node(p2).name ~= "crystalminer:" .. d.colour then ok = false end end
	end
	check("gate displays show each motif and its copy", ok)

	-- Try-it Pad: an L-shaped build is chiral, so its mirror image cannot be moved to match it,
	-- while a rotation always matches.
	local b = cm.PAD_BUILD
	-- Regression: punching a lever with an empty build box must not error (it once called an undefined `say`).
	for dx = 0, 4 do for dy = 0, 4 do for dz = 0, 4 do
		core.set_node({ x = b.x + dx, y = b.y + dy, z = b.z + dz }, { name = "air" })
	end end end
	local fake_puncher = { is_player = function() return true end, get_player_name = function() return "selftest_fake" end }
	local lever_def = core.registered_nodes["crystalminer:lever_" .. cm.LEVERS[1].letter]
	local punch_ok, punch_err = pcall(lever_def.on_punch, { x = 0, y = 0, z = 0 }, { name = lever_def.name }, fake_puncher)
	check("pad: punching a lever with an empty build box does not error", punch_ok, tostring(punch_err))
	for _, o in ipairs({ { 0, 0, 0 }, { 1, 0, 0 }, { 2, 0, 0 }, { 2, 0, 1 }, { 0, 1, 0 }, { 0, 2, 0 } }) do
		core.set_node({ x = b.x + 1 + o[1], y = b.y + o[2], z = b.z + 1 + o[3] }, { name = "crystalminer:red" })
	end
	local mirror_lever, rotate_lever
	for _, l in ipairs(cm.LEVERS) do
		if l.letter == "M" then mirror_lever = l elseif l.letter == "R" then rotate_lever = l end
	end
	local empty, matches = cm.apply_lever(mirror_lever)
	check("pad: a chiral build does not match its mirror image", empty == false and matches == false)
	local reds = 0
	local rr = cm.PAD_RESULT
	for dx = 0, 4 do for dy = 0, 4 do for dz = 0, 4 do
		if core.get_node({ x = rr.x + dx, y = rr.y + dy, z = rr.z + dz }).name == "crystalminer:red" then reds = reds + 1 end
	end end end
	check("pad: the result box shows all 6 blocks", reds == 6, tostring(reds))
	empty, matches = cm.apply_lever(rotate_lever)
	check("pad: a rotated build always matches", matches == true)

	-- Plane-group floor: one block becomes 8 per cell in 16 cells.
	local w = live("weave_tiles").region
	place({ x = w.min[1] + 1, y = w.min[2], z = w.min[3] + 2 }, "crystalminer:purple")
	n = count_in(w, "crystalminer:purple")
	check("weave tiles (p4g) make 8 copies in each of 36 cells", n == 288, tostring(n))

	-- -3 room: 6 copies.
	local t3 = live("bar_three_room").region
	place({ x = t3.min[1] + 2, y = t3.min[2] + 4, z = t3.min[3] + 9 }, "crystalminer:cyan")
	n = count_in(t3, "crystalminer:cyan")
	check("bar-three room makes 6 copies", n == 6, tostring(n))

	-- Architecture: the Fourfold Tower has brick corner towers, and nothing was built inside regions.
	local ft = live("fourfold_tower").region
	local corner = { x = ft.min[1] - 3, y = 5, z = ft.min[3] - 3 }
	core.load_area(corner)
	check("fourfold tower has a brick corner tower", core.get_node(corner).name == "crystalminer:brick", core.get_node(corner).name)
	check("Mirror Plaza is paved", core.get_node({ x = m.min[1] - 3, y = 0, z = m.min[3] + 3 }).name == "crystalminer:plaza")

	-- Lattice floors alternate their tint cell by cell.
	local mt = live("mirror_tiles").region
	check("lattice floor alternates by unit cell",
		core.get_node({ x = mt.min[1], y = 0, z = mt.min[3] }).name == "crystalminer:floor"
		and core.get_node({ x = mt.min[1] + 6, y = 0, z = mt.min[3] }).name == "crystalminer:floor_alt")

	-- Nothing stands in the strip in front of the gate where players view the displays.
	local clear = true
	for _, d in ipairs(cm.G.displays(content.gate.at)) do
		for dz = 4, 14 do
			for y = 1, 4 do
				if core.get_node({ x = d.look_at.x, y = y, z = d.look_at.z + dz }).name ~= "air" then clear = false end
			end
		end
	end
	check("the view of every gate display is clear", clear)

	check("the engine can load distant map blocks for /showcase", type(core.load_area) == "function")

	-- Showcase: the Twin Mirrors seat (6 blocks) appears 4 times; clear empties the region again.
	local tm = live("twin_mirrors").region
	cm.showcase("twin_mirrors")
	n = count_in(tm, "crystalminer:green")
	check("showcase builds the Twin Mirrors seat four times", n == 24, tostring(n))
	cm.showcase("clear")
	n = count_in(tm, "crystalminer:green")
	check("showcase clear empties the region", n == 0, tostring(n))
	check("showcase clear forgets that an example was built", cm.storage:get_string("showcase:twin_mirrors") == "")

	-- Learning: a full pre-test is recorded and exported without the player's name.
	for _, it in ipairs(content.assessment.items) do
		cm.A.answer(cm.record("student"), "pre", content.assessment.items, it.id, it.answer, 1)
	end
	cm.A.record_prediction(cm.record("student"), "mirror_plaza", 2, 2, 2, 1)
	local summary = cm.export(core.get_worldpath())
	local f = io.open(core.get_worldpath() .. "/crystalminer_tests.csv")
	local text = f and f:read("*a") or ""
	if f then f:close() end
	check("export writes the pre-test without names", summary.n_pre >= 1 and text:find("pre,order4", 1, true) ~= nil
		and not text:find("student", 1, true))
	-- Predictions use the engine's count for the exact spot: 2 off the mirror, 1 on it.
	local mp = live("mirror_plaza")
	local off = cm.counts(mp, { x = mp.region.min[1] + 2, y = mp.region.min[2], z = mp.region.min[3] + 3 })
	local on = cm.counts(mp, { x = mp.region.min[1] + 12, y = mp.region.min[2], z = mp.region.min[3] + 3 })
	check("prediction counts: 2 off the mirror, 1 on it", off == 2 and on == 1, off .. "," .. on)

	-- Step mode names each copy: the Screw Hall's copies include a screw and lattice translations.
	local sh = live("screw_hall")
	local texts = {}
	for _, im in ipairs(cm.described_images(sh, { x = sh.region.min[1] + 1, y = sh.region.min[2], z = sh.region.min[3] + 1 })) do
		texts[#texts + 1] = im.text
	end
	local joined = table.concat(texts, "|")
	check("step mode names screw copies", joined:find("a screw: a half turn about the vertical axis", 1, true) ~= nil
		and joined:find("lattice translation", 1, true) ~= nil, joined)
	-- Spiral Tower: 4 copies per cell in 3 cells.
	local st = live("spiral_tower").region
	place({ x = st.min[1] + 1, y = st.min[2], z = st.min[3] + 2 }, "crystalminer:lime")
	n = count_in(st, "crystalminer:lime")
	check("spiral tower (4_1) makes 4 copies in each of 12 cells", n == 48, tostring(n))

	-- Crystal Museum: the copper model is built (343 atoms for n = 6, one block per atom), each
	-- exhibit has its clue crystal, a right answer is a discovery, and visitors cannot dig exhibits.
	local copper = cm.museum_layout[1]
	local atoms = 0
	for dx = 0, copper.size - 1 do for dy = 0, copper.size - 1 do for dz = 0, copper.size - 1 do
		if core.get_node({ x = copper.x0 + dx, y = copper.y0 + dy, z = copper.z0 + dz }).name == "crystalminer:orange" then atoms = atoms + 1 end
	end end end
	local expect = #dofile(core.get_modpath("crystalminer") .. "/structures.lua").model("fcc", 6)
	check("museum: the copper model has one block per atom", atoms == expect, atoms .. " of " .. expect)
	local clues = 0
	for _, e in ipairs(cm.museum_layout) do
		if core.get_node(e.clue).name == "crystalminer:clue" and core.get_meta(e.clue):get_string("exhibit") == e.ex.id then clues = clues + 1 end
	end
	check("museum: every exhibit has its clue crystal", clues == #cm.museum_layout, tostring(clues))
	check("museum: a wrong clue answer is not a discovery", not cm.answer_clue("student", "copper", 0))
	check("museum: the right answer is a discovery", cm.answer_clue("student", "copper", 2) and cm.discoveries("student") == 1)
	check("museum: visitors cannot change an exhibit", core.is_protected({ x = copper.x0, y = copper.y0, z = copper.z0 }, "student"))

	-- Portal Hall: one portal per region, each with its destination; every world has a portal back,
	-- an entrance arch and its boards.
	local portals, backs, banners, missing_backs = 0, 0, 0, {}
	for _, pt in ipairs(cm.lobby.portals()) do
		local pp = { x = pt.x, y = 1, z = cm.lobby.PORTAL_Z }
		if core.get_node(pp).name == "crystalminer:teleporter" and core.get_meta(pp):get_string("target") == pt.live.area.id then portals = portals + 1 end
		local pl = cm.D.plaza(pt.live.region)
		local back = { x = pl.portal.x, y = 1, z = pl.portal.z }
		-- Load the block first: one unloaded since the build reads as "ignore".
		core.load_area(back)
		local bn = core.get_node(back).name
		if bn == "crystalminer:teleporter" and core.get_meta(back):get_string("target") == "portal_hall" then
			backs = backs + 1
		else
			missing_backs[#missing_backs + 1] = pt.live.area.id .. "=" .. bn
		end
		for _, obj in ipairs(core.get_objects_inside_radius({ x = pl.arrive.x, y = 8, z = pl.arch_z + 0.5 }, 2)) do
			local e = obj:get_luaentity()
			if e and e.name == "crystalminer:sign" then banners = banners + 1 end
		end
	end
	check("portal hall: one portal per world, each with its destination", portals == #cm.regions, tostring(portals))
	local exhibit_portals = 0
	for _, p in ipairs(cm.exhibit_portals or {}) do
		local node = core.get_node(p.pos)
		if node.name == "crystalminer:teleporter" and core.get_meta(p.pos):get_string("target") == p.target then exhibit_portals = exhibit_portals + 1 end
	end
	check("portal hall: six random exhibit portals exist", exhibit_portals == 6, tostring(exhibit_portals))
	local exhibit_command = core.registered_chatcommands.exhibit
	check("random exhibits expose entry flow and list-only command", cm.exhibit_enter and exhibit_command
		and exhibit_command.params == "list")
	check("exhibit migration stamp is current", cm.storage:get_string("exhibit_version") == cm.exhibit_version,
		cm.storage:get_string("exhibit_version"))
	-- The exhibits arrive in existing worlds through their own stamp (exhibit_version), and are rebuilt with everything else (exhibits.lua's on_build) when WORLD_VERSION is raised, as it was for Prism's desk and billboard.
	check("world version is the current one", cm.storage:get_string("world_version") == cm.WORLD_VERSION,
		cm.WORLD_VERSION .. "/" .. cm.storage:get_string("world_version"))
	for _, room in ipairs(cm.exhibit_rooms or {}) do
		local entry = cm.exhibit_dynamic_records and cm.exhibit_dynamic_records[room.number]
		local floor = core.get_node({ x = room.min[1] + 1, y = 0, z = room.min[3] + 1 }).name
		local roof = core.get_node({ x = room.min[1] + 1, y = room.min[2] + room.size[2] - 1, z = room.min[3] + 1 }).name
		check("random exhibit " .. room.id .. " shell", floor == "crystalminer:stone_brick" and roof == "crystalminer:roof_glass")
		check("random exhibit " .. room.id .. " live lookup", entry and cm.exhibit_live_at({ x = room.min[1] + 1, y = 1, z = room.min[3] + 1 }) == entry.room_data.live)
	end
	check("structure exhibit live lookup leaves rooms", not cm.exhibit_live_at({ x = 0, y = 0, z = 0 }))
	check("every world has a portal back to the museum", backs == #cm.regions,
		tostring(backs) .. " " .. table.concat(missing_backs, ", "))
	check("every world's entrance arch carries its name", banners == #cm.regions, tostring(banners))

	-- Signs and doors in the museum: the welcome board, a plaque above each display, the front door.
	local signs = 0
	for _, obj in ipairs(core.get_objects_inside_radius({ x = 0, y = 5, z = -30 }, 12)) do
		local e = obj:get_luaentity()
		if e and e.name == "crystalminer:sign" then signs = signs + 1 end
	end
	check("the foyer has its signs", signs >= 2, tostring(signs))
	local plaques = 0
	for _, d in ipairs(cm.G.displays(content.gate.at)) do
		for _, obj in ipairs(core.get_objects_inside_radius({ x = d.look_at.x, y = 7.5, z = -29.5 }, 1)) do
			local e = obj:get_luaentity()
			if e and e.name == "crystalminer:sign" then plaques = plaques + 1 end
		end
	end
	check("every display has its plaque", plaques == 4, tostring(plaques))
	local door = core.get_node({ x = cm.lobby.Z0 and -1 or 0, y = 1, z = cm.lobby.Z0 }).name
	check("the museum has a front door", door == "crystalminer:door_bottom", door)
	cm.toggle_door({ x = -1, y = 1, z = cm.lobby.Z0 })
	-- Open doors stand against the jambs: the leaves of a double door are turned opposite ways,
	-- and a doorway in a wall at fixed z runs along x (facedir 0/2), at fixed x along z (1/3).
	local function p2(x, z) local n = core.get_node({ x = x, y = 1, z = z }) return n.name .. "/" .. n.param2 end
	check("inner doors in an east-west wall open against its jambs",
		p2(-1, -30) == "crystalminer:door_bottom_open/0" and p2(0, -30) == "crystalminer:door_bottom_open/2",
		p2(-1, -30) .. " " .. p2(0, -30))
	check("inner doors in a north-south wall open against its jambs",
		p2(-21, -41) == "crystalminer:door_bottom_open/1" and p2(-21, -40) == "crystalminer:door_bottom_open/3",
		p2(-21, -41) .. " " .. p2(-21, -40))
	local function nm(x, y, z) return core.get_node({ x = x, y = y, z = z }).name end
	check("doorways are 3 high, so a flying visitor fits through",
		nm(-1, 3, -30) == "air" and nm(0, 3, -30) == "air" and nm(-1, 3, cm.lobby.Z0) == "air"
		and nm(-1, 4, -30) == "crystalminer:stone_brick", nm(-1, 3, -30) .. " " .. nm(-1, 4, -30))
	local stale = core.add_entity({ x = 0, y = 6, z = -20 }, "crystalminer:sign",
		core.serialize({ format = "label", text = "old", v = "an earlier build" }))
	check("a sign from an earlier build of the world removes itself", stale == nil or stale:get_pos() == nil)
	-- NPCs: added once each, never twice, and one saved by an earlier version removes itself.
	local function npc_counts()
		local info, visitors = 0, 0
		for _, e in pairs(core.luaentities) do
			if e.name == "crystalminer:guide_npc" and e.object:get_pos() then info = info + 1 end
			if e.name == "crystalminer:museum_visitor" and e.object:get_pos() then visitors = visitors + 1 end
		end
		return info, visitors
	end
	cm.npc_refresh(true)
	cm.npc_refresh(true)
	local info_n, visitor_n = npc_counts()
	check("NPCs: one information-desk NPC and eight visitors, no duplicates", info_n == 1 and visitor_n == 8,
		info_n .. " " .. visitor_n)
	local old_npc = core.add_entity({ x = 0, y = 1, z = -20 }, "crystalminer:museum_visitor",
		core.serialize({ slot = 1, home = { x = 0, y = 1, z = -20 } }))
	check("NPCs: one saved in the map by an earlier version removes itself", old_npc == nil or old_npc:get_pos() == nil)
	local blocked = {}
	for _, p in ipairs(cm.npc_places) do
		core.load_area({ x = p.x, y = p.y, z = p.z }, { x = p.x, y = p.y + 1, z = p.z })
		local here, above = core.get_node(p).name, core.get_node({ x = p.x, y = p.y + 1, z = p.z }).name
		if here ~= "air" or above ~= "air" then blocked[#blocked + 1] = core.pos_to_string(p) .. " " .. here .. "/" .. above end
	end
	check("NPCs: every NPC stands in free space, not inside furniture", #blocked == 0, table.concat(blocked, ", "))
	-- Guides: a first arrival marks the place as guided (the window opens a moment later), and the
	-- window carries the steps; the Try-it Pad has its labels.
	for _, f in ipairs(cm.on_area) do f("guidetester", "fourfold_tower", live("fourfold_tower")) end
	check("a first arrival shows the place's guide", (cm.progress("guidetester").guided or {}).fourfold_tower == true)
	local gfs = cm.guide_formspec("fourfold_tower")
	check("the guide window has the steps", gfs:find("What to do", 1, true) ~= nil and gfs:find("windmill", 1, true) ~= nil)
	local padsigns = 0
	for _, obj in ipairs(core.get_objects_inside_radius({ x = cm.PAD_BUILD.x - 2, y = 4, z = cm.PAD_BUILD.z }, 9)) do
		local e = obj:get_luaentity()
		if e and e.name == "crystalminer:sign" then padsigns = padsigns + 1 end
	end
	check("the Try-it Pad has its box signs and lever labels", padsigns >= 6, tostring(padsigns))
	-- Furniture: the foyer carpet, a bench, and every sculpture on its plinth.
	check("the foyer has its carpet", core.get_node({ x = 0, y = 1, z = -40 }).name == "crystalminer:carpet")
	check("Gallery 1 has benches facing the displays", core.get_node({ x = 0, y = 1, z = -9 }).name == "crystalminer:bench")
	local sculpted = 0
	for _, sc in ipairs(cm.SCULPTURES.list) do
		local b = sc.blocks[1]
		if core.get_node({ x = sc.at[1] + b[1], y = 2 + b[2], z = sc.at[2] + b[3] }).name == "crystalminer:" .. b[4]
			and core.get_node({ x = sc.at[1], y = 1, z = sc.at[2] }).name == "crystalminer:marble" then
			sculpted = sculpted + 1
		end
	end
	check("every sculpture stands on its plinth", sculpted == #cm.SCULPTURES.list, tostring(sculpted))
	check("the front door opens", core.get_node({ x = -1, y = 2, z = cm.lobby.Z0 }).name == "crystalminer:door_top_open")

	-- Prism, the AI tutor: on the information desk, and a chat that keeps the conversation. The HTTP call is swapped for one that answers at once; the self-test server has no tutor configured.
	local desk = cm.TUTOR_DESK
	check("tutor: the screen stands on the information desk",
		core.get_node({ x = desk.x, y = 3, z = desk.z }).name == "crystalminer:tutor_screen"
		and core.get_node({ x = desk.x, y = 2, z = desk.z }).name == "crystalminer:marble")
	check("tutor: Prism floats behind it", core.get_node({ x = desk.x, y = 5, z = desk.z - 2 }).name == "crystalminer:tutor_prism")
	local tu, Tm = cm.tutor, cm.tutor.T
	local saved_on, saved_send, sent = tu.on, Tm.send, nil
	tu.on = true
	Tm.send = function(_, _, body, _, _, cb) sent = body cb("A **mirror** reflects.", nil) end
	cm.tutor_ask("chatter", "What is a mirror?")
	local c = cm.tutor_chats["chatter"]
	check("tutor: a question and its answer are kept", c and #c.msgs == 2 and c.msgs[1].role == "user"
		and c.msgs[2].role == "assistant" and not c.waiting, c and tostring(#c.msgs))
	check("tutor: the question went out with the chat prompt", sent ~= nil, "nothing sent")
	local bst = cm.billboard_state()
	check("billboard: shows the latest question and answer", bst.mode == "answer" and bst.q == "What is a mirror?"
		and bst.a == "A **mirror** reflects.", bst.mode)
	local boards, facing = 0, true
	for _, obj in ipairs(core.get_objects_inside_radius({ x = 40, y = 9.5, z = -49.48 }, 1.5)) do
		local e = obj:get_luaentity()
		if e and e.name == "crystalminer:billboard" then
			boards = boards + 1
			facing = facing and math.abs(obj:get_yaw() - cm.SG.YAW.n) < 0.01
		end
	end
	check("billboard: hangs above Prism's desk, facing the room", boards == 1 and facing,
		boards .. " " .. tostring(facing))
	check("billboard: its mount in the wall puts it back if it is lost",
		core.get_node(cm.BILLBOARD.AT.wall).name == "crystalminer:billboard_mount" and cm.BILLBOARD.present())
	local fs = cm.tutor_formspec("chatter")
	check("tutor: the window shows the welcome, the answer in bold and the question box",
		fs:find("Prism", 1, true) and fs:find("<b>mirror</b>", 1, true) and fs:find("field[5.35,9.25;9.9,0.85;msg;;]", 1, true)
		and fs:find("scroll_container_end[]", 1, true), fs:sub(1, 200))
	cm.tutor_ask("chatter", "Again?")
	check("tutor: too soon again shows a friendly wait", c.notice and c.notice:find("ask again"), tostring(c.notice))
	tu.on = false
	cm.tutor_ask("sleepy", "Hello?")
	check("tutor: switched off, it says so instead of sending",
		cm.tutor_chats["sleepy"].notice == content.tutor.off and #cm.tutor_chats["sleepy"].msgs == 0)
	tu.on, Tm.send = saved_on, saved_send

	-- Tour: a visitor on the tour may build at a tour stop above their tier, and not elsewhere.
	cm.tour_state["visitor"] = { i = 3 }
	local kal = live("kaleidoscope").region
	check("tour: a visitor may build in the Kaleidoscope during the tour",
		core.is_protected({ x = kal.min[1] + 1, y = kal.min[2] + 1, z = kal.min[3] + 1 }, "visitor") == false)
	local sh = live("screw_hall").region
	check("tour: but not in regions the tour does not visit",
		core.is_protected({ x = sh.min[1] + 1, y = sh.min[2] + 1, z = sh.min[3] + 1 }, "visitor") == true)
	cm.tour_state["visitor"] = nil

	-- Teacher view lists the student who answered questions.
	local listed = false
	for _, r in ipairs(cm.class_rows()) do if r.name == "student" and r.tier == 1 then listed = true end end
	check("teacher class view lists students with their tier", listed)

	-- Progress board: lists the gate for a tier-0 player and has a button to go there.
	local fs = cm.board_formspec("newbie")
	check("progress board offers a button to the Symmetry Gate", fs:find("go_symmetry_gate", 1, true) ~= nil)

	-- Quiz window: a wrong option is greyed out and the hint shown.
	local q1 = L.questions(content.gate, 0)[1]
	local qfs = cm.quiz_formspec(q1, { wrong = { [0] = true }, feedback = "Not quite. " .. q1.hint })
	check("quiz window greys out a wrong option and shows the hint",
		qfs:find("not this one", 1, true) ~= nil and qfs:find("opt_0", 1, true) == nil and qfs:find("mirror image", 1, true) ~= nil)

	-- Review questions: /quiz in a place with nothing open at the player's tier asks one of its
	-- questions from that tier or below, and answering it changes nothing that is stored.
	do
		local pending = cm.pending_question
		local function submit(who, fields)
			local fake = { get_player_name = function() return who end }
			for _, f in ipairs(core.registered_on_player_receive_fields) do
				local ok, handled = pcall(f, fake, "crystalminer:quiz", fields)
				if not ok then return false, handled end
				if handled then return true end
			end
			return true
		end
		local who = "reviewer"
		local rp = cm.progress(who)
		rp.tier = 4
		cm.save_progress(who)
		cm.current_area[who] = content.gate.id
		local stored = cm.storage:get_string("progress:" .. who)
		local rec = core.serialize(cm.record(who))
		cm.show_quiz(who)
		local st = pending[who]
		check("review: a tier-4 player in Gallery 1 gets a Gate question as a review",
			st and st.review == true and st.id:find("^symmetry_gate%.0%.") ~= nil, st and st.id)
		local q = st and L.question(content, st.id)
		check("review: the quiz window says it does not change the tier",
			q and cm.quiz_formspec(q, st):find(content.quiz_review.label, 1, true) ~= nil)
		local first = st and st.id
		pending[who] = nil
		cm.show_quiz(who, true)
		check("review: not offered right after a correct answer (the player is told where to go instead)",
			pending[who] == nil)
		pending[who] = st
		cm.show_quiz(who)
		check("review: /quiz again shows a different question", pending[who] and pending[who].id ~= first,
			pending[who] and pending[who].id)
		st = pending[who]
		q = st and L.question(content, st.id)
		local wrong = q and (q.answer + 1) % #q.options
		local ok1, err1 = submit(who, { ["opt_" .. tostring(wrong)] = "x" })
		check("review: a wrong answer greys out the option and shows the hint", ok1 and pending[who] == st
			and st.review == true and st.wrong[wrong] == true and (st.feedback or ""):find(q.hint, 1, true) ~= nil, tostring(err1))
		local ok2, err2 = submit(who, { ["opt_" .. tostring(q and q.answer)] = "x" })
		check("review: a right answer closes the question", ok2 and pending[who] == nil, tostring(err2))
		check("review: answering leaves the tier and the answered questions unchanged",
			rp.tier == 4 and next(rp.answered) == nil and cm.progress(who).tier == 4, tostring(rp.tier))
		check("review: nothing stored changes (progress, learning record)",
			cm.storage:get_string("progress:" .. who) == stored and core.serialize(cm.record(who)) == rec)
		check("review: answer() still refuses a question below the tier", cm.answer(who, first, L.question(content, first).answer) == false
			and next(rp.answered) == nil and rp.tier == 4)

		-- No spoilers: a tier-2 player in Mirror Plaza (questions at tiers 1 and 3) reviews only tier 1.
		local w2 = "reviewer2"
		cm.progress(w2).tier = 2
		cm.current_area[w2] = "mirror_plaza"
		local tiers_ok, n = true, #L.questions(L.area(content, "mirror_plaza"), 1)
		for _ = 1, 2 * n + 1 do
			cm.show_quiz(w2)
			local s = pending[w2]
			if not (s and s.review and s.id:find("^mirror_plaza%.1%.")) then tiers_ok = false end
		end
		check("review: never a question above the player's tier", tiers_ok)
		cm.current_area[w2] = ""
		pending[w2] = nil
		cm.show_quiz(w2)
		check("review: outside any place, /quiz still only lists where questions wait", pending[w2] == nil)

		-- A tier-0 player in Gallery 1 still gets the normal first Gate question.
		local w0 = "gate_newbie"
		cm.current_area[w0] = content.gate.id
		cm.show_quiz(w0)
		check("review: a tier-0 player still gets the normal Gate question", pending[w0] and not pending[w0].review
			and pending[w0].id == L.questions(content.gate, 0)[1].id, pending[w0] and pending[w0].id)
		for _, w in ipairs({ who, w2, w0 }) do pending[w] = nil; cm.current_area[w] = nil end
	end

	-- Free Lab: a hexagonal group is refused, 4mm is applied.
	local lab = live("free_lab")
	cm.apply_symmetry("teacher_test", lab, "6mm")
	check("free lab refuses 6mm", lab.symbol == "1", lab.symbol)
	cm.apply_symmetry("teacher_test", lab, "4mm")
	check("free lab accepts 4mm", lab.symbol == "4mm" and #lab.region.group.ops == 8, lab.symbol)

	-- Symmetry markers: one endless particle spawner per dot, added and deleted only on change.
	-- The engine call is real here once; for the rest the spawner functions are swapped for counters. For a player who is not here, 5.4 and 5.6 fail with -1 (seen as 4294967295), while 5.17 hands out an id and sends nothing. Either way spawner_ok must tell the two apart (see test_elements.lua).
	local kl = live("kaleidoscope")
	local probe = cm.E.marker_def(kl.dots[1], nil)
	local real = core.add_particlespawner(probe)
	check("markers: the engine accepts the spawner definition", cm.E.spawner_ok(real), tostring(real))
	if cm.E.spawner_ok(real) then core.delete_particlespawner(real) end
	local absent = core.add_particlespawner(cm.E.marker_def(kl.dots[1], "nobody_here"))
	check("markers: a spawner for a player who is not here is a failure or a new id",
		absent == 4294967295 or absent == -1 or (cm.E.spawner_ok(absent) and absent ~= real), tostring(absent))
	if cm.E.spawner_ok(absent) then core.delete_particlespawner(absent) end
	local api, shown, adds, defs_ok = cm.marker_api, {}, 0, true
	local saved_add, saved_delete = api.add, api.delete
	local function count() local n = 0 for _ in pairs(shown) do n = n + 1 end return n end
	api.add = function(def)
		adds = adds + 1
		defs_ok = defs_ok and def.playername == "markers" and def.time == 0 and def.minpos == def.maxpos
		shown[adds] = def
		return adds
	end
	api.delete = function(id, name)
		defs_ok = defs_ok and name == "markers" and shown[id] ~= nil
		shown[id] = nil
	end
	local elements = core.registered_chatcommands["elements"].func
	cm.progress("markers").tier = #content.tiers + 1
	cm.sync_markers("markers", kl)
	check("markers: entering the Kaleidoscope shows one spawner per dot", count() == #kl.dots and #kl.dots > 1000,
		count() .. " of " .. #kl.dots)
	for _ = 1, 10 do cm.sync_markers("markers", kl) end
	check("markers: staying sends nothing more", adds == #kl.dots, tostring(adds))
	local axes = 0
	for _, d in ipairs(kl.dots) do if d.kind == "axes" then axes = axes + 1 end end
	elements("markers", "axes")
	cm.sync_markers("markers", kl)
	check("markers: /elements axes keeps only the axes", count() == axes and adds == #kl.dots, count() .. " of " .. axes)
	elements("markers", "none")
	cm.sync_markers("markers", kl)
	check("markers: /elements none removes them all", count() == 0 and cm.markers.markers == nil, tostring(count()))
	elements("markers", "all")
	cm.sync_markers("markers", kl)
	check("markers: /elements all brings them back", count() == #kl.dots, tostring(count()))
	cm.sync_markers("markers", live("translation_hall"))
	check("markers: another region replaces them", count() == #live("translation_hall").dots, tostring(count()))
	cm.sync_markers("markers", nil)
	check("markers: leaving removes them all", count() == 0 and cm.markers.markers == nil, tostring(count()))
	local exhibit_live = cm.exhibit_live_at({x=-220, y=3, z=-7})
	cm.sync_markers("markers", exhibit_live)
	check("markers: entering an exhibit shows every exhibit dot", exhibit_live
		and count() == #exhibit_live.dots,
		tostring(count()) .. " of " .. tostring(exhibit_live and #exhibit_live.dots or 0))
	cm.sync_markers("markers", nil)
	check("markers: leaving an exhibit removes its dots", count() == 0 and cm.markers.markers == nil, tostring(count()))
	cm.sync_markers("newbie", kl)
	check("markers: a locked region shows none", count() == 0 and cm.markers.newbie == nil, tostring(count()))
	check("markers: every spawner was for the player, endless, at one point", defs_ok)
	api.add, api.delete = saved_add, saved_delete

	-- One window at a time: a guide waits for the pre-test, then shows for where the player is.
	do
		local who, shown = "queuetester", {}
		local function show(n, id) shown[#shown + 1] = id end
		local saved_due = cm.pretest_due
		local qp = cm.progress(who)
		qp.guided = {}
		cm.guide_enqueue(who, "symmetry_gate", 100)
		cm.guide_enqueue(who, "tryit_pad", 100)
		check("guide queue: nothing before the delay", select(2, cm.guide_flush(who, "tryit_pad", 100.5, show)) == "wait")
		cm.pretest_due = function() return true end
		check("guide queue: waits while the pre-test is due", select(2, cm.guide_flush(who, "tryit_pad", 102, show)) == "busy")
		cm.pretest_due = function() return false end
		cm.note_window(who, "crystalminer:test", "formspec_version[4]size[1,1]")
		check("guide queue: waits while a crystalminer window is open", cm.window_open(who) == "crystalminer:test"
			and select(2, cm.guide_flush(who, "tryit_pad", 102, show)) == "busy")
		cm.note_window_closed(who, "crystalminer:test")
		qp.guided = { symmetry_gate = true, tryit_pad = true }
		local id = cm.guide_flush(who, "tryit_pad", 102, show)
		check("guide queue: after the window closes, the guide for where the player is", id == "tryit_pad"
			and #shown == 1 and shown[1] == "tryit_pad", tostring(id))
		check("guide queue: the skipped place shows on the next arrival", qp.guided.symmetry_gate == nil
			and qp.guided.tryit_pad == true)
		check("guide queue: empty afterwards", select(2, cm.guide_flush(who, "tryit_pad", 103, show)) == "empty")
		cm.note_window(who, "crystalminer:quiz", "x")
		cm.note_window(who, "crystalminer:quiz", "")
		check("window tracking: show_formspec with \"\" closes", cm.window_open(who) == nil)
		cm.note_window(who, "other_mod:thing", "x")
		check("window tracking: other mods' windows are not tracked", cm.window_open(who) == nil)
		-- The quit the engine sends reaches the tracker even though other handlers return true.
		cm.note_window(who, "crystalminer:guide", "x")
		local fake = { get_player_name = function() return who end }
		for _, f in ipairs(core.registered_on_player_receive_fields) do
			local ok, handled = pcall(f, fake, "crystalminer:guide", { quit = "true" })
			if not ok or handled then break end
		end
		check("window tracking: a quit closes the window", cm.window_open(who) == nil)
		cm.pretest_due = saved_due
	end

	-- The "Next:" line, from fake progress tables.
	do
		local H = cm.next_hint
		local function prog(tier)
			local p = { tier = tier, answered = {}, visited = { tryit_pad = true } }
			for t = 0, tier - 1 do
				for _, q in ipairs(L.questions_for_tier(content, t)) do p.answered[q.id] = true end
			end
			return p
		end
		check("next hint: new player", H.text(content, L, prog(0), "") == "Next: answer the quiz in Gallery 1 (type /quiz there)")
		local t1 = H.text(content, L, prog(1), "")
		check("next hint: tier 1 goes to a world", t1 == "Next: go to the Portal Hall and open Mirror Plaza", t1)
		check("next hint: in a world with open questions", H.text(content, L, prog(1), "mirror_plaza") == "Next: build here, then type /quiz")
		local done = prog(L.max_tier(content))
		for _, q in ipairs(L.questions_for_tier(content, done.tier)) do done.answered[q.id] = true end
		check("next hint: all done", H.text(content, L, done, "") == "You have finished every tier. Try the Free Lab or /tour.")
		local np = prog(1)
		np.visited = nil
		check("next hint: suggests the Try-it Pad until visited", (H.text(content, L, np, "") or ""):find("Try-it Pad", 1, true) ~= nil)
	end

	-- Sounds (on by default): every node of the game has footstep, dig, dug and place sounds, and
	-- each named sound has a file (name.ogg or one of the variants name.1.ogg ...). With
	-- crystalminer.sounds = false (CM_EXTRA_CONF='crystalminer.sounds = false'): none at all.
	if not core.settings:get_bool("crystalminer.sounds", true) then
		local with = {}
		for name, def in pairs(core.registered_nodes) do
			if name:find("^crystalminer:") and def.sounds and next(def.sounds) then with[#with + 1] = name end
		end
		check("sounds off: no crystalminer node has sounds", #with == 0, table.concat(with, ", ", 1, math.min(#with, 8)))
		check("sounds off: the jump sound was not added", cm.jump_sound.added == false, tostring(cm.jump_sound.added))
	else
		local dir = core.get_modpath("crystalminer") .. "/sounds/"
		local function has_file(sname)
			for _, suffix in ipairs({ "", ".1", ".2", ".3" }) do
				local f = io.open(dir .. sname .. suffix .. ".ogg", "rb")
				if f then f:close(); return true end
			end
			return false
		end
		local missing, nodes = {}, 0
		for name, def in pairs(core.registered_nodes) do
			if name:find("^crystalminer:") then
				nodes = nodes + 1
				local s = def.sounds or {}
				for _, key in ipairs({ "footstep", "dig", "dug", "place", "place_failed" }) do
					local spec = s[key]
					if type(spec) ~= "table" or not spec.name or spec.name == "" then
						missing[#missing + 1] = name .. " " .. key
					elseif not has_file(spec.name) then
						missing[#missing + 1] = name .. " " .. key .. " file " .. spec.name
					end
				end
			end
		end
		table.sort(missing)
		check("sounds: every crystalminer node (" .. nodes .. ") has footstep, dig, dug, place sounds with files",
			nodes > 30 and #missing == 0, table.concat(missing, ", ", 1, math.min(#missing, 8)))
		-- Checked from Luanti 5.5 on; with older engines (untested) a missing jump sound is only noted.
		results[#results + 1] = "info  jump sound added: " .. tostring(cm.jump_sound.added)
		if core.features.dynamic_add_media_table then
			check("sounds: the jump sound was added", cm.jump_sound.added ~= false, tostring(cm.jump_sound.added))
		end
		core.settings:set_bool("crystalminer.sounds", false)
		local off = cm.node_sounds("hard")
		core.settings:set_bool("crystalminer.sounds", true)
		check("sounds: switched off, a node gets no sounds", next(off) == nil)
	end

	local out = io.open(core.get_worldpath() .. "/crystalminer_selftest.txt", "w")
	out:write(table.concat(results, "\n") .. "\n" .. (failures == 0 and "PASS" or ("FAILURES " .. failures)) .. "\n")
	out:close()
	core.request_shutdown()
end

-- A visitor who joins while the world is being built: the engine emerges the map around them in
-- requests of its own, at the same time as the build's. With several emerge threads (Luanti picks
-- up to 4 for a singlenode map) such a request could still be generating part of the museum when
-- the build ran, and then overwrote it.
-- Like a client, it asks for one block at a time, nearest first, while the build's requests are
-- still queued.
local visitor_blocks = {}
for bx = -7, 7 do
	for bz = -7, 7 do
		for _, by in ipairs({ -2, 2 }) do visitor_blocks[#visitor_blocks + 1] = { x = bx, y = by, z = bz } end
	end
end
table.sort(visitor_blocks, function(a, b) return a.x * a.x + a.y * a.y + a.z * a.z < b.x * b.x + b.y * b.y + b.z * b.z end)
local visitor_next = 1
-- The visitor arrives once this share of the build's blocks has come back: then its requests can
-- start a chunk of the museum that the build is still waiting for (with 4 emerge threads and no
-- retries, this cut the museum's north-east chunk in 2 of 12 runs).
local VISITOR_AFTER = tonumber(core.settings:get("crystalminer.selftest_visitor_after") or "") or 0.8
core.register_globalstep(function()
	local st = cm.emerge_stats
	if not st or not st.total then return end
	local done = 0
	for k, v in pairs(st) do if type(k) == "number" then done = done + v end end
	if done < VISITOR_AFTER * st.total then return end
	for _ = 1, 400 do
		local b = visitor_blocks[visitor_next]
		if not b then return end
		visitor_next = visitor_next + 1
		local p = { x = b.x * 16, y = b.y * 16, z = b.z * 16 - 44 }
		core.emerge_area(p, p)
	end
end)

cm.when_exhibits_ready(function()
	-- Signs placed while the world was built are stored in the map until a player comes near.
	-- Keep the places the checks look at loaded, so their signs wake up as they would for a player.
	local spots = { { x = 0, y = 5, z = -30 } }
	for _, d in ipairs(cm.G.displays(content.gate.at)) do spots[#spots + 1] = { x = d.look_at.x, y = 7, z = -30 } end
	spots[#spots + 1] = { x = cm.PAD_BUILD.x - 2, y = 4, z = cm.PAD_BUILD.z }
	spots[#spots + 1] = { x = 40, y = 9, z = -49 }   -- Prism's billboard
	for _, live in ipairs(cm.regions) do
		local pl = cm.D.plaza(live.region)
		spots[#spots + 1] = { x = pl.arrive.x, y = 8, z = pl.arch_z }
	end
	for _, p in ipairs(spots) do core.forceload_block(p, true) end
	core.after(4, function()
		local ok, err = pcall(run)
		if not ok then
			local out = io.open(core.get_worldpath() .. "/crystalminer_selftest.txt", "w")
			out:write("ERROR " .. tostring(err) .. "\n")
			out:close()
			core.request_shutdown()
		end
	end)
end)
