-- Shorter Dungeon. Uses only the public S.A.M API.
-- levels.txt and secretlevels.txt in this folder are reference copies, not game-file overrides.

local BLACKLIST = {
	[1] = true, [4] = true, [6] = true, [9] = true, [12] = true, [14] = true,
	[17] = true, [19] = true, [22] = true, [27] = true, [29] = true, [32] = true, [34] = true,
}

-- Whole map.name values for the main biomes. Not substrings: "The Gnomish Mines" must stay.
local BIOMES = {
	["the mines"] = true,
	["the swamp"] = true,
	["the labyrinth"] = true,
	["the ruins"] = true,
	["hell"] = true,
	["the caves"] = true,
	["crystal caves"] = true,
	["the citadel"] = true,
}

local loggedNames = {}
local weightsPatched = false
local pendingIdentify = {}

local function nextOpenFloor(from)
	local n = from + 1
	while n <= 100 and BLACKLIST[n] do
		n = n + 1
	end
	if n > 100 then return nil end
	return n
end

-- sam_is_host() is true on every machine while mods load, so this waits for a game.
-- The patch is absolute and kind "all": one host call is replayed to joiners.
local function patchWeights()
	if weightsPatched or not sam_is_host() then return end
	weightsPatched = true
	local items = sam_list_items() or {}
	for _, item in ipairs(items) do
		local w = item.weight
		if type(w) == "number" and w > 0 then
			sam_patch_item(item.name or item.type, { weight = math.floor(w * 0.7 + 0.5) })
		end
	end
end

local function maybeSkipFloor(e)
	local info = sam_get_level_info()
	if not info or not BLACKLIST[info.floor] then return end

	local name = info.name or e.level_name or ""
	local key = string.lower(name)
	if info.secret or not BIOMES[key] then
		if not BIOMES[key] and not loggedNames[key] then
			loggedNames[key] = true
			sam_log("ShorterDungeon: staying on floor " .. tostring(info.floor)
				.. " named '" .. name .. "'")
		end
		return
	end

	local target = nextOpenFloor(info.floor)
	if target then
		sam_travel_to_level(target)
	end
end

local function maybeIdentifyAnother(e)
	if pendingIdentify[e.player] then
		pendingIdentify[e.player] = nil
		return
	end
	if not sam_random_chance("extra_appraise", 20) then return end

	local inv = sam_get_inventory(e.player)
	if not inv then return end
	local candidates = {}
	for _, item in ipairs(inv) do
		if not item.identified then
			candidates[#candidates + 1] = item.uid
		end
	end
	if #candidates == 0 then return end

	local pick = sam_random("extra_appraise_pick", 1, #candidates)
	pendingIdentify[e.player] = true
	if not sam_identify_item(e.player, candidates[pick]) then
		pendingIdentify[e.player] = nil
	end
end

function on_event(e)
	if e.name == "game.on_game_start" and e.player == 0 then
		patchWeights()

	elseif e.name == "game.on_level_entered" and e.player == 0 then
		maybeSkipFloor(e)

	elseif e.name == "player.on_xp_gained" then
		sam_modify_value(math.floor(e.amount * 1.6 + 0.5))

	elseif e.name == "player.on_item_identified" then
		maybeIdentifyAnother(e)
	end
end
