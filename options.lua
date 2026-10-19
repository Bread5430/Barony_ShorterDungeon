-- Shorter Dungeon options. Edit the numbers, then unload and reload the ShorterDungeon mod.
-- This file is loaded because options.json sits beside it. The book that JSON
-- declares is not placed in the dungeon (level -1). The sandbox cannot open a
-- text file, so the options have to be Lua.

ShorterDungeonOptions = {
	-- Fraction of the original weight. 0.7 means 30% lighter. 1 leaves weight alone.
	-- Not working yet.
	weight_multiplier = 0.7,

	-- Kill experience multiplier. 1.6 means 60% more. Rounded to the nearest whole number.
	xp_multiplier = 1.6,

	-- Percent chance that identifying an item also identifies one other unidentified
	-- item in that inventory. 0 never, 100 always. The extra identification does not roll again.
	appraisal_chance = 20,
}
