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

local DEFAULTS = {
	weight_multiplier = 0.7,
	xp_multiplier = 1.6,
	appraisal_chance = 20,
}

local warnedOptions = {}

local function optionNumber(key)
	local options = ShorterDungeonOptions
	local value = options and options[key]
	if type(value) ~= "number" then
		if not warnedOptions[key] then
			warnedOptions[key] = true
			sam_log("ShorterDungeon: options.lua " .. key .. " is missing or not a number, using "
				.. tostring(DEFAULTS[key]))
		end
		return DEFAULTS[key]
	end
	return value
end

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
-- Note: This doesn't seem to work right now.
local function patchWeights()
	if weightsPatched or not sam_is_host() then return end
	weightsPatched = true
	local multiplier = optionNumber("weight_multiplier")
	if multiplier <= 0 then
		sam_log("ShorterDungeon: weight_multiplier " .. tostring(multiplier) .. " is not applied")
		return
	end
	sam_log("ShorterDungeon: weight_multiplier " .. tostring(multiplier))
	local items = sam_list_items() or {}
	for _, item in ipairs(items) do
		local w = item.weight
		if type(w) == "number" and w > 0
			and item.name ~= "shorterdungeon:options"
			and item.name ~= "Shorter Dungeon Options" then
			sam_patch_item(item.name or item.type, { weight = math.floor(w * multiplier + 0.5) })
		end
	end
end

local function maybeSkipFloor(e)
	local info = sam_get_level_info()
	local eventFloor = tostring(e.floor)
	local eventName = tostring(e.level_name)
	if not info then
		sam_log("ShorterDungeon: entered floor " .. eventFloor
			.. " event_name='" .. eventName .. "' level_info=nil")
		return
	end

	local name = info.name or e.level_name or ""
	local key = string.lower(name)
	local blacklisted = BLACKLIST[info.floor] and true or false
	local biome = BIOMES[key] and true or false
	local secret = info.secret and true or false
	sam_log("ShorterDungeon: entered floor " .. tostring(info.floor)
		.. " event_floor=" .. eventFloor
		.. " name='" .. tostring(name) .. "'"
		.. " event_name='" .. eventName .. "'"
		.. " secret=" .. tostring(secret)
		.. " blacklisted=" .. tostring(blacklisted)
		.. " biome=" .. tostring(biome))

	if not blacklisted then return end
	if secret or not biome then
		if not biome and not loggedNames[key] then
			loggedNames[key] = true
			sam_log("ShorterDungeon: staying on floor " .. tostring(info.floor)
				.. " named '" .. name .. "'")
		end
		return
	end

	local target = nextOpenFloor(info.floor)
	if not target then
		sam_log("ShorterDungeon: floor " .. tostring(info.floor) .. " is blacklisted but has no later floor")
		return
	end
	sam_log("ShorterDungeon: skipping floor " .. tostring(info.floor) .. " for floor " .. tostring(target))
	sam_travel_to_level(target)
end

local function maybeIdentifyAnother(e)
	if pendingIdentify[e.player] then
		pendingIdentify[e.player] = nil
		return
	end
	local chance = optionNumber("appraisal_chance")
	if chance < 0 then chance = 0 end
	if chance > 100 then chance = 100 end
	if not sam_random_chance("extra_appraise", chance) then return end

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
	-- Not working yet, throws 1000+ errors if uncommented.
	--if e.name == "game.on_game_start" and e.player == 0 then
	--	patchWeights()


	if e.name == "game.on_level_entered" and e.player == 0 then
		maybeSkipFloor(e)

	elseif e.name == "player.on_xp_gained" then
		local multiplier = optionNumber("xp_multiplier")
		sam_modify_value(math.floor(e.amount * multiplier + 0.5))

	elseif e.name == "player.on_item_identified" then
		maybeIdentifyAnother(e)
	end
end

-- sam_log is the only script output. It is written to sam_log.txt as a SCRIPT line
-- (a second game copy from the same folder writes sam_log_2.txt instead).
sam_log("ShorterDungeon: script loaded, weight_multiplier="
	.. tostring(optionNumber("weight_multiplier"))
	.. " xp_multiplier=" .. tostring(optionNumber("xp_multiplier"))
	.. " appraisal_chance=" .. tostring(optionNumber("appraisal_chance")))
