-- Random structure loading for the six permanent crystal exhibit portals.

local cm = crystalminer
local modpath = core.get_modpath("crystalminer")
local elements = dofile(modpath .. "/exhibit_elements.lua")
local pipeline = loadfile(modpath .. "/exhibit_live.lua")(elements)
local decor = dofile(modpath .. "/decor.lua")
local baked = dofile(modpath .. "/exhibit_data.lua")
local rooms = cm.exhibit_rooms
cm.exhibit_live_pipeline = pipeline

local function room_for_id(id)
	for _, room in ipairs(rooms) do if room.id == id then return room end end
end

local function copy_room(room)
	return { min = { room.min[1], room.min[2], room.min[3] }, size = { room.size[1], room.size[2], room.size[3] } }
end

local function load_records()
	local encoded = cm.storage:get_string("dynamic_exhibits")
	if encoded == "" then return {} end
	local ok, value = pcall(core.deserialize, encoded)
	return ok and type(value) == "table" and value or {}
end

local old_records = load_records()
local records = {}
for _, room in ipairs(rooms) do
	local old
	for _, entry in ipairs(old_records) do if entry.slot == room.number then old = entry end end
	records[room.number] = old or { slot = room.number, state = "empty" }
	records[room.number].room = copy_room(room)
	records[room.number].state = records[room.number].state == "ready" and "ready" or "empty"
end
cm.exhibit_dynamic_records = records

local function save_records()
	local saved = {}
	for _, entry in ipairs(records) do
		saved[#saved + 1] = {
			slot = entry.slot, state = entry.state, room = entry.room, record = entry.record,
			fingerprint = entry.fingerprint, previous_fingerprint = entry.previous_fingerprint,
			fallback_index = entry.fallback_index, gen = entry.gen,
		}
	end
	cm.storage:set_string("dynamic_exhibits", core.serialize(saved))
end
cm.exhibit_live_save = save_records

local function say(name, message)
	if cm.say then cm.say(name, message, "#FFD700") else core.chat_send_player(name, message) end
end

local function display_name(record)
	if type(record.name) == "string" and #record.name <= 24 and not record.name:find("%s") then return record.name end
	return record.formula or "Live structure"
end

local function room_max(room)
	return cm.exhibit_room_max(room)
end

local function inside(room, pos)
	return pos.x >= room.min[1] and pos.x < room.min[1] + room.size[1]
		and pos.y >= room.min[2] and pos.y < room.min[2] + room.size[2]
		and pos.z >= room.min[3] and pos.z < room.min[3] + room.size[3]
end

local function occupied(room, except)
	for _, player in ipairs(core.get_connected_players and core.get_connected_players() or {}) do
		if player:get_player_name() ~= except and inside(room, player:get_pos()) then return true end
	end
	return false
end
cm.exhibit_room_occupied = occupied

local function clear_signs(room)
	local maxp = room_max(room)
	local centre = { x = (room.min[1] + maxp[1]) / 2, y = (room.min[2] + maxp[2]) / 2, z = (room.min[3] + maxp[3]) / 2 }
	for _, object in ipairs(core.get_objects_inside_radius(centre, 35)) do
		local entity, pos = object:get_luaentity(), object:get_pos()
		if entity and entity.name == "crystalminer:sign" and inside(room, pos) then object:remove() end
	end
end

local function clear_contents(room)
	local maxp = room_max(room)
	clear_signs(room)
	cm.fill(room.min[1] + 1, maxp[1] - 1, room.min[2] + 1, maxp[2] - 1, room.min[3] + 1, maxp[3] - 1, "air")
end

local function plaque_text(record)
	local l = record.lattice
	return string.format("# %s\n## %s\ncell a %.2f b %.2f c %.2f A\nangles %.2f %.2f %.2f deg\n%d atoms\nMaterials Project record %s\nSource: MPContribs\nAtoms: Jmol colours. White lines: bonds. Orange: unit cell.",
		display_name(record), record.formula or "", l.a, l.b, l.c, l.alpha, l.beta, l.gamma, record.sites, record.id:sub(1, 8))
end

local function ready_data(entry, record)
	local room = room_for_id("exhibit_" .. entry.slot)
	local fp = pipeline.footprint(record)
	local model = { x = room.min[1] + 9, y = 2, z = room.min[3] + 10 }
	return { room = room, model = model, record = record,
		live = { area = { id = room.id, tier = 0 }, dots = pipeline.dots(record, model) } }
end

local function empty_data(entry)
	local room = room_for_id("exhibit_" .. entry.slot)
	return { room = room, live = { area = { id = room.id, tier = 0 }, dots = {} } }
end

local function build_ready(entry, record)
	local room = room_for_id("exhibit_" .. entry.slot)
	local model = { x = room.min[1] + 9, y = 2, z = room.min[3] + 10 }
	local fp = pipeline.footprint(record)
	clear_contents(room)
	cm.exhibit_build_shell(room)
	cm.fill(model.x - 1, model.x + fp[1], model.y - 1, model.y - 1, model.z - 1, model.z + fp[2], "crystalminer:stone_brick")
	local decoration = {}
	decor.STYLES.cube(decoration, { x0 = model.x, x1 = model.x + fp[1] - 1, y1 = room.min[2] + room.size[2] - 3,
		z0 = model.z, z1 = model.z + fp[2] - 1 })
	for _, p in ipairs(decoration) do core.set_node({ x = p.x, y = p.y, z = p.z }, { name = "crystalminer:" .. p.n }) end
	for _, atom in ipairs(record.atoms) do
		core.set_node({ x = model.x + atom[1] - record.lo[1], y = model.y + atom[3] - record.lo[3], z = model.z + atom[2] - record.lo[2] },
			{ name = "crystalminer:atom_" .. (elements[atom[4]] and atom[4] or "grey") })
	end
	local plaque_x = model.x + math.floor((fp[1] - 1) / 2)
	local maxp = room_max(room)
	-- The only sign is the plaque on the far wall; none stands in or beside the model. Each build
	-- gets a new generation, and signs of an older one remove themselves when they wake up (see below).
	entry.gen = (entry.gen or 0) + 1
	core.set_node({ x = plaque_x, y = 5, z = maxp[3] }, { name = "crystalminer:stone_brick" })
	cm.SG.on_wall({ x = plaque_x, y = 5, z = maxp[3] }, "s", "panel", plaque_text(record), nil,
		{ exhibit_room = room.id, exhibit_gen = entry.gen })
	return ready_data(entry, record)
end

-- Signs stored in a room that nobody is near are asleep, so clear_signs cannot find them. When one
-- wakes up inside an exhibit room it removes itself unless it belongs to the room's current build.
do
	local def = core.registered_entities["crystalminer:sign"]
	local original = def and def.on_activate
	if original then
		def.on_activate = function(self, staticdata, ...)
			local ok, data = pcall(core.deserialize, staticdata or "")
			local pos = self.object:get_pos()
			if ok and type(data) == "table" and pos then
				for _, entry in ipairs(records) do
					local room = entry.room
					if room and inside(room, pos) then
						local opts = data.opts
						if not (opts and opts.exhibit_room == "exhibit_" .. entry.slot and opts.exhibit_gen == entry.gen) then
							self.object:remove()
							return
						end
					end
				end
			end
			return original(self, staticdata, ...)
		end
	end
end

local function fingerprints_for(entry)
	return pipeline.exclusion_fingerprints(records, entry.previous_fingerprint, entry)
end
cm.exhibit_fingerprints_for = fingerprints_for

-- The key may sit in the game folder's .env file (git-ignored), as MP_API or MP_API_KEY. Mod security
-- (on by default) does not let a mod read the game folder, so this works only with
-- secure.enable_security = false; otherwise io.open fails inside the pcall and the setting or the
-- environment variable is needed. The file is read once and its contents are never logged.
local env_key
do
	local ok, file = pcall(io.open, core.get_modpath("crystalminer") .. "/../../.env", "r")
	if ok and file then
		for line in file:lines() do
			local name, value = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
			if name == "MP_API" or name == "MP_API_KEY" or name == "CRYSTALMINER_MP_API_KEY" then
				value = value:gsub("^[\"']", ""):gsub("[\"']$", "")
				if value ~= "" then env_key = value; break end
			end
		end
		file:close()
	end
end

-- Order: the setting, the CRYSTALMINER_MP_API_KEY environment variable, then the .env file.
-- settings:get returns nil, not "", for a setting that was never set.
local function api_key()
	local key = core.settings:get("crystalminer.mp_api_key")
	if not key or key == "" then key = os.getenv("CRYSTALMINER_MP_API_KEY") end
	if not key or key == "" then key = env_key end
	return key and key ~= "" and key or nil
end

cm.exhibit_http = cm.exhibit_http or {}
if not cm.exhibit_http.fetch then
	cm.exhibit_http.available = cm.http ~= nil
	cm.exhibit_http.fetch = function(request, callback)
		if not cm.http then callback({ succeeded = false }); return end
		cm.http.fetch(request, callback)
	end
elseif cm.exhibit_http.available == nil then
	cm.exhibit_http.available = true
end

local function api_base()
	local base = core.settings:get("crystalminer.mp_api_url")
	if not base or base == "" then base = "https://contribs-api.materialsproject.org" end
	return base:gsub("/+$", "")
end

local function fetch_json(url, key, callback)
	cm.exhibit_http.fetch({ url = url, method = "GET", timeout = 20, extra_headers = { "X-API-KEY: " .. key } }, function(response)
		if not response or not response.succeeded or (response.code and response.code >= 400) then
			callback(nil, response and (response.timeout and "timeout" or "http error") or "request failed"); return
		end
		local ok, parsed = pcall(core.parse_json, response.data)
		if not ok or type(parsed) ~= "table" then callback(nil, "bad JSON"); return end
		callback(parsed)
	end)
end

local function rejection_reason(err)
	if not err then return "rejected" end
	if err == "request failed" or err == "http error" then return "http error" end
	if err == "bad JSON" then return "bad JSON" end
	if err == "timeout" then return "timeout" end
	if err:find("bulk") then return "slab" end
	if err:find("atom count") then return "too many atoms" end
	if err:find("grid cell") then return "grid collision" end
	if err:find("disordered") then return "disorder" end
	if err:find("unknown element") then return "unknown element" end
	if err:find("footprint") then return "footprint" end
	if err:find("tall") then return "too tall" end
	if err:find("no bonds") then return "no bonds" end
	if err:find("dots") then return "too many dots" end
	return "rejected"
end

local function failure_message(stats)
	local reasons = {}
	for reason, count in pairs(stats.rejections) do reasons[#reasons + 1] = { reason, count } end
	table.sort(reasons, function(a, b) return a[1] < b[1] end)
	local text = {}
	for _, item in ipairs(reasons) do text[#text + 1] = item[2] .. " " .. item[1] end
	return "No suitable structure found" .. (#text > 0 and " (rejected: " .. table.concat(text, ", ") .. ")" or "")
end

local in_flight, last_entry = 0, {}
local function teleport_player(name, player, room)
	if not player or not player.get_pos then player = core.get_player_by_name(name) end
	if not player then return end
	player:set_pos({ x = room.min[1] + 17, y = 1, z = room.min[3] + 2 })
	player:set_look_horizontal(0); player:set_look_vertical(0)
end

local function finish_load(entry, record, reason)
	entry.state = record and "ready" or (entry.record and "ready" or "empty")
	if record then
		entry.record, entry.fingerprint = record, pipeline.fingerprint(record)
		entry.room_data = build_ready(entry, record)
	end
	save_records()
	if not record and not entry.record then entry.room_data = empty_data(entry) end
	local network = reason == nil or reason:find("^No suitable") ~= nil
	for _, waiter in ipairs(entry.waiters or {}) do
		if reason then
			local why = network and "Could not load a new structure" or reason
			if record then say(waiter.name, why .. "; showing " .. display_name(record) .. ".")
			else say(waiter.name, why .. "; keeping the current structure.") end
		end
		if entry.record then teleport_player(waiter.name, waiter.player, entry.room_data.room) end
	end
	entry.waiters, in_flight = {}, math.max(0, in_flight - 1)
end

--- Offline choice among the three baked records: first one not similar to what the other rooms show.
local function fallback(entry)
	local excluded = fingerprints_for(entry)
	for offset = 0, #baked - 1 do
		local index = ((entry.fallback_index or 0) + offset) % #baked + 1
		local record = baked[index]
		if not pipeline.similar(record, excluded) then entry.fallback_index = index; return record end
	end
	-- Six rooms but only three baked records (two of them perovskites): the pool runs out. A room must
	-- never stay empty, so repeat the next record that this room is not already showing.
	for offset = 0, #baked - 1 do
		local index = ((entry.fallback_index or 0) + offset) % #baked + 1
		local record = baked[index]
		if not (entry.record and entry.record.md5 == record.md5) then entry.fallback_index = index; return record end
	end
end

local function request_structure(entry)
	local key = api_key()
	if not cm.exhibit_http or not cm.exhibit_http.fetch or cm.exhibit_http.available == false then
		finish_load(entry, fallback(entry), "Live structures are off: add crystalminer to secure.http_mods in minetest.conf and restart"); return
	end
	if not key then
		finish_load(entry, fallback(entry), "Live structures are off: no Materials Project key (set crystalminer.mp_api_key in minetest.conf)"); return
	end
	local stats = { lists = 0, details = 0, tried_ids = {}, tried_elements = {}, rejections = {}, started = os.time(),
		network_errors = 0 }
	local names = {}
	for element in pairs(elements) do names[#names + 1] = element end
	local function reject(err) local reason = rejection_reason(err); stats.rejections[reason] = (stats.rejections[reason] or 0) + 1 end
	local function failed() finish_load(entry, fallback(entry), failure_message(stats)) end
	-- With no network, a wrong key or the API down, every request fails the same way: stop after
	-- three failures in a row instead of sending up to 90 requests for each room load.
	local function network_down(err)
		if err ~= "request failed" and err ~= "http error" and err ~= "timeout" then return false end
		stats.network_errors = stats.network_errors + 1
		if stats.network_errors >= 3 then failed(); return true end
		return false
	end
	local function next_list()
		if stats.lists >= 30 or stats.details >= 60 or os.time() - stats.started >= 60 then failed(); return end
		local choices = {}
		for _, element in ipairs(names) do if not stats.tried_elements[element] then choices[#choices + 1] = element end end
		if #choices == 0 then failed(); return end
		local element = choices[math.random(#choices)]; stats.tried_elements[element] = true; stats.lists = stats.lists + 1
		fetch_json(api_base() .. "/structures/?name__icontains=" .. element .. "&_limit=100&_fields=id,name", key, function(list, err)
			if not list then reject(err); if network_down(err) then return end next_list(); return end
			stats.network_errors = 0
			list = list.data or list
			if type(list) ~= "table" then reject("bad JSON"); next_list(); return end
			for i = #list, 2, -1 do local j = math.random(i); list[i], list[j] = list[j], list[i] end
			local candidates, similar = pipeline.filter_name_candidates(list, fingerprints_for(entry), stats.tried_ids)
			for _, item in ipairs(list) do if item.id then stats.tried_ids[item.id] = true end end
			for _ = 1, similar do reject("similar") end
			local function next_detail(index)
				if index > math.min(3, #candidates) then next_list(); return end
				if stats.details >= 60 or os.time() - stats.started >= 60 then failed(); return end
				local candidate = candidates[index]; stats.details = stats.details + 1
				fetch_json(api_base() .. "/structures/" .. candidate.id .. "/?_fields=id,name,md5,lattice,sites", key, function(raw, detail_err)
					if not raw then reject(detail_err); if network_down(detail_err) then return end next_detail(index + 1); return end
					stats.network_errors = 0
					local prepared, prepare_err = pipeline.prepare(raw)
					if not prepared then reject(prepare_err); next_detail(index + 1); return end
					local duplicate = false
					for _, old in ipairs(records) do if old.record and old.record.md5 == raw.md5 then duplicate = true end end
					for _, old in ipairs(baked) do if old.md5 == raw.md5 then duplicate = true end end
					if duplicate then reject("duplicate"); next_detail(index + 1); return end
					if pipeline.similar(raw, fingerprints_for(entry)) then reject("similar"); next_detail(index + 1); return end
					finish_load(entry, prepared); return
				end)
			end
			next_detail(1)
		end)
	end
	next_list()
end

local function start_load(entry, player_name, player)
	entry.state, entry.last_player = "loading", player_name
	entry.waiters = entry.waiters or {}; entry.waiters[#entry.waiters + 1] = { name = player_name, player = player }
	if #entry.waiters == 1 then
		in_flight = in_flight + 1
		entry.previous_fingerprint = entry.record and (entry.fingerprint or pipeline.fingerprint(entry.record)) or entry.previous_fingerprint
		request_structure(entry)
	else say(player_name, "This exhibit is already loading; you will enter when it is ready.") end
	save_records()
end

local function enter(name, id, player)
	local room = room_for_id(id)
	if not room then return false end
	local entry = records[room.number]
	local now = os.time()
	if last_entry[name] and now - last_entry[name] < 2 then say(name, "Please try again in a moment."); return true end
	last_entry[name] = now
	if entry.state == "ready" and occupied(room, name) then
		say(name, "This room is showing " .. display_name(entry.record) .. ".")
		teleport_player(name, player, room)
		return true
	end
	if entry.state == "loading" then
		if in_flight >= 2 and not entry.waiters then say(name, "Please try again in a moment."); return true end
		entry.waiters = entry.waiters or {}; entry.waiters[#entry.waiters + 1] = { name = name, player = player }
		say(name, "This exhibit is loading; you will enter when it is ready."); return true
	end
	if in_flight >= 2 then say(name, "Please try again in a moment."); return true end
	say(name, "Loading a random crystal structure..."); start_load(entry, name, player); return true
end
cm.exhibit_enter = enter
cm.exhibit_live_enter = enter

local function install(entry)
	if entry.record then entry.room_data = ready_data(entry, entry.record) else entry.room_data = empty_data(entry) end
end
for _, entry in ipairs(records) do install(entry) end
cm.when_exhibits_ready(function() for _, entry in ipairs(records) do if entry.record then entry.room_data = build_ready(entry, entry.record) end end end)

local old_live_at = cm.exhibit_live_at
cm.exhibit_live_at = function(pos)
	for _, entry in ipairs(records) do
		local room = entry.room_data and entry.room_data.room
		if room and pos.x >= room.min[1] - 1 and pos.x < room.min[1] + room.size[1] + 1
			and pos.y >= room.min[2] - 1 and pos.y < room.min[2] + room.size[2] + 1
			and pos.z >= room.min[3] - 1 and pos.z < room.min[3] + room.size[3] + 1 then return entry.room_data.live end
	end
	return old_live_at and old_live_at(pos)
end

local old_is_protected = core.is_protected
core.is_protected = function(pos, name)
	for _, entry in ipairs(records) do
		local room = entry.room_data and entry.room_data.room
		if room and inside(room, pos) and name ~= "" and not core.check_player_privs(name, { teacher = true }) then return true end
	end
	return old_is_protected(pos, name)
end

local function list(name)
	for _, room in ipairs(rooms) do
		local entry = records[room.number]
		say(name, "Exhibit " .. room.number .. ": " .. (entry.record and (display_name(entry.record) .. " (" .. entry.record.formula .. ")") or entry.state))
	end
end
core.register_chatcommand("exhibit", {
	params = "list", description = "List the current live crystal exhibits (teachers)", privs = { teacher = true },
	func = function(name, param)
		if param:trim() == "list" then list(name); return true end
		return false, "Usage: /exhibit list"
	end,
})

table.insert(cm.on_teleport, function(name, id, player)
	if id:match("^exhibit_%d+$") then return enter(name, id, player) end
end)
