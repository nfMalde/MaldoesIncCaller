-- A tiny stand-in for the game's API: enough to load the addon and poke at it.
-- It is a guess at the real API, so a green run here proves less than a match in the game.
__NS = {}
unpack = table.unpack
tinsert = table.insert
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
date = os.date
time = os.time
NOW = 1000
function GetTime() return NOW end
WOW_PROJECT_ID = 18
TEST_LOCALE = "deDE"
function GetLocale() return TEST_LOCALE end
function GetBuildInfo() return "1.60.1", "70959", "Nov 1 2026", 16001 end
C_AddOns = { GetAddOnMetadata = function() return "1.0.0" end }
function geterrorhandler() return function() ERRORS_SEEN = (ERRORS_SEEN or 0) + 1 end end
function debugstack() return "stack" end
function IsControlKeyDown() return false end

SECRET = {} -- a value the game keeps secret
function issecretvalue(value) return value == SECRET end

-- Combat and the secure environment ---------------------------------------------
COMBAT = false -- InCombatLockdown()
SECURE = false -- true while the game's own code runs (a secure snippet, a macro)
VIOLATIONS = {} -- what addon code did to a protected frame in combat (the game would block it)
function InCombatLockdown() return COMBAT end

-- Frames ---------------------------------------------------------------------
EVENT_FRAMES = {}
ALL_FRAMES = {}
local Frame = {}
local function NewRegion(kind, name, parent, template)
    local region = setmetatable({
        __kind = kind, __name = name, __parent = parent, __template = template, __shown = true,
        __scripts = {}, __hooks = {}, __attributes = {}, __refs = {}, __w = 100, __h = 50, __text = "",
    }, Frame)
    if name then _G[name] = region end
    return region
end
Frame.__index = function(_, key)
    local method = rawget(Frame, key)
    if method ~= nil then return method end
    -- Any other method is a no-op; fields (lower case) are nil, as on a real frame.
    if type(key) == "string" and key:match("^%u") then return function() end end
    return nil
end

-- A frame with a secure template is protected, and so is every frame it sits in.
local function Guard(self, what)
    if COMBAT and not SECURE and self.__protected then
        VIOLATIONS[#VIOLATIONS + 1] = what .. " on " .. tostring(self.__name or self.__template or self.__kind)
    end
end

function Frame.SetScript(self, name, fn) self.__scripts[name] = fn end
function Frame.GetScript(self, name) return self.__scripts[name] end
function Frame.HookScript(self, name, fn)
    local hooks = self.__hooks[name] or {}
    hooks[#hooks + 1] = fn
    self.__hooks[name] = hooks
end
function Frame.Fire(self, name, ...)
    local fn = self.__scripts[name]
    if fn then fn(self, ...) end
    for _, hook in ipairs(self.__hooks[name] or {}) do hook(self, ...) end
end
function Frame.CreateTexture(self) return NewRegion("Texture", nil, self) end
function Frame.CreateFontString(self) return NewRegion("FontString", nil, self) end
function Frame.GetName(self) return self.__name end
function Frame.GetParent(self) return self.__parent end
function Frame.GetFrameLevel() return 1 end
function Frame.SetSize(self, w, h) Guard(self, "SetSize"); self.__w, self.__h = w, h end
function Frame.SetWidth(self, w) Guard(self, "SetWidth"); self.__w = w end
function Frame.SetHeight(self, h) Guard(self, "SetHeight"); self.__h = h end
function Frame.GetWidth(self) return self.__w end
function Frame.GetHeight(self) return self.__h end
function Frame.SetPoint(self) Guard(self, "SetPoint") end
function Frame.ClearAllPoints(self) Guard(self, "ClearAllPoints") end
function Frame.SetScale(self, scale) Guard(self, "SetScale"); self.__scale = scale end
function Frame.StartMoving(self) Guard(self, "StartMoving") end
function Frame.Show(self) Guard(self, "Show"); self.__shown = true end
function Frame.Hide(self) Guard(self, "Hide"); self.__shown = false end
function Frame.SetShown(self, shown) Guard(self, "SetShown"); self.__shown = shown and true or false end
function Frame.IsShown(self) return self.__shown end
function Frame.IsVisible(self)
    if not self.__shown then return false end
    local parent = self.__parent
    return parent == nil or parent:IsVisible()
end
function Frame.GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function Frame.SetText(self, text) self.__text = text end
function Frame.GetText(self) return self.__text end
function Frame.GetStringHeight() return 12 end
function Frame.SetMinMaxValues(self, a, b) self.__min, self.__max = a, b end
function Frame.GetMinMaxValues(self) return self.__min or 0, self.__max or 0 end
function Frame.SetValue(self, value) self.__value = value; self:Fire("OnValueChanged", value) end
function Frame.GetValue(self) return self.__value or 0 end
function Frame.GetID() return 1 end
function Frame.SetAttribute(self, key, value) Guard(self, "SetAttribute " .. tostring(key)); self.__attributes[key] = value end
function Frame.GetAttribute(self, key) return self.__attributes[key] end
function Frame.GetFrameRef(self, label) return self.__refs[label] end
function Frame.RegisterEvent(self, event)
    EVENT_FRAMES[event] = EVENT_FRAMES[event] or {}
    table.insert(EVENT_FRAMES[event], self)
end
function Frame.UnregisterEvent(self, event)
    local list = EVENT_FRAMES[event] or {}
    for index = #list, 1, -1 do
        if list[index] == self then table.remove(list, index) end
    end
end
function FireEvent(event, ...)
    for _, frame in ipairs(EVENT_FRAMES[event] or {}) do frame:Fire("OnEvent", event, ...) end
end
function CreateFrame(kind, name, parent, template)
    local frame = NewRegion(kind or "Frame", name, parent, template)
    if type(template) == "string" and template:find("Secure", 1, true) then
        local protected = frame
        while protected and protected ~= UIParent do
            protected.__protected = true
            protected = protected.__parent
        end
    end
    ALL_FRAMES[#ALL_FRAMES + 1] = frame
    return frame
end
function SecureHandlerSetFrameRef(frame, label, ref)
    Guard(frame, "SecureHandlerSetFrameRef")
    frame.__refs[label] = ref
end

--[[
A click by the player on a secure button, as the game handles it: the "_onclick" snippet of a
SecureHandlerClickTemplate runs in the secure environment, the macro of a macro button is run by
the game (recorded in MACROS_RUN), and PostClick fires for the key going down and up.
]]
MACROS_RUN = {}
function SecureClick(button)
    SECURE = true
    local snippet = button:GetAttribute("_onclick")
    if snippet then
        assert(load("local self = ...\n" .. snippet))(button)
    end
    if button:GetAttribute("type") == "macro" then
        local text = button:GetAttribute("macrotext")
        if text and text ~= "" then MACROS_RUN[#MACROS_RUN + 1] = text end
    end
    SECURE = false
    button:Fire("PostClick", "LeftButton", true)
    button:Fire("PostClick", "LeftButton", false)
end

-- Timers
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
function RunTimers()
    local list = timers
    timers = {}
    for _, fn in ipairs(list) do fn() end
end

-- The game's frames the addon uses
UIParent = CreateFrame("Frame", "UIParent")
GameTooltip = CreateFrame("GameTooltip", "GameTooltip"); GameTooltip:Hide()
CHAT = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) CHAT[#CHAT + 1] = tostring(message) end }
SlashCmdList = {}
Settings = {
    RegisterCanvasLayoutCategory = function(panel)
        OPTIONS_PANEL = panel
        return { GetID = function() return 7 end }
    end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function(id) OPENED_CATEGORY = id end,
}

-- Where the player is ----------------------------------------------------------
BG = { name = nil, type = "none", id = 0, map = 1415, subzone = "", markers = {}, x = nil, y = nil }
function GetInstanceInfo() return BG.name, BG.type, nil, nil, nil, nil, nil, BG.id end
function GetSubZoneText() return BG.subzone end
C_Map = {
    GetBestMapForUnit = function() return BG.map end,
    GetPlayerMapPosition = function()
        if not BG.x then return nil end
        return { GetXY = function() return BG.x, BG.y end }
    end,
}
C_AreaPoiInfo = {
    GetAreaPOIForMap = function()
        local ids = {}
        for index = 1, #BG.markers do ids[index] = index end
        return ids
    end,
    GetAreaPOIInfo = function(_, id)
        local marker = BG.markers[id]
        if not marker then return nil end
        local info = { name = marker.name }
        if marker.x then
            info.position = { GetXY = function() return marker.x, marker.y end }
        end
        return info
    end,
}

-- Group and chat ---------------------------------------------------------------
LE_PARTY_CATEGORY_INSTANCE = 2
GROUP = "none" -- none | party | raid | instance
function IsInGroup(category)
    if category == LE_PARTY_CATEGORY_INSTANCE then return GROUP == "instance" end
    return GROUP ~= "none"
end
function IsInRaid() return GROUP == "raid" end
LOCKDOWN = false
C_ChatInfo = { InChatMessagingLockdown = function() return LOCKDOWN end }
