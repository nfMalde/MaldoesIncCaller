local ADDON, ns = ...
local L = ns.L

ns.addonName = ADDON
ns.mediaPath = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"

-- Maldö's colours (the GT Toolz theme): espresso black and the amber of the stripes.
ns.colors = {
    bg = { 0.051, 0.039, 0.027 },
    surface = { 0.118, 0.094, 0.071 },
    surfaceHover = { 0.188, 0.149, 0.110 },
    border = { 1, 0.894, 0.784, 0.14 },
    accent = { 1, 0.541, 0.239 },
    accentText = { 1, 0.643, 0.388 },
    onAccent = { 0.086, 0.059, 0.035 },
    text = { 0.945, 0.922, 0.898 },
    textDim = { 0.725, 0.678, 0.631 },
    textFaint = { 0.490, 0.443, 0.400 },
    danger = { 0.984, 0.282, 0.408 },
    good = { 0.204, 0.827, 0.600 },
}

ns.defaults = {
    template = "*Inc call* {base} {count} *INC*",
    flagTemplate = "*Inc call* {base} {count} *INC*",
    -- The call buttons. text is the label and the {count} of the phrase; phrase (optional) is an
    -- own phrase for this button; danger paints the label red, good paints it green.
    buttons = {
        { text = "1" },
        { text = "2" },
        { text = "3" },
        { text = "4+" },
        { text = "Big", danger = true },
        { text = "Clear", good = true, phrase = "*Clear call* {base} *CLEAR*" },
    },
}

local dbDefaults = {
    language = "auto", -- auto | en | de
    callLanguage = "ui", -- ui | en | de
    opacity = 0.5,
    scale = 1,
    locked = false,
    autoShow = true,
    channel = "auto", -- auto | instance | raid | party
    cooldown = 3, -- seconds the call buttons are covered after a call (spam protection), 0 = off
    deselect = true, -- drop the selection when the player walks away from the selected base
    deselectRange = 2, -- how far away that is, in multiples of the battleground's "near" radius (1 to 4)
    debug = false, -- print debug lines to chat
    -- log, errors: written by Log.lua
    -- buttons: nil = default; else a list like ns.defaults.buttons, as long as the player likes
    -- template, flagTemplate: nil = default
    -- position: { point, relativePoint, x, y }
}

ns.targets = {}

local SEND_INTERVAL = 1
local lastSend = 0

function ns.Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff8a3dMaldö's Inc Caller|r: " .. tostring(message))
end

local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

local function Trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end
ns.Trim = Trim

function ns.ApplyLanguage()
    local db = ns.db
    ns.uiLang = ns.ResolveLanguage(db.language)
    if db.callLanguage == "ui" then
        ns.callLang = ns.uiLang
    else
        ns.callLang = ns.ResolveLanguage(db.callLanguage)
    end
end

--- The name of a base as it is shown and sent, in the given language.
function ns.TargetName(target, language)
    if target.names then
        return target.names[language] or target.names.en
    end
    return target.name
end

-- ---------------------------------------------------------------------------
-- Battleground and bases
-- ---------------------------------------------------------------------------

local function CurrentBattleground()
    local name, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    if instanceType == "pvp" then
        ns.testMode = nil
        local definition = ns.Battlegrounds[instanceID]
        if not definition and type(name) == "string" and not IsSecret(name) then
            definition = ns.BattlegroundsByName[string.lower(name)]
        end
        return definition or ns.GenericBattleground, name
    end
    if ns.testMode == "darkspear" then return ns.DemoDarkspearBattleground, L.TEST_MODE end
    if ns.testMode == "flag" then return ns.DemoFlagBattleground, L.TEST_MODE end
    if ns.testMode then return ns.DemoBattleground, L.TEST_MODE end
    return nil
end

--- The named markers on the battleground map: these are the bases, with their position.
local function GetMapMarkers()
    local markers = {}
    if ns.testMode then return markers end
    if not (C_Map and C_Map.GetBestMapForUnit and C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap
            and C_AreaPoiInfo.GetAreaPOIInfo) then
        return markers
    end

    local okMap, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    if not okMap or not mapID then return markers end
    local okList, ids = pcall(C_AreaPoiInfo.GetAreaPOIForMap, mapID)
    if not okList or type(ids) ~= "table" then return markers end

    for _, id in ipairs(ids) do
        local okInfo, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, mapID, id)
        if okInfo and type(info) == "table" and not IsSecret(info.name)
                and type(info.name) == "string" and info.name ~= "" then
            local x, y
            local position = info.position
            if position and not IsSecret(position) then
                if position.GetXY then
                    x, y = position:GetXY()
                else
                    x, y = position.x, position.y
                end
            end
            markers[#markers + 1] = { name = info.name, x = x, y = y }
        end
    end
    return markers
end

local function NameMatches(target, text)
    text = string.lower(text)
    for _, candidate in ipairs(target.match) do
        if text == candidate or (#candidate >= 4 and string.find(text, candidate, 1, true)) then
            return true
        end
    end
    return false
end

local function NewTarget(source)
    local target = {
        key = source.key,
        names = source.names,
        name = source.name,
        flag = source.flag,
        x = source.x,
        y = source.y,
        match = {},
    }
    if source.names then
        for _, name in pairs(source.names) do
            target.match[#target.match + 1] = string.lower(name)
        end
    end
    if source.name then target.match[#target.match + 1] = string.lower(source.name) end
    for _, name in ipairs(source.sub or {}) do
        target.match[#target.match + 1] = string.lower(name)
    end
    return target
end

local function FindByKey(key)
    if not key then return nil end
    for _, target in ipairs(ns.targets) do
        if target.key == key then return target end
    end
    return nil
end

local lastSummary

--- Builds the list of bases for the battleground the player is in (or the demo).
function ns.RebuildTargets()
    -- The base buttons are secure and cannot be laid out again in combat, so a change of the
    -- map markers during a fight waits until it is over.
    if InCombatLockdown() and #ns.targets > 0 then
        ns.AfterCombat("rebuild", ns.RebuildTargets)
        return
    end

    local selectedKey = ns.selected and ns.selected.key
    local nearKey = ns.nearTarget and ns.nearTarget.key
    local definition, bgName = CurrentBattleground()

    ns.bg = definition
    ns.bgName = bgName
    ns.targets = {}

    local markerNames = ""
    if definition then
        local markers = GetMapMarkers()
        local used = {}
        local names = {}
        for index, marker in ipairs(markers) do
            names[index] = marker.name
        end
        markerNames = table.concat(names, ", ")

        for _, source in ipairs(definition.targets or {}) do
            local target = NewTarget(source)
            if not target.flag then
                for index, marker in ipairs(markers) do
                    if not used[index] and NameMatches(target, marker.name) then
                        used[index] = true
                        if marker.x and marker.y then
                            target.x, target.y = marker.x, marker.y
                        end
                        break
                    end
                end
            end
            ns.targets[#ns.targets + 1] = target
        end

        if definition.dynamic then
            local dynamic, seen = {}, {}
            for index, marker in ipairs(markers) do
                if not used[index] and not seen[marker.name] then
                    seen[marker.name] = true
                    dynamic[#dynamic + 1] = NewTarget({
                        key = "poi:" .. marker.name,
                        name = marker.name,
                        x = marker.x,
                        y = marker.y,
                    })
                end
            end
            if #dynamic > 0 then
                -- North to south, like the map.
                table.sort(dynamic, function(a, b)
                    local ay, by = a.y or 2, b.y or 2
                    if ay ~= by then return ay < by end
                    return a.name < b.name
                end)
                for _, target in ipairs(dynamic) do
                    ns.targets[#ns.targets + 1] = target
                end
            else
                for _, source in ipairs(definition.fallback or {}) do
                    ns.targets[#ns.targets + 1] = NewTarget(source)
                end
            end
        end
    end

    ns.selected = FindByKey(selectedKey)
    ns.nearTarget = FindByKey(nearKey)

    -- Log only when something changed: this runs on every map marker update.
    local positioned = 0
    for _, target in ipairs(ns.targets) do
        if target.x and target.y then positioned = positioned + 1 end
    end
    local summary = (definition and "battleground" or "no battleground") .. ", bases " .. #ns.targets
        .. ", with position " .. positioned .. " | map markers: " .. markerNames
    if summary ~= lastSummary then
        lastSummary = summary
        local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
        local mapID = C_Map and C_Map.GetBestMapForUnit and select(2, pcall(C_Map.GetBestMapForUnit, "player"))
        ns.Debug("bases rebuilt:", summary, "| instance", instanceID, instanceType, "| map", mapID,
            "| known", (definition ~= nil and definition ~= ns.GenericBattleground) and "yes" or "no",
            "| demo", ns.testMode and "yes" or "no")
    end

    if ns.UI then ns.UI:Refresh() end
end

--- Where the player is on the battleground map (0..1), or nil when the game does not say.
local function PlayerPosition()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local okMap, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    if not okMap or not mapID then return nil end
    local okPos, position = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not okPos or not position or IsSecret(position) then return nil end
    local px, py = position:GetXY()
    if not px or not py or IsSecret(px) or IsSecret(py) then return nil end
    return px, py
end

--- The base the player is standing at: first by subzone name, then by distance on the map.
function ns.FindNearTarget()
    if not ns.bg or ns.testMode then return nil end

    local subzone = GetSubZoneText and GetSubZoneText()
    if subzone and not IsSecret(subzone) and subzone ~= "" then
        for _, target in ipairs(ns.targets) do
            if not target.flag and NameMatches(target, subzone) then return target end
        end
    end

    local px, py = PlayerPosition()
    if not px then return nil end

    local radius = ns.bg.radius or 0.06
    local best, bestDistance
    for _, target in ipairs(ns.targets) do
        if not target.flag and target.x and target.y then
            local dx, dy = target.x - px, target.y - py
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance <= radius and (not bestDistance or distance < bestDistance) then
                best, bestDistance = target, distance
            end
        end
    end
    return best
end

local pendingSelection = false
local visitedKey -- key of the selected base, once the player has stood at it
local leaveLogged = false

--[[
Drops the selection when the player has walked away from the selected base (option "deselect").

Only a base the player has stood at is dropped: a base picked by hand from far away (to call
inc for a base you see, or while dead) stays. "Away" is deselectRange times the "near" radius,
so the selection does not flicker at the edge of the base. A base without a position on the
map is only known by its subzone name and is dropped when the player leaves that subzone.
]]
local function CheckLeftSelection()
    local selected = ns.selected
    if not selected then
        visitedKey = nil
        return
    end
    if selected == ns.nearTarget then
        visitedKey = selected.key
        leaveLogged = false
        return
    end
    if selected.key ~= visitedKey then
        visitedKey = nil
        return
    end
    -- A near base that waits for the end of combat replaces the selection anyway.
    if not ns.db.deselect or pendingSelection then return end

    if selected.x and selected.y then
        local px, py = PlayerPosition()
        if not px then return end
        local range = math.max(1, tonumber(ns.db.deselectRange) or 2)
        local limit = ((ns.bg and ns.bg.radius) or 0.06) * range
        local dx, dy = selected.x - px, selected.y - py
        if math.sqrt(dx * dx + dy * dy) <= limit then return end
    end

    if InCombatLockdown() then
        -- The call buttons cannot be rewritten in combat, so the selection stays until it ends;
        -- this function runs again a moment later and drops it then.
        if not leaveLogged then
            leaveLogged = true
            ns.Debug("left base:", selected.key, "| deselect after combat")
        end
        return
    end

    ns.Debug("left base:", selected.key, "| deselected")
    ns.selected = nil
    visitedKey = nil
    leaveLogged = false
    if ns.UI then
        ns.UI:ApplySelection()
        ns.UI:UpdateStates()
    end
end

--- Called a few times per second while the window is visible.
function ns.UpdateProximity()
    local near = ns.FindNearTarget()
    if near ~= ns.nearTarget then
        ns.nearTarget = near

        local selection = "kept"
        if near and near ~= ns.selected then
            if InCombatLockdown() then
                -- The call buttons cannot be rewritten in combat: the base is marked as near now
                -- and selected when combat ends, unless the player picks one by hand before that.
                selection = "after combat"
                pendingSelection = true
                ns.AfterCombat("select", function()
                    if pendingSelection and ns.nearTarget then
                        ns.selected = ns.nearTarget
                        ns.UI:ApplySelection()
                        ns.UI:UpdateStates()
                    end
                    pendingSelection = false
                end)
            else
                selection = "selected"
                ns.selected = near
                if ns.UI then ns.UI:ApplySelection() end
            end
        end
        ns.Debug("near base:", near and near.key or "none", "| selection", selection)
        if ns.UI then ns.UI:UpdateStates() end
    end
    CheckLeftSelection()
end

--- A click on a base button decides the selection; a waiting automatic one is dropped.
function ns.CancelPendingSelection()
    pendingSelection = false
end

-- ---------------------------------------------------------------------------
-- Calls
-- ---------------------------------------------------------------------------

--- The call buttons: the player's own list, or the default 1, 2, 3, 4+, Big.
function ns.GetButtons()
    local own = ns.db.buttons
    if type(own) == "table" and #own > 0 then return own end
    return ns.defaults.buttons
end

--- Makes the list editable: the first change copies the default into the settings.
function ns.GetOwnButtons()
    local db = ns.db
    if type(db.buttons) ~= "table" or #db.buttons == 0 then
        db.buttons = {}
        for index, button in ipairs(ns.defaults.buttons) do
            db.buttons[index] = {
                text = button.text,
                phrase = button.phrase,
                danger = button.danger,
                good = button.good,
            }
        end
    end
    return db.buttons
end

function ns.BuildMessage(target, button)
    local db = ns.db
    local template
    if button.phrase and button.phrase ~= "" then
        template = button.phrase
    elseif target.flag then
        template = db.flagTemplate or ns.defaults.flagTemplate
    else
        template = db.template or ns.defaults.template
    end
    local base = ns.TargetName(target, ns.callLang) or ""
    local count = button.text or ""

    local message = template
    message = message:gsub("{base}", function() return base end)
    message = message:gsub("{count}", function() return count end)
    -- "|" starts a colour or link code, and the server rejects messages with broken codes.
    message = message:gsub("|", "")
    message = Trim(message:gsub("%s+", " "))
    -- The macro line ("/i " plus the message) may be 255 characters long.
    if #message > 240 then message = message:sub(1, 240) end
    return message
end

--[[
The chat command the call is sent with, or nil without a fitting group. The English commands
work in every game language.

Calls are sent by secure macro buttons (see UI.lua), not by C_ChatInfo.SendChatMessage: in a
battleground the game is in "chat lockdown" and blocks every chat message that addon code
sends (ADDON_ACTION_BLOCKED, seen in the game on 2026-11-16). A macro the player presses is
the game's own code and is let through.
]]
function ns.ChatCommand()
    -- The demo sends like a battleground does (user request, 2026-11-19): in a group the call goes to
    -- that group, so the player can try the addon with friends. Alone it is only a preview.
    local preference = ns.db.channel
    local inInstanceGroup = IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
    if preference == "instance" then
        return inInstanceGroup and "/i" or nil
    elseif preference == "raid" then
        return IsInRaid() and "/raid" or nil
    elseif preference == "party" then
        return IsInGroup() and "/p" or nil
    end
    if inInstanceGroup then return "/i" end
    if IsInRaid() then return "/raid" end
    if IsInGroup() then return "/p" end
    return nil
end

--- The macro a call button runs for this base: "" without a group, so the click sends nothing.
function ns.MacroText(target, button)
    local command = ns.ChatCommand()
    if not command or not target or not button then return "" end
    local message = ns.BuildMessage(target, button)
    if message == "" then return "" end
    return command .. " " .. message
end

--- Runs after a click on a call button. The game has already run the macro at this point;
--- this only tells the player what happened and writes the log.
function ns.OnCallClicked(target, button)
    if not button then return end
    if not target then
        ns.Print(L.SELECT_FIRST)
        return
    end
    local message = ns.BuildMessage(target, button)
    local command = ns.ChatCommand()
    if not command then
        ns.Debug("call not sent, no group for channel setting", ns.db.channel, "| base", target.key)
        ns.Print(L.NOT_IN_GROUP:format(message))
        return
    end

    local lockdown = "unknown"
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
        local okLock, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
        if okLock then lockdown = locked and "yes" or "no" end
    end

    local now = GetTime()
    local tooFast = now - lastSend < SEND_INTERVAL
    lastSend = now
    ns.Debug("call clicked:", command, "| base", target.key, "| length", #message, "| chat lockdown", lockdown,
        "| combat", InCombatLockdown() and "yes" or "no", tooFast and "| too fast" or "")
    -- Only possible with the pause switched off: the game silently drops chat macros that follow
    -- each other too quickly.
    if tooFast then ns.Print(L.THROTTLED) end
    -- True: a call went out, so the window starts the pause (spam protection).
    return true
end

-- ---------------------------------------------------------------------------
-- Things that have to wait for the end of combat
-- ---------------------------------------------------------------------------

local waiting, waitingOrder = {}, {}

--- Runs action now, or at the end of combat when the game forbids it now (secure buttons).
--- A later action with the same key replaces the earlier one. Returns true when it ran at once.
function ns.AfterCombat(key, action)
    if not InCombatLockdown() then
        action()
        return true
    end
    if not waiting[key] then waitingOrder[#waitingOrder + 1] = key end
    waiting[key] = action
    return false
end

local function RunWaiting()
    local order, actions = waitingOrder, waiting
    waitingOrder, waiting = {}, {}
    for _, key in ipairs(order) do
        ns.Safe(actions[key])()
    end
end

-- ---------------------------------------------------------------------------
-- Start, events, commands
-- ---------------------------------------------------------------------------

local function CopyDefaults(source, destination)
    if type(destination) ~= "table" then destination = {} end
    for key, value in pairs(source) do
        if type(value) == "table" then
            destination[key] = CopyDefaults(value, destination[key])
        elseif destination[key] == nil then
            destination[key] = value
        end
    end
    return destination
end

local rebuildPending = false
local function RebuildSoon(delay)
    if rebuildPending then return end
    rebuildPending = true
    ns.After(delay, function()
        rebuildPending = false
        ns.RebuildTargets()
    end)
end

local function OnZoneChanged()
    local wasInBattleground = ns.inBattleground
    ns.RebuildTargets()
    ns.inBattleground = ns.bg ~= nil and not ns.testMode

    if ns.db.autoShow and ns.UI then
        if ns.inBattleground and not wasInBattleground then
            ns.UI:Show()
        elseif wasInBattleground and not ns.inBattleground then
            ns.UI:Hide()
        end
    end
    -- The map markers are often not there yet in the first moment after the loading screen.
    if ns.inBattleground then RebuildSoon(2) end
end

--- Debug mode prints the debug lines to chat. They are written to the log either way.
function ns.SetDebug(enabled)
    ns.db.debug = enabled and true or false
    ns.Print(ns.db.debug and L.DEBUG_ON or L.DEBUG_OFF)
end

function ns.SetTestMode(mode)
    ns.testMode = mode
    ns.selected = nil
    ns.nearTarget = nil
    ns.RebuildTargets()
end

function ns.OpenOptions()
    if InCombatLockdown() then
        ns.Print(L.OPTIONS_COMBAT)
        return
    end
    if Settings and Settings.OpenToCategory and ns.settingsCategory then
        Settings.OpenToCategory(ns.settingsCategory:GetID())
    end
end

local lastCommand

local events = ns.NewFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        self:UnregisterEvent("ADDON_LOADED")

        MaldoesIncCallerDB = CopyDefaults(dbDefaults, MaldoesIncCallerDB)
        ns.db = MaldoesIncCallerDB
        ns.InitLog()
        ns.ApplyLanguage()
        ns.Debug("loaded: language", ns.uiLang, "| call language", ns.callLang, "| locale", GetLocale())

        self:RegisterEvent("ADDON_ACTION_BLOCKED")
        self:RegisterEvent("ADDON_ACTION_FORBIDDEN")
        ns.UI:Create()
        ns.Options:Register()

        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        self:RegisterEvent("AREA_POIS_UPDATED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
    elseif event == "PLAYER_REGEN_ENABLED" then
        RunWaiting()
    elseif event == "GROUP_ROSTER_UPDATE" then
        -- Joining or leaving a group changes the chat command inside the macros.
        local command = ns.ChatCommand()
        if command ~= lastCommand then
            lastCommand = command
            ns.Debug("chat command now", command or "none")
            ns.UI:Refresh()
        end
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        -- The game refused a protected action and blames an addon: record it when it is this one.
        local blockedFunction = ...
        if arg1 == ADDON then
            ns.ReportError(event .. ": " .. tostring(blockedFunction))
        end
    elseif event == "AREA_POIS_UPDATED" then
        if ns.inBattleground then RebuildSoon(0.5) end
    else
        -- Not logged: zone events are frequent and "bases rebuilt" already records every change.
        OnZoneChanged()
    end
end)

SLASH_MALDOESINCCALLER1 = "/inc"
SLASH_MALDOESINCCALLER2 = "/inccaller"
SLASH_MALDOESINCCALLER3 = "/mic"
SlashCmdList.MALDOESINCCALLER = ns.Safe(function(input)
    local command = string.lower(Trim(input or ""))
    if command == "log" or command == "report" or command == "errors" then
        ns.ShowReport()
    elseif command == "log clear" then
        ns.ClearLog()
        ns.Print(L.LOG_CLEARED)
    elseif command == "debug" then
        ns.SetDebug(not ns.db.debug)
    elseif command == "options" or command == "config" or command == "optionen" then
        ns.OpenOptions()
    elseif command == "test" or command == "demo" then
        ns.SetTestMode(true)
        ns.UI:Show()
    elseif command == "test darkspear" or command == "demo darkspear" then
        ns.SetTestMode("darkspear")
        ns.UI:Show()
    elseif command == "test flag" or command == "demo flag" then
        ns.SetTestMode("flag")
        ns.UI:Show()
    elseif command == "reset" then
        ns.UI:ResetPosition()
        ns.UI:Show()
        ns.Print(L.POSITION_RESET)
    elseif command == "help" or command == "?" then
        ns.Print(L.HELP)
    else
        ns.UI:Toggle()
    end
end)

MaldoesIncCaller_OnAddonCompartmentClick = ns.Safe(function(_, button)
    if button == "RightButton" then
        ns.OpenOptions()
    else
        ns.UI:Toggle()
    end
end)
