local _, ns = ...

--[[
Battlegrounds by instance map ID (8th return of GetInstanceInfo()).

  targets   fixed entries with a name per language
  flag      true: a flag carrier entry (uses the flag carrier phrase, never auto-selected)
  x, y      optional position on the battleground map (0..1). Positions of bases normally
            come from the game's map markers, matched by name; x/y is only a fallback.
  sub       optional extra subzone names that count as "near this entry"
  dynamic   true: add every map marker of the battleground that is not listed in targets
  fallback  entries used when dynamic is set but the game reports no map markers
  radius    how close (map units) the player must be for the automatic selection

A battleground without an entry here still works: it is treated as { dynamic = true }.
]]

local FLAG_CARRIER = { key = "fc", flag = true, names = { en = "Flag carrier", de = "Flaggenträger" } }

local warsong = {
    radius = 0.2,
    targets = {
        FLAG_CARRIER,
        -- Approximate positions: the Alliance base is in the north, the Horde base in the south.
        { key = "alliance", x = 0.50, y = 0.14, names = { en = "Alliance base", de = "Allianzbasis" }, sub = { "Silverwing Hold" } },
        { key = "horde", x = 0.50, y = 0.86, names = { en = "Horde base", de = "Hordenbasis" }, sub = { "Warsong Lumber Mill" } },
        { key = "mid", x = 0.50, y = 0.50, names = { en = "Middle", de = "Mitte" } },
    },
}

local arathi = {
    radius = 0.07,
    targets = {
        { key = "stables", names = { en = "Stables", de = "Ställe" } },
        { key = "goldmine", names = { en = "Gold Mine", de = "Goldmine" } },
        { key = "blacksmith", names = { en = "Blacksmith", de = "Schmiede" } },
        { key = "lumbermill", names = { en = "Lumber Mill", de = "Sägewerk" } },
        { key = "farm", names = { en = "Farm", de = "Hof" } },
    },
}

local alterac = {
    radius = 0.05,
    dynamic = true,
    targets = {},
    fallback = {
        { key = "dbn", names = { en = "Dun Baldar North Bunker", de = "Nordbunker von Dun Baldar" } },
        { key = "dbs", names = { en = "Dun Baldar South Bunker", de = "Südbunker von Dun Baldar" } },
        { key = "aid", names = { en = "Stormpike Aid Station", de = "Lazarett der Sturmlanzen" } },
        { key = "spgy", names = { en = "Stormpike Graveyard", de = "Friedhof der Sturmlanzen" } },
        { key = "iwb", names = { en = "Icewing Bunker", de = "Eisschwingenbunker" } },
        { key = "irondeep", names = { en = "Irondeep Mine", de = "Eisenschachtmine" } },
        { key = "shgy", names = { en = "Stonehearth Graveyard", de = "Steinbruchfriedhof" } },
        { key = "shb", names = { en = "Stonehearth Bunker", de = "Steinbruchbunker" } },
        { key = "sfgy", names = { en = "Snowfall Graveyard", de = "Schneewehenfriedhof" } },
        { key = "ibt", names = { en = "Iceblood Tower", de = "Eisblutturm" } },
        { key = "ibgy", names = { en = "Iceblood Graveyard", de = "Eisblutfriedhof" } },
        { key = "tp", names = { en = "Tower Point", de = "Turmstellung" } },
        { key = "fwgy", names = { en = "Frostwolf Graveyard", de = "Friedhof der Frostwölfe" } },
        { key = "coldtooth", names = { en = "Coldtooth Mine", de = "Kaltzahnmine" } },
        { key = "wfwt", names = { en = "West Frostwolf Tower", de = "Westlicher Frostwolfturm" } },
        { key = "efwt", names = { en = "East Frostwolf Tower", de = "Östlicher Frostwolfturm" } },
        { key = "hut", names = { en = "Frostwolf Relief Hut", de = "Heilerhütte der Frostwölfe" } },
    },
}

--[[
Darkspear Islands, the battleground that only WoW Forever has: four outposts and a flag in the
middle that is carried to an outpost of the own team.

Its instance ID is 2997; the name (see BattlegroundsByName) is only a second way to find it. The
positions are from fan guides and are only used when the game's map markers do not match by
name. The German names are our own translation, not the game's.
]]
local darkspear = {
    radius = 0.06,
    targets = {
        FLAG_CARRIER,
        { key = "cove", x = 0.415, y = 0.434, names = { en = "Shipwreck Cove", de = "Schiffswrackbucht" } },
        { key = "tower", x = 0.616, y = 0.452, names = { en = "Abandoned Tower", de = "Verlassener Turm" } },
        { key = "camp", x = 0.421, y = 0.624, names = { en = "Camp", de = "Lager" } },
        { key = "ruins", x = 0.613, y = 0.621, names = { en = "Ruins", de = "Ruinen" } },
        -- Where the flag spawns. "Darkspear Flag" is the name of its map marker.
        { key = "mid", x = 0.511, y = 0.524, names = { en = "Middle", de = "Mitte" }, sub = { "Darkspear Flag" } },
    },
}

ns.Battlegrounds = {
    [30] = alterac,
    [489] = warsong,
    [529] = arathi,
    [2997] = darkspear, -- from a player's report of 2026-11-16 (map 2524)
}

-- Battlegrounds whose instance ID is unknown, by the name GetInstanceInfo() returns (lower case).
ns.BattlegroundsByName = {
    ["darkspear islands"] = darkspear,
}

ns.GenericBattleground = { dynamic = true, targets = {}, radius = 0.06 }

-- The demo shown by /inc test outside a battleground.
ns.DemoBattleground = arathi
ns.DemoFlagBattleground = warsong
ns.DemoDarkspearBattleground = darkspear

--[[
Maldö's links, the same as in GT Toolz. The game cannot open a browser, so a click
shows the link in a box to copy.
]]
ns.Links = {
    { id = "paypal", name = "PayPal", donate = true, url = "https://www.paypal.com/donate/?hosted_button_id=SVZHLRTQ6H4VL" },
    { id = "discord", name = "Discord", short = "DC", url = "https://discord.gg/GbvU9sns5z" },
    { id = "twitch", name = "Twitch", short = "TW", url = "https://www.twitch.tv/maldoe" },
    { id = "youtube", name = "YouTube", short = "YT", url = "https://www.youtube.com/@dermaldoe" },
    { id = "facebook", name = "Facebook", short = "FB", url = "https://www.facebook.com/RealMaldoe" },
    { id = "x", name = "X", short = "X", url = "https://x.com/DerMaldoe" },
    { id = "instagram", name = "Instagram", short = "IG", url = "https://www.instagram.com/maldoe_gaming/" },
}
