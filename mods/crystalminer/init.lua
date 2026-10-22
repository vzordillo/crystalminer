-- crystalminer: learn symmetry by building in regions that copy everything you place.

local modpath = core.get_modpath("crystalminer")
local S = dofile(modpath .. "/symmetry.lua")
local L = dofile(modpath .. "/lessons.lua")
local content = dofile(modpath .. "/content.lua")
local E = loadfile(modpath .. "/elements.lua")(S)
local G = loadfile(modpath .. "/gate.lua")(S)
local D = dofile(modpath .. "/decor.lua")
local Tutor = loadfile(modpath .. "/tutor.lua")(S, content)

-- Must be requested at load time; only granted if the server lists crystalminer in secure.http_mods.
local http = core.request_http_api and core.request_http_api()

local storage = core.get_mod_storage()
-- Raise this when the built world changes; existing worlds are then rebuilt on start.
local WORLD_VERSION = "21"
local GROUND_Y = 0
local SPAWN = content.lobby.spawn
local LABEL_RANGE = 30

crystalminer = { S = S, L = L, G = G, content = content, storage = storage, http = http }
local cm = crystalminer
dofile(modpath .. "/sounds.lua") -- before the nodes: they take their sounds from cm.node_sounds

-- Hooks the feature modules (learning.lua, museum.lua, reach.lua) fill in. Each is optional.
--   cm.on_place(name, pos, node) -> true when the module handles the copies itself
--   cm.on_dig(name, pos) ; cm.on_join(name) ; cm.on_levelled(name) ; cm.on_area(name, id, live)
--   cm.unlock_override(name, live) -> true lets a player build in a region above their tier
--   cm.on_build() runs after the world is built; cm.on_teleport(name, id, player) -> true when the
--   module knows the destination id. cm.extra_boxes: areas a module builds on, { min, size }; they
--   are generated with the map and kept clear of scenery. cm.labels: nearby labels, { key, text, pos }.
local function hook(list_name, ...)
	for _, f in ipairs(cm[list_name] or {}) do
		local r = f(...)
		if r then return r end
	end
end
cm.hook = hook
for _, h in ipairs({ "on_place", "on_dig", "on_join", "on_levelled", "on_area", "unlock_override", "on_build",
	"on_teleport", "before_build", "on_clear" }) do cm[h] = {} end
cm.extra_boxes = {}

-- Set below, once regions exist; used by the block callbacks.
local region_at, place_in_air

---------------------------------------------------------------------------- nodes

local COLOURS = {
	"white", "light_grey", "grey", "black", "brown", "red", "orange", "yellow",
	"lime", "green", "cyan", "light_blue", "blue", "purple", "magenta", "pink",
}
-- Order in the inventory: bright colours first, so the first block stands out on the pale floor.
local INVENTORY_ORDER = {
	"red", "orange", "yellow", "lime", "green", "cyan", "blue", "purple",
	"magenta", "pink", "light_blue", "brown", "black", "grey", "light_grey", "white",
}

local function title_case(s)
	return (s:gsub("_", " "):gsub("^%l", string.upper))
end

local function air_place(itemstack, user)
	if place_in_air then place_in_air(itemstack, user) end
end

local buildable = {}
for _, c in ipairs(COLOURS) do
	core.register_node("crystalminer:" .. c, {
		description = title_case(c) .. " block",
		tiles = { "crystalminer_" .. c .. ".png" },
		groups = { dig_immediate = 3, crystalminer_block = 1 },
		is_ground_content = false,
		sounds = cm.node_sounds("hard"),
		on_secondary_use = air_place,
	})
end
for _, c in ipairs(INVENTORY_ORDER) do buildable[#buildable + 1] = "crystalminer:" .. c end
core.register_node("crystalminer:glass", {
	description = "Glass",
	drawtype = "glasslike",
	tiles = { "crystalminer_glass.png" },
	use_texture_alpha = "blend",
	paramtype = "light",
	sunlight_propagates = true,
	groups = { dig_immediate = 3, crystalminer_block = 1 },
	is_ground_content = false,
	sounds = cm.node_sounds("glass"),
	on_secondary_use = air_place,
})
buildable[#buildable + 1] = "crystalminer:glass"

-- Scenery players cannot dig (no dig groups). Sounds of hard stone unless extra.sounds says otherwise.
local function scenery(name, desc, tile, extra)
	local def = { description = desc, tiles = { tile }, groups = { not_in_creative_inventory = 1 }, is_ground_content = false,
		sounds = cm.node_sounds("hard") }
	for k, v in pairs(extra or {}) do def[k] = v end
	core.register_node("crystalminer:" .. name, def)
end
scenery("ground", "Ground", "crystalminer_ground.png", { sounds = cm.node_sounds("soft") })
scenery("dirt", "Dirt", "crystalminer_dirt.png", { sounds = cm.node_sounds("soft") })
scenery("floor", "Region floor", "crystalminer_floor.png")
scenery("floor_alt", "Region floor", "crystalminer_floor_alt.png")
for i = 0, 4 do scenery("border_" .. i, "Tier " .. i .. " border", "crystalminer_border_" .. i .. ".png") end
scenery("frame", "Region frame", "crystalminer_frame.png", {
	sounds = cm.node_sounds("glass"), drawtype = "glasslike", use_texture_alpha = "blend", paramtype = "light", sunlight_propagates = true,
})

-- Architecture and scenery (see decor.lua). None of it can be dug.
for _, n in ipairs({ "path", "brick", "stone_brick", "plaza", "pillar" }) do
	scenery(n, title_case(n), "crystalminer_" .. n .. ".png")
end
for _, n in ipairs({ "planks", "bark" }) do
	scenery(n, title_case(n), "crystalminer_" .. n .. ".png", { sounds = cm.node_sounds("wood") })
end
scenery("hedge", "Hedge", "crystalminer_hedge.png", { drawtype = "allfaces_optional", paramtype = "light",
	sounds = cm.node_sounds("soft") })
scenery("leaves", "Leaves", "crystalminer_leaves.png", { drawtype = "allfaces_optional", paramtype = "light",
	sounds = cm.node_sounds("soft") })
scenery("lamp", "Lamp", "crystalminer_lamp.png", { paramtype = "light", light_source = 13 })
scenery("roof_glass", "Roof glass", "crystalminer_glass.png", {
	sounds = cm.node_sounds("glass"), drawtype = "glasslike", use_texture_alpha = "blend", paramtype = "light", sunlight_propagates = true,
})
scenery("fence", "Fence", "crystalminer_planks.png", {
	sounds = cm.node_sounds("wood"), drawtype = "nodebox", paramtype = "light", sunlight_propagates = true,
	node_box = {
		type = "connected",
		fixed = { -0.125, -0.5, -0.125, 0.125, 0.5, 0.125 },
		connect_front = { { -0.0625, 0.125, -0.5, 0.0625, 0.3125, -0.125 }, { -0.0625, -0.3125, -0.5, 0.0625, -0.125, -0.125 } },
		connect_back = { { -0.0625, 0.125, 0.125, 0.0625, 0.3125, 0.5 }, { -0.0625, -0.3125, 0.125, 0.0625, -0.125, 0.5 } },
		connect_left = { { -0.5, 0.125, -0.0625, -0.125, 0.3125, 0.0625 }, { -0.5, -0.3125, -0.0625, -0.125, -0.125, 0.0625 } },
		connect_right = { { 0.125, 0.125, -0.0625, 0.5, 0.3125, 0.0625 }, { 0.125, -0.3125, -0.0625, 0.5, -0.125, 0.0625 } },
	},
	connects_to = { "crystalminer:fence", "crystalminer:planks" },
})
for _, f in ipairs({ "flower_pink", "flower_blue", "flower_white" }) do
	scenery(f, "Flower", "crystalminer_" .. f .. ".png", {
		sounds = cm.node_sounds("soft"), drawtype = "plantlike", paramtype = "light", sunlight_propagates = true, walkable = false,
		selection_box = { type = "fixed", fixed = { -0.25, -0.5, -0.25, 0.25, 0.2, 0.25 } },
	})
end
for _, c in ipairs({ "cyan", "purple", "pink" }) do
	scenery("crystal_" .. c, "Crystal cluster", "crystalminer_crystal_" .. c .. ".png", {
		sounds = cm.node_sounds("glass"), drawtype = "plantlike", paramtype = "light", sunlight_propagates = true, walkable = false,
		use_texture_alpha = "blend", light_source = 6,
	})
	scenery("crystal_block_" .. c, "Crystal", "crystalminer_crystal_block_" .. c .. ".png", {
		sounds = cm.node_sounds("glass"), drawtype = "glasslike", paramtype = "light", sunlight_propagates = true, use_texture_alpha = "blend",
		light_source = 5,
	})
end

core.register_item(":", {
	type = "none",
	wield_image = "crystalminer_hand.png",
	wield_scale = { x = 1, y = 1, z = 2.5 },
	range = 12,
	tool_capabilities = {
		full_punch_interval = 0.3,
		max_drop_level = 0,
		groupcaps = { dig_immediate = { times = { [3] = 0 }, uses = 0, maxlevel = 1 } },
	},
})

core.register_alias("mapgen_stone", "crystalminer:dirt")
core.register_alias("mapgen_water_source", "crystalminer:glass")
core.register_alias("mapgen_river_water_source", "crystalminer:glass")

---------------------------------------------------------------------------- flat world

core.set_mapgen_setting("mg_name", "singlenode", true)

local c_ground = core.get_content_id("crystalminer:ground")
local c_dirt = core.get_content_id("crystalminer:dirt")

core.register_on_generated(function(minp, maxp)
	if minp.y > GROUND_Y then return end
	local vm, emin, emax = core.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
	local data = vm:get_data()
	for z = minp.z, maxp.z do
		for y = minp.y, math.min(maxp.y, GROUND_Y) do
			local vi = area:index(minp.x, y, z)
			local id = (y == GROUND_Y) and c_ground or c_dirt
			for _ = minp.x, maxp.x do
				data[vi] = id
				vi = vi + 1
			end
		end
	end
	vm:set_data(data)
	vm:calc_lighting()
	vm:write_to_map()
end)

---------------------------------------------------------------------------- regions

-- Live regions: area (from content), engine region, dots to draw, symbol shown.
local regions = {}

--- HUD texture of the stereogram of a region's point group (its crystal class for a lattice):
-- poles of one general direction under every operation, seen from above with north up.
-- Drawn as in International Tables (stereo.lua): copies of a general point as dots (above) and
-- rings (below), axis symbols, and mirror planes as lines.
local P = dofile(modpath .. "/stereo.lua")
local function stereogram_texture(region)
	return P.texture(P.marks(S, S.crystal_ops(region.group)), 128)
end
crystalminer.stereogram_texture = stereogram_texture

local function set_symmetry(live, symbol, generators)
	live.region = S.region(L.region_spec(live.area, generators))
	live.symbol = symbol
	live.dots = live.area.hidden and {} or E.dots(live.region)
	live.stereogram = (not live.area.hidden) and stereogram_texture(live.region) or nil
end

for _, a in ipairs(content.regions) do
	local live = { area = a }
	set_symmetry(live, a.symbol, a.generators)
	regions[#regions + 1] = live
end
crystalminer.regions = regions
function crystalminer.live_by_id(id)
	for _, live in ipairs(regions) do if live.area.id == id then return live end end
	return nil
end

region_at = function(pos)
	for _, live in ipairs(regions) do
		if S.contains_pos(live.region, pos.x, pos.y, pos.z) then return live end
	end
end

--- The region a player is in or standing next to. Without a margin: the region whose world
-- (the region, its plaza, gate and landscape) the player is in.
local world_box_of
local function region_near(pos, margin)
	if not margin and world_box_of then
		for _, live in ipairs(regions) do
			local b = world_box_of(live)
			if pos.x >= b.min[1] and pos.x < b.min[1] + b.size[1] and pos.z >= b.min[3] and pos.z < b.min[3] + b.size[3] then
				return live
			end
		end
		return nil
	end
	margin = margin or 2
	for _, live in ipairs(regions) do
		local r = live.region
		if pos.x >= r.min[1] - margin - 0.5 and pos.x <= r.min[1] + r.size[1] + margin - 0.5
			and pos.y >= r.min[2] - margin - 2 and pos.y <= r.min[2] + r.size[2] + margin
			and pos.z >= r.min[3] - margin - 0.5 and pos.z <= r.min[3] + r.size[3] + margin - 0.5 then
			return live
		end
	end
end

local function near_gate(pos)
	local b = G.box(content.gate.at)
	-- The displays and the floor in front of them, where visitors stand to look (to Gallery 1's north wall).
	return pos.x >= b.min[1] and pos.x <= b.min[1] + b.size[1] and pos.z >= b.min[3] - 1 and pos.z <= b.min[3] + b.size[3] + 15
end

---------------------------------------------------------------------------- the Try-it Pad

-- A glass-edged box to build in (east, on the player's left), a result box (west) and four levers.
local PAD = content.tryit
local PAD_BUILD = { x = PAD.at[1] + 8, y = PAD.at[2], z = PAD.at[3] }
local PAD_RESULT = { x = PAD.at[1], y = PAD.at[2], z = PAD.at[3] }
local PAD_SIZE = 5
local LEVERS = {
	{ letter = "T", op = "translation", text = "T: slide", does = "slides your shape along, without turning it",
		w = { 1, 1, 1 }, x = PAD.at[1] + 9 },
	{ letter = "R", op = "rotation", text = "R: turn half a turn", does = "turns your shape half a turn",
		w = { -1, 1, -1 }, x = PAD.at[1] + 7 },
	{ letter = "M", op = "reflection", text = "M: mirror", does = "makes the mirror image of your shape",
		w = { -1, 1, 1 }, x = PAD.at[1] + 5 },
	{ letter = "I", op = "inversion", text = "I: through the centre",
		does = "sends every block of your shape through its centre point to the opposite side",
		w = { -1, -1, -1 }, x = PAD.at[1] + 3 },
}
local LEVER_Z = PAD.at[3] + 7

local function in_box(pos, corner)
	return pos.x >= corner.x and pos.x < corner.x + PAD_SIZE and pos.y >= corner.y and pos.y < corner.y + PAD_SIZE
		and pos.z >= corner.z and pos.z < corner.z + PAD_SIZE
end

local function near_pad(pos)
	return pos.x >= PAD.at[1] - 3 and pos.x <= PAD.at[1] + 16 and pos.z >= PAD.at[3] - 3 and pos.z <= PAD.at[3] + 11
end

--- Nodes built in the pad's build box, as doubled-coordinate keys for S.detect, and as a list.
local function pad_build()
	local keys, list = {}, {}
	for dx = 0, PAD_SIZE - 1 do
		for dy = 0, PAD_SIZE - 1 do
			for dz = 0, PAD_SIZE - 1 do
				local p = { x = PAD_BUILD.x + dx, y = PAD_BUILD.y + dy, z = PAD_BUILD.z + dz }
				local n = core.get_node(p).name
				if n ~= "air" and n ~= "ignore" then
					keys[(2 * p.x + 1) .. "," .. (2 * p.y + 1) .. "," .. (2 * p.z + 1)] = n
					list[#list + 1] = { d = { dx - 2, dy - 2, dz - 2 }, name = n }
				end
			end
		end
	end
	return keys, list
end

--- Applies a lever to the build: clears the result box and draws the image. Returns whether the
-- build was empty and whether the result can be matched to the build by a proper motion.
local function apply_lever(lever)
	local keys, list = pad_build()
	for dx = 0, PAD_SIZE - 1 do
		for dy = 0, PAD_SIZE - 1 do
			for dz = 0, PAD_SIZE - 1 do
				core.set_node({ x = PAD_RESULT.x + dx, y = PAD_RESULT.y + dy, z = PAD_RESULT.z + dz }, { name = "air" })
			end
		end
	end
	if #list == 0 then return true end
	for _, e in ipairs(list) do
		core.set_node({
			x = PAD_RESULT.x + 2 + lever.w[1] * e.d[1],
			y = PAD_RESULT.y + 2 + lever.w[2] * e.d[2],
			z = PAD_RESULT.z + 2 + lever.w[3] * e.d[3],
		}, { name = e.name })
	end
	local improper = lever.w[1] * lever.w[2] * lever.w[3] < 0
	if not improper then return false, true end
	-- A mirror image matches the original only if the build has an improper symmetry of its own.
	local g = S.detect(keys)
	for _, o in ipairs(g.ops) do
		if S.det(o) < 0 then return false, true end
	end
	return false, false
end
crystalminer.apply_lever = apply_lever
crystalminer.LEVERS = LEVERS
crystalminer.PAD_BUILD, crystalminer.PAD_RESULT = PAD_BUILD, PAD_RESULT
crystalminer.LEVER_Z = LEVER_Z

local pending_lever = {}

local function show_prediction(name, lever)
	-- Ask only once there is something to apply the lever to.
	local _, list = pad_build()
	if #list == 0 then
		crystalminer.say(name, "First build a shape in the glass box on the left, marked YOUR SHAPE: pick a block with keys 1 to 8 "
			.. "and right-click inside the box. Then hit a lever again.", "#FFFF60")
		return
	end
	pending_lever[name] = lever
	core.show_formspec(name, "crystalminer:predict", "formspec_version[4]size[12,5]position[0.5,0.97]anchor[0.5,1]"
		.. "bgcolor[#1E2433E6;false]"
		.. "textarea[0.4,0.4;11.2,2.4;;;" .. core.formspec_escape("Lever " .. lever.letter .. " " .. lever.does
			.. ". The copy will appear in the box on the right, marked COPY.\n\nGuess first: if you could pick the copy up "
			.. "and turn it any way you like, could you make it look exactly like your shape?") .. "]"
		.. "button[0.4,3;5.5,0.9;yes;Yes, I could turn it to match]button[6.1,3;5.5,0.9;no;No, it could never match]"
		.. "label[0.4,4.4;" .. core.formspec_escape("Then look at the COPY box to check.") .. "]")
end

for _, lever in ipairs(LEVERS) do
	scenery("lever_" .. lever.letter, lever.text, "crystalminer_lever_" .. lever.letter .. ".png", {
		paramtype = "light", light_source = 4,
		on_punch = function(_, _, puncher)
			if puncher and puncher:is_player() then show_prediction(puncher:get_player_name(), lever) end
		end,
		on_rightclick = function(_, _, clicker)
			if clicker and clicker:is_player() then show_prediction(clicker:get_player_name(), lever) end
		end,
	})
end

---------------------------------------------------------------------------- progress

local function load_progress(name)
	local s = storage:get_string("progress:" .. name)
	local p = s ~= "" and core.deserialize(s) or nil
	return p or L.new_progress()
end

local progress_cache = {}

local function progress(name)
	if not progress_cache[name] then progress_cache[name] = load_progress(name) end
	return progress_cache[name]
end

local function save_progress(name)
	storage:set_string("progress:" .. name, core.serialize(progress(name)))
end

crystalminer.progress = progress

---------------------------------------------------------------------------- building

local function unlocked(name, live)
	return progress(name).tier >= live.area.tier or hook("unlock_override", name, live) == true
end

-- Regions above a player's tier are protected: they can look but not build.
local old_is_protected = core.is_protected
function core.is_protected(pos, name)
	local live = region_at(pos)
	if live and name ~= "" and not unlocked(name, live) then return true end
	return old_is_protected(pos, name)
end

core.register_on_protection_violation(function(pos, name)
	local live = region_at(pos)
	if live then
		core.chat_send_player(name, core.colorize("#FF6060", "Locked: reach tier " .. live.area.tier
			.. " to build in " .. live.area.name .. ". Type /quiz to progress."))
	end
end)

--- Moves any player whose body a new copy would trap up to the first free space above.
local function free_trapped_players(changed)
	for _, player in ipairs(core.get_connected_players()) do
		local p = vector.round(player:get_pos())
		local hit = changed[p.x .. "," .. p.y .. "," .. p.z] or changed[p.x .. "," .. (p.y + 1) .. "," .. p.z]
		if hit then
			for y = p.y + 1, p.y + 40 do
				local a = core.get_node({ x = p.x, y = y, z = p.z }).name
				local b = core.get_node({ x = p.x, y = y + 1, z = p.z }).name
				if a == "air" and b == "air" then
					player:set_pos({ x = player:get_pos().x, y = y, z = player:get_pos().z })
					break
				end
			end
		end
	end
end

local function copy_to_images(pos, node)
	local live = region_at(pos)
	if not live then return end
	local changed = {}
	for _, im in ipairs(S.images(live.region, pos.x, pos.y, pos.z)) do
		if im.x ~= pos.x or im.y ~= pos.y or im.z ~= pos.z then
			core.set_node({ x = im.x, y = im.y, z = im.z }, node)
			changed[im.x .. "," .. im.y .. "," .. im.z] = true
		end
	end
	if node.name ~= "air" then free_trapped_players(changed) end
end
crystalminer.copy_to_images = copy_to_images

core.register_on_placenode(function(pos, newnode, placer)
	local name = placer and placer:is_player() and placer:get_player_name()
	if name and hook("on_place", name, pos, { name = newnode.name }) then return true end
	copy_to_images(pos, { name = newnode.name })
	if name and crystalminer.sound then crystalminer.sound("crystalminer_copy", name) end
	-- Blocks are free: do not take the item from the stack.
	return true
end)

core.register_on_dignode(function(pos, _, digger)
	local name = digger and digger:is_player() and digger:get_player_name()
	if name and hook("on_dig", name, pos) then return end
	copy_to_images(pos, { name = "air" })
end)

--- Right-click with a block while pointing at nothing: place it 3 nodes in front of the eyes, if
-- that is inside a region (or the Try-it Pad's build box). Floating regions need this.
place_in_air = function(itemstack, user)
	if not user or not user:is_player() then return end
	local name = user:get_player_name()
	local eye = vector.add(user:get_pos(), { x = 0, y = user:get_properties().eye_height or 1.625, z = 0 })
	local p = vector.round(vector.add(eye, vector.multiply(user:get_look_dir(), 3)))
	if not region_at(p) and not in_box(p, PAD_BUILD) then return end
	if core.get_node(p).name ~= "air" then return end
	if core.is_protected(p, name) then
		core.record_protection_violation(p, name)
		return
	end
	local node = { name = itemstack:get_name() }
	core.set_node(p, node)
	if hook("on_place", name, p, node) then return end
	copy_to_images(p, node)
	if crystalminer.sound then crystalminer.sound("crystalminer_copy", name) end
end
crystalminer.place_in_air = place_in_air

-- Blocks are free, so digging does not put them into the inventory.
local old_handle_node_drops = core.handle_node_drops
function core.handle_node_drops(pos, drops, digger)
	if digger and digger:is_player() then return end
	return old_handle_node_drops(pos, drops, digger)
end

---------------------------------------------------------------------------- world construction

-- Earlier versions labelled regions with floating entities, which could be read from anywhere and
-- piled up on top of each other. Labels are now per-player HUD waypoints shown only nearby; any old
-- label entity removes itself when it loads.
core.register_entity("crystalminer:label", {
	initial_properties = { visual = "sprite", textures = { "crystalminer_blank.png" }, static_save = false, pointable = false },
	on_activate = function(self) self.object:remove() end,
})

local function fill(x0, x1, y0, y1, z0, z1, name)
	for x = x0, x1 do
		for y = y0, y1 do
			for z = z0, z1 do core.set_node({ x = x, y = y, z = z }, { name = name }) end
		end
	end
end

--- Edges of the box between two corners (inclusive), in frame nodes.
local function frame_edges(x0, x1, y0, y1, z0, z1)
	for x = x0, x1 do
		for y = y0, y1 do
			for z = z0, z1 do
				local n = ((x == x0 or x == x1) and 1 or 0) + ((y == y0 or y == y1) and 1 or 0) + ((z == z0 or z == z1) and 1 or 0)
				if n >= 2 then core.set_node({ x = x, y = y, z = z }, { name = "crystalminer:frame" }) end
			end
		end
	end
end

local function build_region(live)
	local r = live.region
	local border = "crystalminer:border_" .. math.min(live.area.tier, 4)
	for x = r.min[1] - 1, r.min[1] + r.size[1] do
		for z = r.min[3] - 1, r.min[3] + r.size[3] do
			local edge = x == r.min[1] - 1 or x == r.min[1] + r.size[1] or z == r.min[3] - 1 or z == r.min[3] + r.size[3]
			local floor = "crystalminer:floor"
			-- In lattice regions, alternate the floor tint cell by cell so the unit cells show.
			if r.cell and (math.floor((x - r.min[1]) / r.cell[1]) + math.floor((z - r.min[3]) / r.cell[3])) % 2 == 1 then
				floor = "crystalminer:floor_alt"
			end
			core.set_node({ x = x, y = GROUND_Y, z = z }, { name = edge and border or floor })
		end
	end
	if r.min[2] > GROUND_Y + 1 then
		frame_edges(r.min[1] - 1, r.min[1] + r.size[1], r.min[2] - 1, r.min[2] + r.size[2], r.min[3] - 1, r.min[3] + r.size[3])
	end
end

local function build_gate()
	local at = content.gate.at
	local b = G.box(at)
	-- Clear first: the layout changed between versions. The gate stands inside the museum, so its
	-- floor is the museum's.
	fill(b.min[1], b.min[1] + b.size[1] - 1, b.min[2], b.min[2] + b.size[2] - 1, b.min[3], b.min[3] + b.size[3] - 1, "air")
	fill(b.min[1], b.min[1] + b.size[1] - 1, GROUND_Y, GROUND_Y, b.min[3], b.min[3] + b.size[3] - 1, "crystalminer:plaza")
	for _, d in ipairs(G.displays(at)) do
		fill(d.floor[1], d.floor[2], GROUND_Y, GROUND_Y, d.floor[3], d.floor[4], "crystalminer:floor")
		local node = { name = "crystalminer:" .. d.colour }
		for _, p in ipairs(d.original) do core.set_node(p, node) end
		for _, p in ipairs(d.copy) do core.set_node(p, node) end
	end
end

local function build_pad()
	local at = PAD.at
	fill(at[1] - 2, at[1] + 14, GROUND_Y, GROUND_Y, at[3] - 2, at[3] + 9, "crystalminer:floor")
	fill(at[1] - 2, at[1] + 14, GROUND_Y + 1, GROUND_Y + 7, at[3] - 2, at[3] + 9, "air")
	for _, c in ipairs({ PAD_BUILD, PAD_RESULT }) do
		frame_edges(c.x - 1, c.x + PAD_SIZE, c.y - 1, c.y + PAD_SIZE, c.z - 1, c.z + PAD_SIZE)
	end
	for _, lever in ipairs(LEVERS) do
		core.set_node({ x = lever.x, y = GROUND_Y + 1, z = LEVER_Z }, { name = "crystalminer:lever_" .. lever.letter })
	end
end

--- Every decoration: each region's architecture and the landscape of its world.
local function decor_placements()
	local list = {}
	for _, live in ipairs(regions) do
		for _, p in ipairs(D.region(live.region, live.area.style)) do list[#list + 1] = p end
		for _, p in ipairs(D.island(live.region, live.area.style)) do list[#list + 1] = p end
	end
	return list
end

--- The part of the map one region's world uses (region, architecture, plaza and landscape).
local function world_box(live)
	local b = D.extent(live.region)
	local R = D.ISLAND_RADIUS + 6
	local cz = math.floor((b.z0 + b.z1) / 2)
	local z0 = math.min(cz - R, D.plaza(live.region).z0 - 4)
	return { min = { b.cx - R, GROUND_Y - 1, z0 }, size = { 2 * R + 1, b.y1 + 12, cz + R - z0 + 1 } }
end
cm.world_box = world_box
world_box_of = function(live)
	live.world_box = live.world_box or world_box(live)
	return live.world_box
end

local function build_decor(list)
	for _, p in ipairs(list) do
		core.set_node({ x = p.x, y = p.y, z = p.z }, { name = "crystalminer:" .. (p.n == "glass" and "roof_glass" or p.n) })
	end
end

local world_ready = false
local on_world_ready = {}

--- Fills a box with one node quickly, through a VoxelManip.
local function fill_fast(x0, x1, y0, y1, z0, z1, name)
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map({ x = x0, y = y0, z = z0 }, { x = x1, y = y1, z = z1 })
	local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
	local data = vm:get_data()
	local id = core.get_content_id(name)
	for z = z0, z1 do
		for y = y0, y1 do
			local vi = area:index(x0, y, z)
			for _ = x0, x1 do
				data[vi] = id
				vi = vi + 1
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
end
cm.fill_fast = fill_fast

local function build_world(decor)
	-- First clear what must be empty (the museum's volume), then build.
	for _, f in ipairs(cm.on_clear) do f() end
	build_decor(decor)
	-- The gate and the Try-it Pad first: the museum's walls are then built around them.
	build_gate()
	build_pad()
	for _, f in ipairs(cm.before_build) do f() end
	for _, live in ipairs(regions) do build_region(live) end
	for _, f in ipairs(cm.on_build) do f() end
	storage:set_string("world_version", WORLD_VERSION)
	world_ready = true
	for _, f in ipairs(on_world_ready) do f() end
end

-- Evidence for the self-test: a map chunk inside the built area that is generated after the build
-- started overwrites what the build put there (cm.emerge_stats.late counts them).
local built_boxes
core.register_on_generated(function(minp, maxp)
	if not built_boxes then return end
	for _, b in ipairs(built_boxes) do
		if maxp.x >= b.min[1] and minp.x < b.min[1] + b.size[1] and maxp.y >= b.min[2] and minp.y < b.min[2] + b.size[2]
			and maxp.z >= b.min[3] and minp.z < b.min[3] + b.size[3] then
			cm.emerge_stats.late = (cm.emerge_stats.late or 0) + 1
			core.log("warning", "[crystalminer] map chunk at " .. core.pos_to_string(minp) .. " generated after the build")
			return
		end
	end
end)

core.after(0, function()
	if storage:get_string("world_version") == WORLD_VERSION then
		world_ready = true
		for _, f in ipairs(on_world_ready) do f() end
		return
	end
	-- Generate the parts of the map the world uses (the museum and each region's world, which lie
	-- far apart), then build on them.
	local boxes = {}
	for _, live in ipairs(regions) do boxes[#boxes + 1] = world_box(live) end
	for _, b in ipairs(cm.extra_boxes) do boxes[#boxes + 1] = b end
	local decor = decor_placements()
	-- Every block of every box must really exist before the build. A block comes back CANCELLED
	-- when another emerge thread is still generating its map chunk (Luanti runs up to 4 of them for a
	-- singlenode map), for instance for a player who has just joined; that chunk would then be
	-- written over the build when it is finished, cutting away part of the museum or a world. So
	-- such blocks are asked for again, a moment later, until each one is there.
	local st = { retries = 0, gave_up = 0 }
	cm.emerge_stats = st
	local MAX_TRIES = 150
	local outstanding = 0
	for _, b in ipairs(boxes) do
		local n = 1
		for i = 1, 3 do
			n = n * (math.floor((b.min[i] + b.size[i] - 1) / 16) - math.floor(b.min[i] / 16) + 1)
		end
		outstanding = outstanding + n
	end
	st.total = outstanding
	local function request(pos1, pos2, tries)
		core.emerge_area(pos1, pos2, function(blockpos, action)
			st[action] = (st[action] or 0) + 1
			local failed = action == core.EMERGE_CANCELLED or action == core.EMERGE_ERRORED
			if failed and tries < MAX_TRIES then
				st.retries = st.retries + 1
				local p = { x = blockpos.x * 16, y = blockpos.y * 16, z = blockpos.z * 16 }
				core.after(0.2, function() request(p, p, tries + 1) end)
				return
			end
			if failed then
				st.gave_up = st.gave_up + 1
				core.log("error", "[crystalminer] map block " .. core.pos_to_string(blockpos) .. " could not be generated")
			end
			outstanding = outstanding - 1
			if outstanding == 0 then
				built_boxes = boxes
				build_world(decor)
			end
		end)
	end
	for _, b in ipairs(boxes) do
		request({ x = b.min[1], y = b.min[2], z = b.min[3] },
			{ x = b.min[1] + b.size[1] - 1, y = b.min[2] + b.size[2] - 1, z = b.min[3] + b.size[3] - 1 }, 1)
	end
end)

crystalminer.when_ready = function(f)
	if world_ready then f() else on_world_ready[#on_world_ready + 1] = f end
end

---------------------------------------------------------------------------- labels (HUD waypoints)

--- Everything that gets a floating label: key, text, world position.
local function label_targets()
	local out = {}
	local at = content.gate.at
	out[#out + 1] = { key = "gate", text = "Symmetry Gate: type /quiz", pos = { x = at[1] + 22, y = at[2] + 10, z = at[3] } }
	for _, d in ipairs(G.displays(at)) do
		out[#out + 1] = { key = "display_" .. d.letter, text = "Display " .. d.letter, pos = d.label }
	end
	out[#out + 1] = { key = "pad", text = "Try-it Pad: build, then punch a lever",
		pos = { x = PAD.at[1] + 6, y = PAD.at[2] + 7, z = PAD.at[3] + 2 } }
	out[#out + 1] = { key = "pad_build", text = "Your shape", pos = { x = PAD_BUILD.x + 2, y = PAD_BUILD.y + 5.5, z = PAD_BUILD.z + 2 } }
	out[#out + 1] = { key = "pad_result", text = "Result", pos = { x = PAD_RESULT.x + 2, y = PAD_RESULT.y + 5.5, z = PAD_RESULT.z + 2 } }
	for _, live in ipairs(regions) do
		local r = live.region
		out[#out + 1] = {
			key = "region_" .. live.area.id, region = live,
			pos = { x = r.min[1] + r.size[1] / 2 - 0.5, y = r.min[2] + r.size[2] + 1.5, z = r.min[3] + r.size[3] / 2 - 0.5 },
		}
	end
	return out
end
-- Floating labels gave way to real signs (signs.lua); modules may still add a label with
-- cm.add_label for places that have no wall to hang a sign on.
local LABELS = {}
local _ = label_targets
cm.labels = LABELS
--- Adds a floating label: { key, text, pos }, shown to players within LABEL_RANGE.
function cm.add_label(t) LABELS[#LABELS + 1] = t end

local function label_text(name, t)
	if not t.region then return t.text end
	local a = t.region.area
	local locked = progress(name).tier < a.tier
	return a.name .. " (" .. t.region.symbol .. "), tier " .. a.tier .. (locked and ", locked" or "")
end

local shown_labels = {}

local function update_labels(player)
	local name = player:get_player_name()
	local pos = player:get_pos()
	local shown = shown_labels[name] or {}
	shown_labels[name] = shown
	for _, t in ipairs(LABELS) do
		local dx, dz = t.pos.x - pos.x, t.pos.z - pos.z
		local near = dx * dx + dz * dz <= LABEL_RANGE * LABEL_RANGE
		local text = near and label_text(name, t) or nil
		local cur = shown[t.key]
		if cur and cur.text ~= text then
			player:hud_remove(cur.id)
			shown[t.key] = nil
		end
		if text and not shown[t.key] then
			local id = player:hud_add({
				hud_elem_type = "waypoint", type = "waypoint",
				name = text, text = "", precision = 0, number = 0xFFD700, world_pos = t.pos,
			})
			shown[t.key] = { id = id, text = text }
		end
	end
end

local function refresh_labels(name)
	local player = core.get_player_by_name(name)
	if player then update_labels(player) end
end

---------------------------------------------------------------------------- messages

local function say(name, text, colour)
	core.chat_send_player(name, colour and core.colorize(colour, text) or text)
end

local function show_title(player, text, subtitle)
	local def = {
		hud_elem_type = "text", type = "text",
		position = { x = 0.5, y = 0.25 }, alignment = { x = 0, y = 0 },
		text = text .. (subtitle and ("\n" .. subtitle) or ""),
		number = 0xFFD700, size = { x = 2 }, z_index = 100,
	}
	local id = player:hud_add(def)
	local pname = player:get_player_name()
	core.after(3.5, function()
		local p = core.get_player_by_name(pname)
		if p then p:hud_remove(id) end
	end)
end

local function welcome(name)
	say(name, "crystalminer", "#40C0FF")
	for _, l in ipairs(content.intro) do say(name, l) end
	say(name, "Lost? /explain tells you what to do where you are. /guide lists every command.", "#A0A0A0")
end

-- Element kinds, their legend entries and the colours that mark them.
local LEGEND = {
	{ "axis2", "2-fold axis (lens)" }, { "axis3", "3-fold axis (triangle; with a ring if it is also a -3 axis)" },
	{ "axis4", "4-fold axis (square)" }, { "rotoinversion", "-4 axis (square with a lens)" },
	{ "mirror", "mirror plane (dots across a sheet)" },
	{ "inversion", "inversion centre (white disc)" }, { "lattice", "unit-cell edges" },
}

local function legend(live)
	local present = {}
	for _, d in ipairs(live.dots) do present[d.colour] = true end
	local parts = {}
	for _, l in ipairs(LEGEND) do
		if present[E.COLOURS[l[1]]] then parts[#parts + 1] = core.colorize(E.COLOURS[l[1]], l[2]) end
	end
	return parts
end

local function explain(name, live, with_title)
	local player = core.get_player_by_name(name)
	local p = progress(name)
	local a = live.area
	if with_title and player then
		show_title(player, a.name, "Symmetry " .. live.symbol .. (p.tier < a.tier and ("  (locked: tier " .. a.tier .. ")") or ""))
	end
	say(name, "-- " .. a.name .. " (" .. live.symbol .. ") --", "#FFD700")
	if p.tier < a.tier then
		say(name, "You can look around, but building here unlocks at tier " .. a.tier
			.. ". Finish the quizzes of tier " .. p.tier .. " first (/quiz).", "#A0A0A0")
		return
	end
	-- The steps are in the guide window (first visit, or /explain) and on the boards by the plaza.
	if a.tier == 0 or not crystalminer.GUIDES[a.id] then
		for _, l in ipairs(L.explanation(a, p.tier)) do say(name, l) end
	else
		say(name, (crystalminer.GUIDES[a.id].steps[1] or "") .. "  " .. core.colorize("#A0A0A0", "(/explain shows all the steps)"))
	end
	if a.showcase and storage:get_string("showcase:" .. a.id) == "1" then
		say(name, "Example build: " .. a.showcase.text, "#80E0FF")
	end
	local parts = legend(live)
	if #parts > 0 then
		say(name, "Marked: " .. table.concat(parts, ", ") .. ". " .. core.colorize("#A0A0A0", "/elements chooses which to show."))
	end
	for _, q in ipairs(L.questions(a, p.tier)) do
		if not p.answered[q.id] then
			say(name, "Type /quiz for questions about this region.", "#40C0FF")
			break
		end
	end
end

-- Per player: HUD ids of the stereogram, and whether it is switched off.
local stereo_hud, stereo_off = {}, {}

local function update_stereogram(player, live)
	local name = player:get_player_name()
	local cur = stereo_hud[name]
	if cur then
		player:hud_remove(cur.image)
		player:hud_remove(cur.text)
		stereo_hud[name] = nil
	end
	if not live or not live.stereogram or stereo_off[name] or not unlocked(name, live) then return end
	local n = #S.linear_parts(live.region.group).ops
	stereo_hud[name] = {
		image = player:hud_add({
			hud_elem_type = "image", type = "image", position = { x = 1, y = 1 }, alignment = { x = -1, y = -1 },
			offset = { x = -16, y = -64 }, scale = { x = 1.6, y = 1.6 }, text = live.stereogram, z_index = 50,
		}),
		text = player:hud_add({
			hud_elem_type = "text", type = "text", position = { x = 1, y = 1 }, alignment = { x = -1, y = -1 },
			offset = { x = -16, y = -40 }, number = 0xE0E0E0, z_index = 50,
			text = "Stereogram of " .. (live.region.cell and ("the crystal class of " .. live.symbol) or live.symbol)
				.. ": " .. n .. " copies of one direction\ndots above, rings below; symbols mark axes, lines mirrors; north up",
		}),
	}
end
crystalminer.update_stereogram = update_stereogram

local function explain_pad(name, with_title)
	local player = core.get_player_by_name(name)
	if with_title and player then show_title(player, PAD.name, "Build, predict, then see") end
	say(name, "-- " .. PAD.name .. " --", "#FFD700")
	say(name, "Build a shape in the box marked YOUR SHAPE, then hit a lever.  "
		.. core.colorize("#A0A0A0", "(/explain shows all the steps)"))
end

---------------------------------------------------------------------------- daylight

-- Night makes the colours and symbols hard to see, so by default it stays day. The clock is reset
-- from time to time instead of changing time_speed, which would also change other games.
if core.settings:get_bool("crystalminer.always_day", true) then
	local day_timer = 9
	core.register_globalstep(function(dtime)
		day_timer = day_timer + dtime
		if day_timer < 10 then return end
		day_timer = 0
		local t = core.get_timeofday()
		if t < 0.3 or t > 0.7 then core.set_timeofday(0.5) end
	end)
end

---------------------------------------------------------------------------- tracking and visuals

local current_area = {}
-- Which kinds of symmetry element each player sees; nil means all.
local element_filter = {}
local timer = 0

-- Symmetry markers: one endless particle spawner per dot and player (see E.sync_markers).
-- markers[name] is that player's state; marker_api is swappable so the self-test can count calls.
local markers = {}
local marker_api = { add = core.add_particlespawner, delete = core.delete_particlespawner }
crystalminer.markers, crystalminer.marker_api = markers, marker_api

--- Shows player name the markers of region live (nil: none), honouring /elements and locks.
local function sync_markers(name, live)
	local filter = element_filter[name]
	local dots = live and filter ~= "none" and unlocked(name, live) and live.dots or nil
	markers[name] = E.sync_markers(markers[name], dots, filter,
		function(d) return marker_api.add(E.marker_def(d, name)) end,
		function(id) marker_api.delete(id, name) end)
end
crystalminer.sync_markers = sync_markers

local function area_id_at(pos)
	local live = region_near(pos)
	if live then return live.area.id, live end
	if near_gate(pos) then return content.gate.id end
	if near_pad(pos) then return PAD.id end
	return ""
end

core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer >= 0.5 then
		timer = 0
		for _, player in ipairs(core.get_connected_players()) do
			local name = player:get_player_name()
			local id, live = area_id_at(player:get_pos())
			if id ~= current_area[name] then
				current_area[name] = id
				update_stereogram(player, live)
				hook("on_area", name, id, live)
				if live then
					explain(name, live, true)
				elseif id == content.gate.id then
					show_title(player, "Symmetry Gate", "Type /quiz to test yourself")
				elseif id == PAD.id then
					explain_pad(name, true)
				end
			end
			update_labels(player)
			-- Sends packets only when what the player should see changed.
			local pos = player:get_pos()
			sync_markers(name, region_near(pos) or (crystalminer.exhibit_live_at and crystalminer.exhibit_live_at(pos)))
		end
	end
end)

---------------------------------------------------------------------------- progress board (inventory screen)

local function area_status(p, a)
	local qs = L.questions(a, p.tier)
	local done = 0
	for _, q in ipairs(qs) do if p.answered[q.id] then done = done + 1 end end
	return done, #qs
end

local function board_formspec(name)
	local p = progress(name)
	local rows = {}
	for _, a in ipairs(L.areas(content)) do
		local done, total = area_status(p, a)
		if total > 0 then rows[#rows + 1] = { a = a, done = done, total = total } end
	end
	local h = 1.6 + 0.6 * math.max(#rows, 1) + 5.4
	local fs = { "formspec_version[4]size[12," .. h .. "]",
		"label[0.4,0.5;" .. core.formspec_escape("Tier " .. p.tier .. ": " .. (content.tiers[p.tier] or "")
			.. "   (" .. L.remaining(content, p) .. " question(s) left)") .. "]" }
	local y = 1.1
	if #rows == 0 then
		fs[#fs + 1] = "label[0.4," .. (y + 0.25) .. ";No questions at this tier. Try /challenge in the Free Lab.]"
	end
	for _, r in ipairs(rows) do
		local status = r.done == r.total and core.colorize("#60FF60", "done") or core.colorize("#FFFF60", r.done .. " of " .. r.total)
		fs[#fs + 1] = "label[0.4," .. (y + 0.25) .. ";" .. core.formspec_escape(r.a.name) .. "]"
		fs[#fs + 1] = "label[6,"  .. (y + 0.25) .. ";" .. status .. "]"
		fs[#fs + 1] = "button[9.4," .. y .. ";2.2,0.5;go_" .. r.a.id .. ";Go there]"
		y = y + 0.6
	end
	fs[#fs + 1] = "label[0.4," .. (y + 0.4) .. ";Blocks are free: you never run out.]"
	fs[#fs + 1] = "button[8.4," .. (y + 0.1) .. ";3.2,0.6;ask_tutor;Ask Prism, the tutor]"
	fs[#fs + 1] = "list[current_player;main;0.4," .. (y + 0.8) .. ";8,4;]"
	return table.concat(fs)
end

local function refresh_board(name)
	local player = core.get_player_by_name(name)
	if player then player:set_inventory_formspec(board_formspec(name)) end
end
crystalminer.board_formspec = board_formspec

---------------------------------------------------------------------------- players

core.register_privilege("teacher", { description = "Can change players' tiers and see the class", give_to_singleplayer = true })

core.register_on_newplayer(function(player)
	player:set_pos(SPAWN)
end)

core.register_on_respawnplayer(function(player)
	player:set_pos(SPAWN)
	return true
end)

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local privs = core.get_player_privs(name)
	privs.interact, privs.shout, privs.fly, privs.fast = true, true, true, true
	core.set_player_privs(name, privs)
	-- Nothing in this world should hurt: no health bar, no fall damage.
	player:set_armor_groups({ immortal = 1 })
	player:hud_set_flags({ healthbar = false, breathbar = false })
	local inv = player:get_inventory()
	inv:set_size("main", 32)
	for _, item in ipairs(buildable) do
		if not inv:contains_item("main", item) then inv:add_item("main", item .. " 99") end
	end
	refresh_board(name)
	player:set_look_horizontal(0)
	core.after(1, function()
		welcome(name)
		hook("on_join", name)
	end)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	-- The player still exists during on_leaveplayer, so the server forgets these spawners too.
	sync_markers(name, nil)
	shown_labels[name], current_area[name], element_filter[name] = nil, nil, nil
	stereo_hud[name], stereo_off[name] = nil, nil
end)

---------------------------------------------------------------------------- quiz

-- Per player: { id = question id, wrong = { [choice] = true }, feedback = text, review = true for a
-- review question (answered with review_answer, which changes no progress) }.
local pending_question = {}
crystalminer.pending_question = pending_question   -- read by the self-test

local function quiz_formspec(q, state)
	local n = #q.options
	local fb = state and state.feedback
	-- A review question (state.review) has a line at the top saying it does not change the tier.
	local top = (state and state.review) and 0.6 or 0
	local h = 2.3 + top + (fb and 1.1 or 0) + 0.95 * n
	-- Anchored to the bottom of the screen without dimming it, so the scene stays visible.
	local fs = { "formspec_version[4]size[12,", h, "]position[0.5,0.97]anchor[0.5,1]bgcolor[#1E2433E6;false]" }
	if top > 0 then
		fs[#fs + 1] = "label[0.4,0.45;" .. core.formspec_escape(core.colorize("#40C0FF", content.quiz_review.label)) .. "]"
	end
	fs[#fs + 1] = "textarea[0.4," .. (0.35 + top) .. ";11.2,1.5;;;" .. core.formspec_escape(q.q) .. "]"
	local y = 1.95 + top
	if fb then
		fs[#fs + 1] = "textarea[0.4," .. y .. ";11.2,1;;;" .. core.formspec_escape(fb) .. "]"
		y = y + 1.1
	end
	for i, opt in ipairs(q.options) do
		local text = core.formspec_escape(string.char(64 + i) .. ") " .. opt)
		if state and state.wrong[i - 1] then
			fs[#fs + 1] = "box[0.4," .. y .. ";11.2,0.8;#40404080]"
			fs[#fs + 1] = "label[0.7," .. (y + 0.4) .. ";" .. core.colorize("#909090", text .. "   (not this one)") .. "]"
		else
			fs[#fs + 1] = "button[0.4," .. y .. ";11.2,0.8;opt_" .. (i - 1) .. ";" .. text .. "]"
		end
		y = y + 0.95
	end
	return table.concat(fs)
end
crystalminer.quiz_formspec = quiz_formspec

--- For questions about a Gate display, stand the player in front of it, facing it.
local function face_display(name, letter)
	local player = core.get_player_by_name(name)
	if not player then return end
	for _, d in ipairs(G.displays(content.gate.at)) do
		if d.letter == letter then
			-- Far enough back, and looking slightly down, that the display sits in the upper half of
			-- the screen, above the quiz window.
			local stand = { x = d.look_at.x, y = GROUND_Y + 1, z = d.look_at.z + 14 }
			player:set_pos(stand)
			local dx, dy, dz = d.look_at.x - stand.x, GROUND_Y - 2 - (stand.y + 1.6), d.look_at.z - stand.z
			player:set_look_horizontal(math.atan2(-dx, dz))
			player:set_look_vertical(math.atan2(-dy, math.sqrt(dx * dx + dz * dz)))
		end
	end
end

local function ask_question(name, q, state)
	state = state or { id = q.id, wrong = {} }
	pending_question[name] = state
	if q.display and not state.faced then
		face_display(name, q.display)
		state.faced = true
	end
	core.show_formspec(name, "crystalminer:quiz", quiz_formspec(q, state))
end

-- Which review question each player gets next, per area: name -> { [area id] = k }. In memory
-- only; it just makes repeated /quiz show different questions.
local review_turn = {}

--- /quiz. no_review: only questions that count (used right after a correct answer, so the player
--- is then told where the remaining questions are rather than handed a review).
local function show_quiz(name, no_review)
	local p = progress(name)
	local here = current_area[name] or ""
	local area = p.tier == 0 and content.gate or L.area(content, here)
	if area then
		for _, q in ipairs(L.questions(area, p.tier)) do
			if not p.answered[q.id] then
				ask_question(name, q)
				return
			end
		end
	end
	-- Nothing open here at the player's tier: review a question of this place from the player's
	-- tier or below (never above it), if it has any. Reviews change no progress.
	local here_area = not no_review and L.area(content, here)
	if here_area then
		local turns = review_turn[name] or {}
		review_turn[name] = turns
		local k = turns[here_area.id] or 1
		local q = L.review_pick(here_area, p.tier, k)
		if q then
			turns[here_area.id] = k + 1
			ask_question(name, q, { id = q.id, wrong = {}, review = true })
			return
		end
	end
	local open = {}
	for _, a in ipairs(content.regions) do
		for _, q in ipairs(L.questions(a, p.tier)) do
			if not p.answered[q.id] then
				open[#open + 1] = a
				break
			end
		end
	end
	if #open == 0 then
		say(name, "No questions left at your tier.", "#60FF60")
		return
	end
	say(name, "Questions for tier " .. p.tier .. " are waiting in (press I for your progress board):", "#FFFF60")
	for _, a in ipairs(open) do say(name, "  " .. a.name .. "   (/goto " .. a.id .. ")") end
end
crystalminer.show_quiz = show_quiz

--- Checks an answer. Returns true if correct.
local function answer(name, id, choice)
	local q = L.question(content, id)
	local p = progress(name)
	if not q or p.answered[id] then return false end
	local in_tier = false
	for _, t in ipairs(L.questions_for_tier(content, p.tier)) do
		if t.id == id then in_tier = true end
	end
	if not in_tier then return false end
	if choice ~= q.answer then return false end
	say(name, core.colorize("#60FF60", "Correct! ") .. q.why)
	local before = p.tier
	local levelled = L.record_correct(content, p, id)
	save_progress(name)
	refresh_board(name)
	if levelled then
		local player = core.get_player_by_name(name)
		if player then show_title(player, "Tier " .. p.tier .. " unlocked", content.tiers[p.tier]) end
		say(name, "You finished tier " .. before .. ". New regions are open: press I or type /regions.", "#60FF60")
		hook("on_levelled", name)
	else
		say(name, L.remaining(content, p) .. " question(s) left in tier " .. p.tier .. ".", "#A0A0A0")
	end
	return true
end
crystalminer.answer = answer

--- Checks the answer to a review question: the same "Correct!" feedback, but it changes nothing
--- that is stored (answered questions, tier, learning records). Returns true if correct.
local function review_answer(name, id, choice)
	local q, tier = L.question(content, id)
	local p = progress(name)
	-- Only questions at or below the player's tier can be reviewed.
	if not q or tier > p.tier then return false end
	if choice ~= q.answer then return false end
	say(name, core.colorize("#60FF60", "Correct! ") .. q.why)
	say(name, content.quiz_review.correct, "#A0A0A0")
	if L.remaining(content, p) > 0 then say(name, content.quiz_review.elsewhere, "#A0A0A0") end
	return true
end
crystalminer.review_answer = review_answer

local function teleport(name, id) end -- defined below; used by the board buttons

core.register_on_player_receive_fields(function(player, formname, fields)
	local name = player:get_player_name()
	if formname == "" then
		if fields.ask_tutor then
			cm.open_tutor(name)
			return true
		end
		for k in pairs(fields) do
			local id = k:match("^go_(.+)$")
			if id then
				core.close_formspec(name, "")
				crystalminer.teleport(name, id)
				return true
			end
		end
		return false
	end
	if formname == "crystalminer:predict" then
		local lever = pending_lever[name]
		pending_lever[name] = nil
		if not lever or not (fields.yes or fields.no) then return true end
		core.close_formspec(name, formname)
		local empty, matches = apply_lever(lever)
		if empty then
			say(name, "First build a shape in the box marked YOUR SHAPE.", "#FFFF60")
			return true
		end
		local predicted = fields.yes ~= nil
		say(name, (predicted == matches) and core.colorize("#60FF60", "Your guess was right. ")
			or core.colorize("#FF9060", "Not what you guessed. "))
		if lever.op == "translation" or lever.op == "rotation" then
			say(name, "The copy could be turned back to match: " .. (lever.op == "translation" and "sliding" or "turning")
				.. " only moves a shape, it never changes it.")
		elseif matches then
			say(name, "The copy matches this time, because your shape is symmetric itself: it has its own mirror "
				.. "or centre point, so its mirror twin is the same shape. Now try a lopsided shape with lever "
				.. lever.letter .. ".")
		else
			say(name, "The copy is your shape's mirror twin, like your left hand and your right hand: no turning can "
				.. "make them match. Shapes like this are called chiral, from the Greek word for hand.")
		end
		return true
	end
	if formname ~= "crystalminer:quiz" then return false end
	local state = pending_question[name]
	if not state then return true end
	for k in pairs(fields) do
		local choice = k:match("^opt_(%d+)$")
		if choice then
			choice = tonumber(choice)
			local q = L.question(content, state.id)
			local correct
			if state.review then
				correct = review_answer(name, state.id, choice)
			else
				correct = answer(name, state.id, choice)
			end
			if correct then
				crystalminer.sound("crystalminer_right", name)
				pending_question[name] = nil
				core.close_formspec(name, "crystalminer:quiz")
				-- After a review, the player asks for the next one with /quiz (no endless chain).
				if not state.review then core.after(0.2, function() show_quiz(name, true) end) end
			elseif q then
				crystalminer.sound("crystalminer_wrong", name)
				state.wrong[choice] = true
				state.feedback = "Not quite. " .. (q.hint or "Look at the copies again, then try another option.")
				ask_question(name, q, state)
			end
			return true
		end
	end
	pending_question[name] = nil
	return true
end)

---------------------------------------------------------------------------- commands

local function cmd(name, def)
	core.register_chatcommand(name, def)
end

cmd("guide", {
	description = "List what you can do",
	func = function(name)
		local rows = {
			{ "I", "open your progress board (with buttons to go to each region)" },
			{ "/tour", "a ten-minute guided tour" },
			{ "/hint on|off", "show or hide the 'Next:' line above the hotbar" },
			{ "/step, /byhand", "see each copy appear with its name, or place the copies yourself" },
			{ "/hunt", "the clue crystals you have solved in the Crystal Museum" },
			{ "/stereogram on|off", "the textbook diagram of the region's symmetry" },
			{ "/quiz", "answer questions to unlock the next tier" },
			{ "/explain", "repeat the explanation for the region you are in" },
			{ "/regions", "list all regions" },
			{ "/goto <region>", "teleport to a region" },
			{ "/progress", "see your tier" },
			{ "/elements <all|axes|mirrors|centres|cells|none>", "choose which symmetry elements to show" },
			{ "/ask", "chat with Prism, the AI tutor (also at the information desk)" },
			{ "/whatsymmetry", "work out the exact symmetry of what you built in a region" },
			{ "/symmetry <description>", "give the Free Lab a symmetry (tier 4)" },
			{ "/challenge", "get a build challenge for the Free Lab (tier 4)" },
			{ "/clearlab", "empty the Free Lab" },
			{ "/spawn", "go back to the start" },
		}
		for _, r in ipairs(rows) do say(name, core.colorize("#40C0FF", r[1]) .. "  " .. r[2]) end
		say(name, "Press K to fly (with J for fast). Right-click while pointing at nothing places a block in mid-air "
			.. "inside a region. Every block in your inventory is free.", "#A0A0A0")
		return true
	end,
})

cmd("quiz", { description = "Answer questions to unlock the next tier", func = function(name) show_quiz(name) return true end })

cmd("explain", {
	description = "Repeat the explanation for this region",
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then return true end
		local id, live = area_id_at(player:get_pos())
		if crystalminer.show_guide and crystalminer.show_guide(name, id) then return true end
		if live then explain(name, live, false)
		elseif id == PAD.id then explain_pad(name, false)
		else welcome(name) end
		return true
	end,
})

cmd("regions", {
	description = "List all regions",
	func = function(name)
		local tier = progress(name).tier
		say(name, "Regions (you are tier " .. tier .. "). Teleport with /goto <id>:", "#FFD700")
		say(name, "  " .. content.gate.id .. ": Symmetry Gate (tier 0)")
		say(name, "  " .. PAD.id .. ": " .. PAD.name .. " (tier 0)")
		for _, live in ipairs(regions) do
			local a = live.area
			local line = "  " .. a.id .. ": " .. a.name .. " (" .. live.symbol .. ", tier " .. a.tier .. ")"
			say(name, line, tier >= a.tier and nil or "#707070")
		end
		return true
	end,
})

teleport = function(name, id)
	local player = core.get_player_by_name(name)
	if not player then return false, "Not in game." end
	update_stereogram(player, nil)
	if id == content.gate.id then
		-- In Gallery 1, in front of the displays, facing them (south).
		player:set_pos({ x = 0, y = GROUND_Y + 1, z = content.gate.at[3] + 13 })
		player:set_look_horizontal(math.pi)
		player:set_look_vertical(0.15)
		return true
	end
	if id == PAD.id then
		player:set_pos({ x = PAD.at[1] + 6, y = GROUND_Y + 1, z = LEVER_Z + 2 })
		player:set_look_horizontal(math.pi)
		current_area[name] = PAD.id
		explain_pad(name, true)
		return true
	end
	for _, live in ipairs(regions) do
		if live.area.id == id then
			local r = live.region
			-- Arrive on the region's plaza, looking north through the gate at the region.
			local arrive = D.plaza(r).arrive
			player:set_pos({ x = arrive.x, y = GROUND_Y + 1, z = arrive.z })
			player:set_look_horizontal(0)
			player:set_look_vertical(0)
			current_area[name] = id
			explain(name, live, true)
			hook("on_area", name, id, live)
			update_stereogram(player, live)
			return true
		end
	end
	if hook("on_teleport", name, id, player) then return true end
	return false, "No region called " .. id .. ". Type /regions for the list."
end
do -- shimmer for the player who travelled (portal punch, /goto, /spawn, board buttons), only on success
	local teleport_silent = teleport
	teleport = function(name, id)
		local ok, msg = teleport_silent(name, id)
		if ok and crystalminer.sound then crystalminer.sound("crystalminer_portal", name) end
		return ok, msg
	end
end
crystalminer.teleport = teleport

cmd("goto", { params = "<region>", description = "Teleport to a region", func = function(name, param) return teleport(name, param:trim()) end })
cmd("spawn", { description = "Go back to the start, in the foyer", func = function(name) return teleport(name, "foyer") end })

cmd("progress", {
	description = "Show your tier",
	func = function(name)
		local p = progress(name)
		return true, "Tier " .. p.tier .. ": " .. (content.tiers[p.tier] or "") .. ". "
			.. L.remaining(content, p) .. " question(s) left in this tier. Press I for your progress board."
	end,
})

cmd("stereogram", {
	params = "<on|off>",
	description = "Show or hide the stereogram of the region you are in",
	func = function(name, param)
		param = param:trim():lower()
		if param ~= "on" and param ~= "off" then return false, "Usage: /stereogram on or /stereogram off" end
		stereo_off[name] = param == "off" or nil
		local player = core.get_player_by_name(name)
		if player then update_stereogram(player, select(2, area_id_at(player:get_pos()))) end
		return true, "Stereogram " .. param .. "."
	end,
})

local FILTERS = { all = true, axes = true, mirrors = true, centres = true, cells = true, none = true }
cmd("elements", {
	params = "<all|axes|mirrors|centres|cells|none>",
	description = "Choose which symmetry elements to show",
	func = function(name, param)
		param = param:trim():lower()
		if param == "centers" then param = "centres" end
		if not FILTERS[param] then return false, "Usage: /elements all, axes, mirrors, centres, cells or none" end
		element_filter[name] = param ~= "all" and param or nil
		return true, "Showing " .. (param == "all" and "all symmetry elements" or param == "none" and "no symmetry elements" or param) .. "."
	end,
})

cmd("settier", {
	params = "<tier> [player]",
	description = "Set a player's tier (teachers)",
	privs = { teacher = true },
	func = function(name, param)
		local t, who = param:match("^(%d+)%s*(%S*)$")
		t = tonumber(t)
		if not t or t > L.max_tier(content) then return false, "Usage: /settier <0-" .. L.max_tier(content) .. "> [player]" end
		who = (who and who ~= "") and who or name
		progress(who).tier = t
		save_progress(who)
		refresh_board(who)
		return true, who .. " is now tier " .. t .. "."
	end,
})

---------------------------------------------------------------------------- showcase (example builds for demonstrations)

--- Places a region's showcase seed; the region's symmetry makes every copy. Returns blocks placed.
--- Loads a region's map blocks, so set_node works there even when no player is nearby.
local function load_region(r)
	core.load_area({ x = r.min[1], y = r.min[2], z = r.min[3] },
		{ x = r.min[1] + r.size[1] - 1, y = r.min[2] + r.size[2] - 1, z = r.min[3] + r.size[3] - 1 })
end

local function place_showcase(live)
	local r = live.region
	load_region(r)
	local n = 0
	for _, b in ipairs(L.showcase_blocks(live.area)) do
		local pos = { x = r.min[1] + b[1], y = r.min[2] + b[2], z = r.min[3] + b[3] }
		local node = { name = "crystalminer:" .. b[4] }
		core.set_node(pos, node)
		copy_to_images(pos, node)
		n = n + 1
	end
	storage:set_string("showcase:" .. live.area.id, "1")
	return n
end

local function clear_region(live)
	local r = live.region
	load_region(r)
	for x = r.min[1], r.min[1] + r.size[1] - 1 do
		for y = r.min[2], r.min[2] + r.size[2] - 1 do
			for z = r.min[3], r.min[3] + r.size[3] - 1 do core.set_node({ x = x, y = y, z = z }, { name = "air" }) end
		end
	end
	storage:set_string("showcase:" .. live.area.id, "")
end

local function showcase(param)
	param = (param or ""):trim()
	local done = 0
	for _, live in ipairs(regions) do
		local a = live.area
		if a.showcase and (param == "" or param == "clear" or param == a.id) then
			if param == "clear" then clear_region(live) else place_showcase(live) end
			done = done + 1
		end
	end
	return done
end
crystalminer.showcase = showcase

cmd("showcase", {
	params = "[region | clear]",
	description = "Fill regions with example builds for a demonstration, or empty them again (teachers)",
	privs = { teacher = true },
	func = function(name, param)
		param = param:trim()
		local n = showcase(param)
		if n == 0 then return false, "No showcase called " .. param .. ". Type /regions for the ids." end
		if param == "clear" then return true, "Emptied " .. n .. " showcase region(s), including anything students built there." end
		return true, "Example builds placed in " .. n .. " region(s). Each was seeded with one piece; the symmetry "
			.. "made the copies. Walk into a region to see what was built."
	end,
})

--- Every player with saved progress: name, tier, questions answered, online.
local function class_rows()
	local rows, seen = {}, {}
	local function add(who, p)
		if seen[who] then return end
		seen[who] = true
		local n = 0
		for _ in pairs(p.answered or {}) do n = n + 1 end
		rows[#rows + 1] = { name = who, tier = p.tier or 0, answered = n, left = L.remaining(content, p),
			online = core.get_player_by_name(who) ~= nil }
	end
	for key, value in pairs(storage:to_table().fields) do
		local who = key:match("^progress:(.+)$")
		if who then add(who, progress_cache[who] or core.deserialize(value) or L.new_progress()) end
	end
	for who, p in pairs(progress_cache) do add(who, p) end
	table.sort(rows, function(a, b) return a.name < b.name end)
	return rows
end
crystalminer.class_rows = class_rows

cmd("class", {
	description = "See every student's tier and progress (teachers)",
	privs = { teacher = true },
	func = function(name)
		local rows = class_rows()
		local fs = { "formspec_version[4]size[12,9]label[0.4,0.5;Class progress (" .. #rows .. " players)]",
			"tablecolumns[text;text,align=center;text,align=center;text,align=center;text]",
			"table[0.4,1;11.2,7.6;class;Name,Tier,Answered,Left in tier,Online" }
		for _, r in ipairs(rows) do
			fs[#fs + 1] = "," .. core.formspec_escape(r.name) .. "," .. r.tier .. "," .. r.answered .. "," .. r.left .. "," .. (r.online and "yes" or "")
		end
		fs[#fs + 1] = ";1]"
		core.show_formspec(name, "crystalminer:class", table.concat(fs))
		return true
	end,
})

---------------------------------------------------------------------------- symmetry analysis and the Free Lab

--- Exact point symmetry of everything built in a region: group, catalog entry (nil if empty).
local function analyse(live)
	local r = live.region
	local nodes, any = {}, false
	for x = r.min[1], r.min[1] + r.size[1] - 1 do
		for y = r.min[2], r.min[2] + r.size[2] - 1 do
			for z = r.min[3], r.min[3] + r.size[3] - 1 do
				local n = core.get_node({ x = x, y = y, z = z }).name
				if n ~= "air" and n ~= "ignore" then
					nodes[(2 * x + 1) .. "," .. (2 * y + 1) .. "," .. (2 * z + 1)] = n
					any = true
				end
			end
		end
	end
	if not any then return nil end
	return S.detect(nodes)
end
crystalminer.analyse = analyse

local function whatsymmetry(name)
	local player = core.get_player_by_name(name)
	local live = player and region_near(player:get_pos())
	if not live then return false, "Stand in or next to a region first." end
	local g, entry = analyse(live)
	if not g then return true, "Nothing built here yet." end
	local symbol = entry and entry.symbol or "?"
	say(name, "Your build has point symmetry " .. symbol .. " (" .. #g.ops .. " operation" .. (#g.ops == 1 and "" or "s") .. ").", "#FFD700")
	say(name, S.describe(g))
	local cs = live.area.challenges
	local p = progress(name)
	if cs and cs[p.challenge] then
		local c = cs[p.challenge]
		if c.target == symbol then
			say(name, "Challenge complete: " .. c.text, "#60FF60")
			p.challenge = p.challenge + 1
			save_progress(name)
			say(name, "Type /challenge for the next one.", "#A0A0A0")
		else
			say(name, "Your challenge wants " .. c.target .. ".", "#FFFF60")
		end
	end
	return true
end

cmd("whatsymmetry", { description = "Work out the exact symmetry of your build", func = whatsymmetry })

local function free_lab(name)
	for _, live in ipairs(regions) do
		if live.area.free then
			if progress(name).tier < live.area.tier then
				return nil, "The Free Lab unlocks at tier " .. live.area.tier .. "."
			end
			return live
		end
	end
	return nil, "There is no Free Lab in this world."
end

local function apply_symmetry(name, live, symbol, reason)
	if symbol:lower() == "none" then
		say(name, "That does not match any of the 32 crystallographic point groups. "
			.. "Crystals can only have 1-, 2-, 3-, 4- and 6-fold rotation axes.", "#FFFF60")
		return
	end
	local e = S.point_group(symbol)
	if not e then
		say(name, "'" .. symbol .. "' is not a crystallographic point group.", "#FF6060")
		return
	end
	-- The model's own words may be wrong; the engine's statements below are what describe the group.
	if reason then say(name, core.colorize("#D080FF", "Tutor's note (may be wrong): ") .. reason) end
	if not S.fits_grid(e.group) then
		local sig = S.signature(e.group)
		say(name, e.symbol .. " is a real crystal symmetry, but it cannot be built here: it needs a "
			.. (sig["6"] and "6-fold" or "-6") .. " axis, and turning a square grid by 60 degrees moves grid "
			.. "points off the grid. Hexagonal crystals need a hexagonal lattice.", "#FFFF60")
		return
	end
	set_symmetry(live, e.symbol, e.generators)
	for _, pl in ipairs(core.get_connected_players()) do
		if current_area[pl:get_player_name()] == live.area.id then update_stereogram(pl, live) end
	end
	say(name, "The Free Lab now has symmetry " .. e.symbol .. " (" .. #e.group.ops .. " operations, " .. e.system .. ").", "#60FF60")
	say(name, S.describe(e.group))
	say(name, "Blocks already in the lab were not changed. /clearlab empties it.", "#A0A0A0")
end
crystalminer.apply_symmetry = apply_symmetry

-- Provider, URL, model and key settings are read in tutor.lua (Tutor.config). Keys are never logged.
local tutor_cfg, tutor_off = Tutor.config(function(k) return core.settings:get(k) end, os.getenv)
local tutor_on = http ~= nil and tutor_off == nil
-- Claude is paid per request, so it keeps the longer wait between questions; a conversation with a cheap hosted or a local model can go faster.
local tutor_limits = Tutor.new_limiter(tutor_cfg and tutor_cfg.provider == "openai_compatible" and 5 or nil)
local function now_s() return core.get_us_time() / 1e6 end
-- For the chat window (tutor_window.lua).
cm.tutor = { T = Tutor, http = http, cfg = tutor_cfg, on = tutor_on, limits = tutor_limits, now = now_s }

if tutor_cfg then core.log("action", "[crystalminer] Tutor: " .. Tutor.describe(tutor_cfg)) end
if not tutor_on then
	core.log("action", "[crystalminer] Tutor off: " .. (http and tutor_off or "add crystalminer to secure.http_mods"))
end

local function ask_tutor(name, param, source)
	if not tutor_on then return false, "The tutor is not set up on this server. See the README." end
	param = param:trim()
	if param == "" then return false, "Please type a question first." end
	local too_long = Tutor.check_length(param)
	if too_long then return false, too_long end
	local ok, busy = Tutor.try_start(tutor_limits, name, now_s())
	if not ok then return false, busy end
	local player = core.get_player_by_name(name)
	local live = player and region_near(player:get_pos())
	if source then say(name, source, "#A0A0A0") end
	Tutor.send(http, tutor_cfg, Tutor.ask_request(tutor_cfg, param, progress(name).tier, live and live.area.name),
		core.write_json, core.parse_json, function(text, err)
			Tutor.finish(tutor_limits, name)
			say(name, core.colorize("#D080FF", "Tutor: ") .. (text and Tutor.strip_label(text) or err))
		end)
	return true
end
cm.ask_tutor = ask_tutor

cmd("symmetry", {
	params = "<description>",
	description = "Give the Free Lab a symmetry, e.g. /symmetry a fourfold axis with mirrors",
	func = function(name, param)
		local live, err = free_lab(name)
		if not live then return false, err end
		param = param:trim()
		if param == "" then return false, "Usage: /symmetry <description or symbol>" end
		-- A symbol works without the tutor.
		if S.point_group(param) or param:lower() == "none" or not tutor_on then
			apply_symmetry(name, live, param, nil)
			return true
		end
		local too_long = Tutor.check_length(param)
		if too_long then return false, too_long end
		local ok, busy = Tutor.try_start(tutor_limits, name, now_s())
		if not ok then return false, busy end
		say(name, "Working out which symmetry you mean...", "#A0A0A0")
		Tutor.send_symmetry(http, tutor_cfg, param, core.write_json, core.parse_json, function(text, err2)
			Tutor.finish(tutor_limits, name)
			if not text then
				say(name, err2 or "The tutor could not read that. Try a point-group symbol, like /symmetry 4mm.", "#FF6060")
				return
			end
			-- Only a symbol the engine knows gets through; the engine then checks and describes it.
			local symbol, note = Tutor.choose_symbol(text, core.parse_json)
			if not symbol then
				say(name, note, "#FF6060")
				return
			end
			apply_symmetry(name, live, symbol, note)
		end)
		return true
	end,
})

-- /ask opens the chat with Prism (tutor_window.lua); /ask <question> asks it straight away there.
cmd("ask", {
	params = "[question]",
	description = "Chat with Prism, the AI tutor",
	func = function(name, param)
		cm.open_tutor(name, param:trim())
		return true
	end,
})

cmd("challenge", {
	description = "Get a build challenge for the Free Lab",
	func = function(name)
		local live, err = free_lab(name)
		if not live then return false, err end
		local cs, i = live.area.challenges or {}, progress(name).challenge
		if not cs[i] then return true, "You have completed every challenge!" end
		say(name, "Challenge " .. i .. "/" .. #cs .. ": " .. cs[i].text, "#FFFF60")
		say(name, "Build it in the Free Lab (/symmetry 1 lets you build without copies), then type /whatsymmetry.", "#A0A0A0")
		return true
	end,
})

cmd("clearlab", {
	description = "Empty the Free Lab",
	func = function(name)
		local live, err = free_lab(name)
		if not live then return false, err end
		local r = live.region
		for x = r.min[1], r.min[1] + r.size[1] - 1 do
			for y = r.min[2], r.min[2] + r.size[2] - 1 do
				for z = r.min[3], r.min[3] + r.size[3] - 1 do core.set_node({ x = x, y = y, z = z }, { name = "air" }) end
			end
		end
		return true, "The Free Lab is empty."
	end,
})

---------------------------------------------------------------------------- feature modules

cm.say, cm.show_title, cm.save_progress, cm.refresh_board = say, show_title, save_progress, refresh_board
cm.region_at, cm.region_near, cm.unlocked, cm.explain = region_at, region_near, unlocked, explain
cm.current_area, cm.GROUND_Y, cm.SPAWN, cm.E, cm.D = current_area, GROUND_Y, SPAWN, E, D
cm.fill, cm.scenery, cm.load_region = fill, scenery, load_region

cm.teleport, cm.update_labels = teleport, update_labels
cm.in_pad = function(pos) return in_box(pos, PAD_BUILD) or in_box(pos, PAD_RESULT) end
cm.WORLD_VERSION = WORLD_VERSION
cm.GUIDES = dofile(modpath .. "/guides.lua")
cm.SG = dofile(modpath .. "/signs.lua")
dofile(modpath .. "/npc.lua")
dofile(modpath .. "/doors.lua")
dofile(modpath .. "/lobby.lua")
dofile(modpath .. "/worlds.lua")
dofile(modpath .. "/guide_window.lua")
dofile(modpath .. "/next_hint.lua")
dofile(modpath .. "/learning.lua")
dofile(modpath .. "/modes.lua")
dofile(modpath .. "/museum.lua")
dofile(modpath .. "/exhibits.lua")
dofile(modpath .. "/exhibit_dynamic.lua")
dofile(modpath .. "/tour.lua")
dofile(modpath .. "/furniture.lua")
dofile(modpath .. "/tutor_window.lua") -- after furniture.lua: Prism sits on its information desk
dofile(modpath .. "/billboard.lua")

---------------------------------------------------------------------------- self-test (used by tests/run_server_test.sh)

if core.settings:get_bool("crystalminer.selftest", false) then
	dofile(modpath .. "/selftest.lua")
end
