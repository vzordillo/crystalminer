-- Static shells and portals for the six random crystal exhibits.

local cm = crystalminer
local modpath = core.get_modpath("crystalminer")
local data = dofile(modpath .. "/exhibit_data.lua")
local elements = dofile(modpath .. "/exhibit_elements.lua")
local structures = dofile(modpath .. "/exhibit_structures.lua")
local EXHIBIT_VERSION = "7"
cm.exhibit_version = EXHIBIT_VERSION
local exhibit_ready, callbacks = false, {}

local function mark_ready()
	if exhibit_ready then return end
	exhibit_ready = true
	for _, f in ipairs(callbacks) do f() end
	callbacks = {}
end

cm.when_exhibits_ready = function(f)
	if exhibit_ready then f() else callbacks[#callbacks + 1] = f end
end

local element_colours = dofile(modpath .. "/exhibit_colours.lua")
cm.exhibit_atom_node = function(element) return structures.atom_node(element, element_colours) end

for _, colour in ipairs({ "red", "purple", "lime", "orange", "light_blue", "grey" }) do
	cm.scenery("atom_" .. colour, "Rounded exhibit atom", "crystalminer_" .. colour .. ".png", {
		drawtype = "mesh", mesh = "crystalminer_atom.obj", paramtype = "light", sunlight_propagates = true,
		selection_box = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 } },
		collision_box = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 } },
	})
end
for element in pairs(elements) do
	cm.scenery("atom_" .. element, "Rounded exhibit atom", "crystalminer_atom_" .. element .. ".png", {
		drawtype = "mesh", mesh = "crystalminer_atom.obj", paramtype = "light", sunlight_propagates = true,
		selection_box = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 } },
		collision_box = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 } },
	})
end

local ROOMS = {
	{ id = "exhibit_1", number = 1, portal = { x = -59, z = 65 }, wall_x = -58, face = "e", min = { -280, -1, -20 }, size = { 35, 32, 35 } },
	{ id = "exhibit_2", number = 2, portal = { x = 59, z = 65 }, wall_x = 58, face = "w", min = { 230, -1, -20 }, size = { 35, 32, 35 } },
	{ id = "exhibit_3", number = 3, portal = { x = -59, z = 75 }, wall_x = -58, face = "e", min = { -230, -1, -20 }, size = { 35, 32, 35 } },
	{ id = "exhibit_4", number = 4, portal = { x = 59, z = 75 }, wall_x = 58, face = "w", min = { 180, -1, -20 }, size = { 35, 32, 35 } },
	{ id = "exhibit_5", number = 5, portal = { x = -59, z = 85 }, wall_x = -58, face = "e", min = { -330, -1, -20 }, size = { 35, 32, 35 } },
	{ id = "exhibit_6", number = 6, portal = { x = 59, z = 85 }, wall_x = 58, face = "w", min = { 280, -1, -20 }, size = { 35, 32, 35 } },
}
cm.exhibit_rooms, cm.exhibit_data = ROOMS, data

local function room_max(room)
	return { room.min[1] + room.size[1] - 1, room.min[2] + room.size[2] - 1, room.min[3] + room.size[3] - 1 }
end

local function clear_box(box)
	local maxp = { box.min[1] + box.size[1] - 1, box.min[2] + box.size[2] - 1, box.min[3] + box.size[3] - 1 }
	cm.load_region(box)
	local centre = { x = (box.min[1] + maxp[1]) / 2, y = (box.min[2] + maxp[2]) / 2, z = (box.min[3] + maxp[3]) / 2 }
	for _, object in ipairs(core.get_objects_inside_radius(centre, 60)) do
		local entity, pos = object:get_luaentity(), object:get_pos()
		if entity and entity.name == "crystalminer:sign" and pos.x >= box.min[1] and pos.x <= maxp[1]
			and pos.y >= box.min[2] and pos.y <= maxp[2] and pos.z >= box.min[3] and pos.z <= maxp[3] then object:remove() end
	end
	cm.fill(box.min[1], maxp[1], box.min[2], maxp[2], box.min[3], maxp[3], "air")
end

local function build_side_portal(room)
	local z, x, wall = room.portal.z, room.portal.x, room.wall_x
	for y = 1, 4 do
		core.set_node({ x = wall, y = y, z = z - 2 }, { name = "crystalminer:pillar" })
		core.set_node({ x = wall, y = y, z = z + 2 }, { name = "crystalminer:pillar" })
	end
	for zz = z - 2, z + 2 do core.set_node({ x = wall, y = 5, z = zz }, { name = "crystalminer:stone_brick" }) end
	core.set_node({ x = x, y = 0, z = z }, { name = "crystalminer:border_4" })
	core.set_node({ x = x, y = 1, z = z }, { name = "crystalminer:teleporter" })
	local meta = core.get_meta({ x = x, y = 1, z = z })
	meta:set_string("target", room.id)
	meta:set_string("infotext", "Random crystal exhibit " .. room.number .. " (punch it)")
	cm.SG.on_wall({ x = wall, y = 3, z = z }, room.face, "plaque",
		"# Crystal Structures\n## Exhibit " .. room.number .. "\nA random real structure")
end

local function build_shell(room)
	local maxp = room_max(room)
	local x0, x1, z0, z1 = room.min[1], maxp[1], room.min[3], maxp[3]
	cm.load_region(room)
	cm.fill(x0, x1, 0, 0, z0, z1, "crystalminer:stone_brick")
	cm.fill(x0, x1, maxp[2], maxp[2], z0, z1, "crystalminer:roof_glass")
	for x = x0, x1 do for y = 1, maxp[2] - 1 do
		core.set_node({ x = x, y = y, z = z0 }, { name = "crystalminer:stone_brick" })
		core.set_node({ x = x, y = y, z = z1 }, { name = "crystalminer:stone_brick" })
	end end
	for z = z0, z1 do for y = 1, maxp[2] - 1 do
		core.set_node({ x = x0, y = y, z = z }, { name = "crystalminer:stone_brick" })
		core.set_node({ x = x1, y = y, z = z }, { name = "crystalminer:stone_brick" })
	end end
	for _, p in ipairs({ { x = x0 + 2, z = z0 + 2 }, { x = x1 - 2, z = z0 + 2 }, { x = x0 + 2, z = z1 - 2 }, { x = x1 - 2, z = z1 - 2 } }) do
		core.set_node({ x = p.x, y = maxp[2] - 1, z = p.z }, { name = "crystalminer:lamp" })
	end
	local px, pz = math.floor((x0 + x1) / 2), z0 + 1
	core.set_node({ x = px, y = 0, z = pz }, { name = "crystalminer:border_4" })
	core.set_node({ x = px, y = 1, z = pz }, { name = "crystalminer:teleporter" })
	local meta = core.get_meta({ x = px, y = 1, z = pz })
	meta:set_string("target", "portal_hall")
	meta:set_string("infotext", "Return to the Portal Hall (punch it)")
end

cm.exhibit_build_side_portal = function(x, wall_x, face, target, text, z)
	build_side_portal({ id = target, number = 0, portal = { x = x, z = z or 75 }, wall_x = wall_x, face = face })
end
cm.exhibit_build_shell, cm.exhibit_room_max = build_shell, room_max

-- All boxes used by versions 1-6, plus every new fixed room. They are deliberately
-- emerged and cleared before the v7 shells are built.
local LEGACY_BOXES = {
	{ min = { -230, -1, -20 }, size = { 41, 38, 47 } }, { min = { 180, -1, -20 }, size = { 35, 26, 31 } },
	{ min = { -230, -1, -20 }, size = { 31, 17, 35 } }, { min = { 180, -1, -20 }, size = { 35, 17, 31 } },
	{ min = { 180, -1, -20 }, size = { 35, 36, 31 } },
	{ min = { -280, -1, -20 }, size = { 35, 32, 35 } }, { min = { 230, -1, -20 }, size = { 35, 32, 35 } },
	{ min = { -330, -1, -20 }, size = { 35, 32, 35 } }, { min = { 280, -1, -20 }, size = { 35, 32, 35 } },
}
for _, room in ipairs(ROOMS) do cm.extra_boxes[#cm.extra_boxes + 1] = { min = room.min, size = room.size } end
for _, box in ipairs(LEGACY_BOXES) do cm.extra_boxes[#cm.extra_boxes + 1] = { min = box.min, size = box.size } end

-- The emerge callback runs once per map block, so count blocks, not boxes. A block comes back
-- CANCELLED when the emerge queue is full or another thread is generating its chunk; ask for it
-- again a moment later, as init.lua does for the first build.
local MAX_TRIES = 150
local function emerge_all(done)
	local pending, failed = 0, false
	for _, box in ipairs(LEGACY_BOXES) do
		local maxp, n = room_max(box), 1
		for i = 1, 3 do n = n * (math.floor(maxp[i] / 16) - math.floor(box.min[i] / 16) + 1) end
		pending = pending + n
	end
	local function request(pos1, pos2, tries)
		core.emerge_area(pos1, pos2, function(blockpos, action)
			local bad = action == core.EMERGE_CANCELLED or action == core.EMERGE_ERRORED
			if bad and tries < MAX_TRIES then
				local p = { x = blockpos.x * 16, y = blockpos.y * 16, z = blockpos.z * 16 }
				core.after(0.2, function() request(p, p, tries + 1) end)
				return
			end
			if bad then failed = true end
			pending = pending - 1
			if pending == 0 then done(not failed) end
		end)
	end
	for _, box in ipairs(LEGACY_BOXES) do
		local maxp = room_max(box)
		request({ x = box.min[1], y = box.min[2], z = box.min[3] }, { x = maxp[1], y = maxp[2], z = maxp[3] }, 1)
	end
end

local function build_all()
	for _, box in ipairs(LEGACY_BOXES) do clear_box(box) end
	for _, room in ipairs(ROOMS) do build_shell(room); build_side_portal(room) end
end

cm.exhibit_portals = {}
for _, room in ipairs(ROOMS) do cm.exhibit_portals[#cm.exhibit_portals + 1] = { pos = { x = room.portal.x, y = 1, z = room.portal.z }, target = room.id } end

table.insert(cm.on_build, function()
	build_all()
	cm.storage:set_string("exhibit_version", EXHIBIT_VERSION)
	mark_ready()
end)

cm.when_ready(function()
	if cm.storage:get_string("exhibit_version") == EXHIBIT_VERSION then mark_ready(); return end
	emerge_all(function(ok)
		if ok then build_all(); cm.storage:set_string("exhibit_version", EXHIBIT_VERSION)
		else core.log("error", "[crystalminer] exhibit rooms could not be generated; they are built at the next start") end
		mark_ready()
	end)
end)

local old_is_protected = core.is_protected
function core.is_protected(pos, name)
	for _, room in ipairs(ROOMS) do
		if pos.x >= room.min[1] and pos.x < room.min[1] + room.size[1]
			and pos.y >= room.min[2] and pos.y < room.min[2] + room.size[2]
			and pos.z >= room.min[3] and pos.z < room.min[3] + room.size[3]
			and name ~= "" and not core.check_player_privs(name, { teacher = true }) then return true end
	end
	return old_is_protected(pos, name)
end
